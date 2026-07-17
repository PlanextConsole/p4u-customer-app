import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';
import '../../customer/data/customer_api.dart';
import '../domain/customer_user.dart';

Map<String, dynamic> _authPayloadFromPhoneExchange(
    Map<String, dynamic> exchange) {
  final nested = exchange['auth'];
  if (nested is Map<String, dynamic>) return nested;
  if (nested is Map) return Map<String, dynamic>.from(nested);
  return exchange;
}

bool _hasAccessToken(Map<String, dynamic> payload) =>
    payload['accessToken'] != null || payload['access_token'] != null;

Map<String, dynamic>? _profilePayloadFromAuthResponse(
    Map<String, dynamic> response) {
  final profile =
      response['profile'] ?? response['customer'] ?? response['user'];
  final object = apiObject(profile);
  return object == null ? null : Map<String, dynamic>.from(object);
}

class AuthRepository {
  AuthRepository({ApiClient? api})
      : _api = api ?? ApiClient(),
        _gateway = CustomerApi(api: api);

  final ApiClient _api;
  final CustomerApi _gateway;

  Stream<void> get authChanges => apiSession.changes;

  Future<CustomerUser?> currentCustomer() async {
    if (!await apiSession.hasToken()) return null;
    final cached = await apiSession.cachedProfile();
    try {
      final profile =
          _profileFrom(await _api.getJson('/api/v1/profile/me', auth: true));
      await apiSession.saveProfile(profile);
      // Commerce stores orders under JWT customer_id/sub (same as web).
      // Never overwrite that with profile DB id or My Orders go empty.
      final jwtId = customerIdFromAccessToken(await apiSession.accessToken());
      if (jwtId != null && jwtId.isNotEmpty) {
        await apiSession.setCustomerId(jwtId);
      } else {
        final cid = (profile['id'] ?? profile['customerId'])?.toString();
        if (cid != null && cid.isNotEmpty) {
          final existing = await apiSession.customerId();
          if (existing == null || existing.isEmpty) {
            await apiSession.setCustomerId(cid);
          }
        }
      }
      return CustomerUser.fromApi(profile,
          fallbackId: await apiSession.customerId());
    } on ApiException catch (e) {
      // 401 only reaches here after a failed silent refresh (session is truly
      // dead) — clearing is correct. A 403 is a live-token authorization issue,
      // NOT an expiry, so it must not log the user out; fall back to the cache.
      if (e.statusCode == 401) {
        await apiSession.clear();
        return null;
      }
      if (cached != null) {
        return CustomerUser.fromApi(cached,
            fallbackId: await apiSession.customerId());
      }
      rethrow;
    }
  }

  Future<CustomerUser> signInWithFirebaseIdToken(String firebaseIdToken) async {
    final exchange = await _gateway.phoneOtpExchange(firebaseIdToken);
    final auth = _authPayloadFromPhoneExchange(exchange);
    if (exchange['loggedIn'] != true && !_hasAccessToken(auth)) {
      final code = exchange['code']?.toString();
      throw ApiException(
        code == 'NOT_REGISTERED' || exchange['registrationToken'] != null
            ? 'No account found with this mobile number. Please register first.'
            : exchange['message']?.toString() ??
                auth['message']?.toString() ??
                'Phone verification failed.',
      );
    }
    await apiSession.saveAuth(auth);
    final profile = await _safeProfile();
    if (profile != null) await apiSession.saveProfile(profile);
    return CustomerUser.fromApi(profile ?? auth,
        fallbackId: auth['customerId']?.toString());
  }
  Future<CustomerUser> registerWithFirebaseIdToken({
    required String firebaseIdToken,
    required String name,
    required String email,
    required String mobile,
    String? occupation,
    String? referralCode,
  }) async {
    var registrationToken = firebaseIdToken;
    try {
      final exchange = await _gateway.phoneOtpExchange(firebaseIdToken);
      final auth = _authPayloadFromPhoneExchange(exchange);
      if (_hasAccessToken(auth)) {
        await apiSession.saveAuth(auth);
        final profile = await _safeProfile();
        if (profile != null) await apiSession.saveProfile(profile);
        return CustomerUser.fromApi(profile ?? auth,
            fallbackId: auth['customerId']?.toString());
      }
      registrationToken = (exchange['registrationToken'] ??
              exchange['registration_token'] ??
              exchange['token'] ??
              firebaseIdToken)
          .toString();
    } on ApiException catch (e) {
      final details = apiObject(e.details);
      registrationToken = (details?['registrationToken'] ??
              details?['registration_token'] ??
              details?['token'] ??
              firebaseIdToken)
          .toString();
    }
    final response = await _gateway.registerCustomerByPhone(
      {
        'registrationToken': registrationToken,
        'fullName': name,
        'email': email,
        if (mobile.isNotEmpty) 'phone': mobile,
        'occupationId': null,
        'customOccupation': occupation,
        'latitude': null,
        'longitude': null,
        'referralCode': referralCode,
      },
    );
    final auth = _authPayloadFromPhoneExchange(response);
    await apiSession.saveAuth(auth);
    final profile = _profilePayloadFromAuthResponse(response) ?? await _safeProfile();
    if (profile != null) await apiSession.saveProfile(profile);
    return CustomerUser.fromApi(profile ?? auth,
        fallbackId: auth['customerId']?.toString());
  }

  Future<void> signOut() async {
    final refresh = await apiSession.refreshToken();
    if (await apiSession.hasToken()) {
      await _gateway.logout(refresh).catchError((_) => <String, dynamic>{});
    }
    await apiSession.clear();
  }

  Future<Map<String, dynamic>?> _safeProfile() async {
    try {
      return _profileFrom(await _api.getJson('/api/v1/profile/me', auth: true));
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _profileFrom(Map<String, dynamic> data) {
    final raw = apiObject(
            data['profile'] ?? data['customer'] ?? data['user'] ?? data) ??
        data;
    final meta = raw['metadata'] is Map
        ? Map<String, dynamic>.from(raw['metadata'] as Map)
        : <String, dynamic>{};
    final name = (raw['fullName'] ?? raw['name'] ?? raw['displayName'] ?? '')
        .toString();
    final phone = (raw['phone'] ?? raw['mobile'] ?? '').toString();
    return {
      ...raw,
      'id': (raw['id'] ?? raw['customerId'] ?? '').toString(),
      'name': name,
      'fullName': name,
      'email': (raw['email'] ?? '').toString(),
      'phone': phone,
      'mobile': phone,
      'dob': (raw['dob'] ?? meta['dob'] ?? '').toString(),
      'gender': (raw['gender'] ?? meta['gender'] ?? '').toString(),
      'metadata': meta,
    };
  }
}

final authRepositoryProvider = Provider((ref) => AuthRepository());

final customerAuthStateProvider = StreamProvider<CustomerUser?>((ref) async* {
  final repo = ref.watch(authRepositoryProvider);
  yield await repo.currentCustomer();
  await for (final _ in repo.authChanges) {
    yield await repo.currentCustomer();
  }
});



