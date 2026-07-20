import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.details});

  final String message;
  final int? statusCode;
  final Object? details;

  @override
  String toString() => message;
}

class ApiSession {
  static const _accessTokenKey = 'p4u_customer_access_token';
  static const _refreshTokenKey = 'p4u_customer_refresh_token';
  static const _customerIdKey = 'p4u_customer_id';
  static const _rolesKey = 'p4u_customer_roles';
  static const _profileKey = 'p4u_customer_profile';

  final _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  Future<String?> accessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  Future<String?> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  Future<String?> customerId() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_customerIdKey);
    if (stored != null && stored.trim().isNotEmpty) return stored.trim();
    final fromJwt = customerIdFromAccessToken(await accessToken());
    if (fromJwt != null && fromJwt.isNotEmpty) {
      await prefs.setString(_customerIdKey, fromJwt);
      return fromJwt;
    }
    return null;
  }

  Future<void> setCustomerId(String id) async {
    if (id.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final next = id.trim();
    final prev = prefs.getString(_customerIdKey);
    // Only notify on real changes — unconditional notify + currentCustomer()
    // caused an infinite auth stream loop that kept recreating FutureBuilders.
    if (prev == next) return;
    await prefs.setString(_customerIdKey, next);
    _changes.add(null);
  }

  Future<bool> hasToken() async =>
      (await accessToken())?.isNotEmpty == true ||
      (await refreshToken())?.isNotEmpty == true;

  Future<Map<String, dynamic>?> cachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } on FormatException {
      // A partially-written/corrupt cache must not prevent app startup.
      await prefs.remove(_profileKey);
      return null;
    }
  }

  Future<void> saveAuth(
    Map<String, dynamic> data, {
    Map<String, dynamic>? profile,
    bool notify = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final access = data['accessToken'] ?? data['access_token'];
    final refresh = data['refreshToken'] ?? data['refresh_token'];
    var customerId = data['customerId'] ?? data['customer_id'];
    if (customerId == null || customerId.toString().trim().isEmpty) {
      customerId = customerIdFromAccessToken(access?.toString());
    }
    if (customerId == null || customerId.toString().trim().isEmpty) {
      customerId = profile?['id'] ?? profile?['customerId'];
    }
    final roles = data['roles'];
    if (access != null) {
      await prefs.setString(_accessTokenKey, access.toString());
    }
    if (refresh != null) {
      await prefs.setString(_refreshTokenKey, refresh.toString());
    }
    if (customerId != null && customerId.toString().trim().isNotEmpty) {
      await prefs.setString(_customerIdKey, customerId.toString().trim());
    }
    if (roles != null) await prefs.setString(_rolesKey, jsonEncode(roles));
    if (profile != null) {
      await prefs.setString(_profileKey, jsonEncode(profile));
    }
    // A silent access-token refresh must not rebuild the router and every
    // active FutureBuilder. Login/registration still notify normally.
    if (notify) _changes.add(null);
  }

  Future<void> saveProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_customerIdKey);
    await prefs.remove(_rolesKey);
    await prefs.remove(_profileKey);
    _changes.add(null);
  }
}

final apiSession = ApiSession();

class ApiClient {
  ApiClient({ApiSession? session}) : session = session ?? apiSession;

  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.planext4u.com',
  );

  static const _jsonRequestTimeout = Duration(seconds: 30);
  static const _uploadTimeout = Duration(minutes: 2);
  static Future<void>? _refreshInFlight;

  final ApiSession session;
  final _http = HttpClient()..connectionTimeout = const Duration(seconds: 20);

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, Object?> query = const {},
    bool auth = false,
  }) =>
      _send('GET', path, query: query, auth: auth);

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, Object?> query = const {},
    Object? body,
    bool auth = false,
  }) =>
      _send('POST', path, query: query, body: body, auth: auth);

  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, Object?> query = const {},
    Object? body,
    bool auth = false,
  }) =>
      _send('PUT', path, query: query, body: body, auth: auth);

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, Object?> query = const {},
    Object? body,
    bool auth = false,
  }) =>
      _send('PATCH', path, query: query, body: body, auth: auth);

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, Object?> query = const {},
    Object? body,
    bool auth = false,
  }) =>
      _send('DELETE', path, query: query, body: body, auth: auth);

  Future<List<Map<String, dynamic>>> getList(
    String path, {
    Map<String, Object?> query = const {},
    bool auth = false,
  }) async =>
      apiItems(await getJson(path, query: query, auth: auth));

  Future<Map<String, dynamic>> uploadFile(
    String path,
    File file, {
    String field = 'file',
    Map<String, Object?> fields = const {},
    String? contentType,
    bool auth = true,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _withUploadTimeout(_uploadFileOnce(
          path,
          file,
          field: field,
          fields: fields,
          contentType: contentType,
          auth: auth,
        ));
      } on ApiException catch (e) {
        if (!auth || e.statusCode != 401 || attempt > 0) rethrow;
        await _refreshAuthDeduped();
      }
    }
    throw const ApiException('Upload failed');
  }

  Future<Map<String, dynamic>> _uploadFileOnce(
    String path,
    File file, {
    required String field,
    required Map<String, Object?> fields,
    String? contentType,
    required bool auth,
  }) async {
    final request = await _http.postUrl(_uri(path));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (auth) await _attachAuth(request);

    final boundary = '----p4u-${DateTime.now().microsecondsSinceEpoch}';
    request.headers.contentType = ContentType('multipart', 'form-data',
        parameters: {'boundary': boundary});

    for (final entry in fields.entries) {
      if (entry.value == null) continue;
      request.write('--$boundary\r\n');
      request
          .write('Content-Disposition: form-data; name="${entry.key}"\r\n\r\n');
      request.write('${entry.value}\r\n');
    }

    final fileName = file.path.split(RegExp(r'[\\/]')).last;
    request.write('--$boundary\r\n');
    request.write(
        'Content-Disposition: form-data; name="$field"; filename="$fileName"\r\n');
    request.write(
        'Content-Type: ${contentType ?? _mediaContentType(fileName)}\r\n\r\n');
    // Stream media from disk. Loading an entire video into memory can trigger
    // Android out-of-memory termination on otherwise valid uploads.
    await request.addStream(file.openRead());
    request.write('\r\n--$boundary--\r\n');

    return _decodeResponse(await request.close());
  }

  Future<Map<String, dynamic>> uploadFiles(
    String path,
    List<File> files, {
    String field = 'files',
    Map<String, Object?> fields = const {},
    String? contentType,
    bool auth = true,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _withUploadTimeout(_uploadFilesOnce(
          path,
          files,
          field: field,
          fields: fields,
          contentType: contentType,
          auth: auth,
        ));
      } on ApiException catch (e) {
        if (!auth || e.statusCode != 401 || attempt > 0) rethrow;
        await _refreshAuthDeduped();
      }
    }
    throw const ApiException('Upload failed');
  }

  Future<Map<String, dynamic>> _uploadFilesOnce(
    String path,
    List<File> files, {
    required String field,
    required Map<String, Object?> fields,
    String? contentType,
    required bool auth,
  }) async {
    final request = await _http.postUrl(_uri(path));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (auth) await _attachAuth(request);

    final boundary = '----p4u-${DateTime.now().microsecondsSinceEpoch}';
    request.headers.contentType = ContentType('multipart', 'form-data',
        parameters: {'boundary': boundary});

    for (final entry in fields.entries) {
      if (entry.value == null) continue;
      request.write('--$boundary\r\n');
      request
          .write('Content-Disposition: form-data; name="${entry.key}"\r\n\r\n');
      request.write('${entry.value}\r\n');
    }

    for (final file in files) {
      final fileName = file.path.split(RegExp(r'[\\/]')).last;
      request.write('--$boundary\r\n');
      request.write(
          'Content-Disposition: form-data; name="$field"; filename="$fileName"\r\n');
      request.write(
          'Content-Type: ${contentType ?? _mediaContentType(fileName)}\r\n\r\n');
      await request.addStream(file.openRead());
      request.write('\r\n');
    }
    request.write('--$boundary--\r\n');

    return _decodeResponse(await request.close());
  }

  String _mediaContentType(String fileName) {
    final name = fileName.toLowerCase();
    if (name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.jfif')) {
      return 'image/jpeg';
    }
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.gif')) return 'image/gif';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.heic')) return 'image/heic';
    if (name.endsWith('.avif')) return 'image/avif';
    if (name.endsWith('.mp4')) return 'video/mp4';
    if (name.endsWith('.mov')) return 'video/quicktime';
    if (name.endsWith('.webm')) return 'video/webm';
    if (name.endsWith('.m4v')) return 'video/x-m4v';
    if (name.endsWith('.avi')) return 'video/x-msvideo';
    return 'application/octet-stream';
  }

  Future<T> _withUploadTimeout<T>(Future<T> future) => future.timeout(
        _uploadTimeout,
        onTimeout: () => throw const ApiException(
          'Upload timed out. Check your connection and try again.',
        ),
      );

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?> query = const {},
    Object? body,
    bool auth = false,
  }) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await _sendOnce(
          method,
          path,
          query: query,
          body: body,
          auth: auth,
        );
      } on ApiException catch (e) {
        if (e.statusCode == 429 && attempt < 2) {
          await Future.delayed(Duration(milliseconds: 700 * (attempt + 1)));
          continue;
        }
        if (!auth || e.statusCode != 401) rethrow;
        await _refreshAuthDeduped();
        return _sendOnce(
          method,
          path,
          query: query,
          body: body,
          auth: auth,
        );
      }
    }
    throw const ApiException(
        'Too many requests. Please wait a moment and try again.',
        statusCode: 429);
  }

  Future<Map<String, dynamic>> _sendOnce(
    String method,
    String path, {
    Map<String, Object?> query = const {},
    Object? body,
    bool auth = false,
  }) async {
    return (() async {
      final request = await _http.openUrl(method, _uri(path, query));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.contentType = ContentType.json;
      if (auth) await _attachAuth(request);
      if (body != null) request.write(jsonEncode(body));
      return _decodeResponse(await request.close());
    })()
        .timeout(
      _jsonRequestTimeout,
      onTimeout: () => throw const ApiException(
        'The server took too long to respond. Please retry.',
      ),
    );
  }

  Future<void> _refreshAuthDeduped() {
    final current = _refreshInFlight;
    if (current != null) return current;
    final refresh = _refreshAuth().whenComplete(() => _refreshInFlight = null);
    _refreshInFlight = refresh;
    return refresh;
  }

  Future<void> _refreshAuth() async {
    final refreshToken = await session.refreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await session.clear();
      throw const ApiException('Session expired. Please login again.',
          statusCode: 401);
    }

    try {
      final data = await (() async {
        final request =
            await _http.openUrl('POST', _uri('/api/auth/public/refresh'));
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({'refreshToken': refreshToken}));
        return _decodeResponse(await request.close());
      })()
          .timeout(
        _jsonRequestTimeout,
        onTimeout: () => throw const ApiException(
          'Session refresh timed out. Please retry.',
        ),
      );
      final auth = apiObject(data['auth'] ?? data['data'] ?? data) ?? data;
      await session.saveAuth(auth, notify: false);
    } on ApiException {
      rethrow;
    }
  }

  Uri _uri(String path, [Map<String, Object?> query = const {}]) {
    final base = Uri.parse(baseUrl);
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    final queryParams = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value == null || value.toString().isEmpty) continue;
      queryParams[entry.key] = value.toString();
    }
    return base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/$'), '')}/$normalized',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
  }

  Future<void> _attachAuth(HttpClientRequest request) async {
    final token = await session.accessToken();
    if (token == null || token.isEmpty) {
      throw const ApiException('Please login to continue.', statusCode: 401);
    }
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  }

  Future<Map<String, dynamic>> _decodeResponse(
      HttpClientResponse response) async {
    final raw = await response.transform(utf8.decoder).join();
    final decoded = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : decoded is Map
            ? Map<String, dynamic>.from(decoded)
            : {'items': decoded};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data['message'] ??
          data['error'] ??
          data['code'] ??
          'API request failed';
      throw ApiException(message.toString(),
          statusCode: response.statusCode, details: data);
    }
    // Mirror web client: unwrap `{ success: true, data: ... }` so callers see
    // the payload fields (email, balance, items) at the top level.
    if (data['success'] == true && data.containsKey('data')) {
      final inner = data['data'];
      if (inner is Map) {
        final result = Map<String, dynamic>.from(inner);
        for (final key in const ['total', 'limit', 'offset', 'page']) {
          if (data[key] != null && result[key] == null) {
            result[key] = data[key];
          }
        }
        return result;
      }
      if (inner is List) {
        return {
          'items': inner,
          if (data['total'] != null) 'total': data['total'],
          if (data['limit'] != null) 'limit': data['limit'],
          if (data['offset'] != null) 'offset': data['offset'],
        };
      }
    }
    return data;
  }
}

List<Map<String, dynamic>> apiItems(Object? value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }
  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    for (final key in [
      'items',
      'data',
      'results',
      'rows',
      'banners',
      'products',
      'services',
      'categories',
      'vendors',
      'orders',
      'bookings',
      'addresses',
      'wishlist',
      'transactions',
      'notifications',
      'slots',
      'recentHistory',
      'posts',
      'feed',
      'stories',
      'comments',
      'conversations',
      'messages',
      'brands',
      'popups',
      'reels',
      'classified',
    ]) {
      final nested = map[key];
      if (nested is List) return apiItems(nested);
      if (nested is Map) {
        final rows = apiItems(nested);
        if (rows.isNotEmpty) return rows;
      }
    }
  }
  return [];
}

Map<String, dynamic>? apiObject(Object? value) {
  if (value is Map<String, dynamic>) {
    if (value['success'] == true && value['data'] is Map) {
      return Map<String, dynamic>.from(value['data'] as Map);
    }
    return value;
  }
  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    if (map['success'] == true && map['data'] is Map) {
      return Map<String, dynamic>.from(map['data'] as Map);
    }
    return map;
  }
  return null;
}

/// Decode JWT payload (no verify) and return customer_id / customerId / sub.
String? customerIdFromAccessToken(String? accessToken) {
  if (accessToken == null || accessToken.trim().isEmpty) return null;
  try {
    final parts = accessToken.split('.');
    if (parts.length < 2) return null;
    var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
    while (payload.length % 4 != 0) {
      payload += '=';
    }
    final json = jsonDecode(utf8.decode(base64Decode(payload)));
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    final explicit = map['customer_id'] ?? map['customerId'];
    if (explicit != null && explicit.toString().trim().isNotEmpty) {
      return explicit.toString().trim();
    }
    final sub = map['sub'];
    if (sub != null && sub.toString().trim().isNotEmpty) {
      return sub.toString().trim();
    }
  } catch (_) {}
  return null;
}
