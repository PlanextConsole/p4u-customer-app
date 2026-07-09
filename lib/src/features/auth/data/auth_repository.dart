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
      return CustomerUser.fromApi(profile,
          fallbackId: await apiSession.customerId());
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
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

  Future<CustomerUser> signInWithPassword(String email, String password) async {
    throw const ApiException(
        'Password login is not available in the new API yet. Please use Phone OTP.');
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
    final auth = await _gateway.registerCustomerByPhone(
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
    await apiSession.saveAuth(auth);
    final profile = await _safeProfile();
    if (profile != null) await apiSession.saveProfile(profile);
    return CustomerUser.fromApi(profile ?? auth,
        fallbackId: auth['customerId']?.toString());
  }

  Future<void> updatePassword(String password) async {
    if (!await apiSession.hasToken()) return;
    await _api
        .postJson(
          '/api/auth/change-password',
          body: {'currentPassword': '', 'newPassword': password},
          auth: true,
        )
        .catchError((_) => <String, dynamic>{});
  }

  Future<void> sendPasswordReset(String email) async {
    throw const ApiException(
        'Password reset is not available in the new API yet. Please use Phone OTP.');
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
    return apiObject(
            data['profile'] ?? data['customer'] ?? data['user'] ?? data) ??
        data;
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
