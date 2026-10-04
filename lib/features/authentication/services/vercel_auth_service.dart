import 'dart:async';

import '../../../core/services/vercel_api_client.dart';

import '../models/registration_form.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import 'admin_account_service.dart';
import 'auth_service.dart';

/// Authentication adapter for the Vercel API backed by Supabase Auth.
/// The access token remains in memory; persistent secure-session storage is a
/// separate integration step and is deliberately not written to preferences.
class VercelAuthService implements AuthService {
  VercelAuthService({VercelApiClient? api})
    : _api = api ?? VercelApiClient.instance;

  final VercelApiClient _api;
  UserModel? _currentUser;

  @override
  Future<UserModel> login({
    required String userId,
    required String password,
  }) async {
    try {
      _api.clearSession();
      final loginData = await _api.post('/api/v1/auth/login', {
        'userId': userId.trim(),
        'password': password,
      }, authenticated: false);
      final token = loginData['accessToken'];
      final refreshToken = loginData['refreshToken'];
      if (token is! String || token.isEmpty) {
        throw const AuthException('The server did not create a valid session.');
      }

      _api.setSession(
        accessToken: token,
        refreshToken: refreshToken is String ? refreshToken : null,
      );
      final profile = await _api.get('/api/v1/me');
      final scope = profile['scope'];
      if (scope is! Map<String, dynamic>) {
        throw const AuthException(
          'The account has no valid assignment. Contact your administrator.',
        );
      }

      final roleCode = profile['role'];
      final role = UserRole.values
          .where((value) => value.code == roleCode)
          .firstOrNull;
      if (role == null) {
        throw const AuthException(
          'The account role is invalid. Contact your administrator.',
        );
      }

      _currentUser = UserModel(
        id: profile['userId'] as String,
        userId: profile['userId'] as String,
        fullName: profile['fullName'] as String,
        role: role,
        stateId: scope['stateCode'] as String?,
        lgaId: scope['lgaCode'] as String?,
        wardId: scope['wardCode'] as String?,
        pollingUnitId: scope['pollingUnitCode'] as String?,
        mustChangePassword: profile['mustChangePassword'] as bool? ?? false,
        canProvisionUsers: profile['canProvisionUsers'] as bool? ?? false,
      );
      if (_currentUser!.role == UserRole.superAdmin &&
          !_currentUser!.mustChangePassword) {
        unawaited(_warmGeography());
      }
      return _currentUser!;
    } on AuthException {
      _api.clearSession();
      rethrow;
    } on VercelApiException catch (error) {
      _api.clearSession();
      throw AuthException(error.message);
    } catch (_) {
      _api.clearSession();
      throw const AuthException(
        'Unable to reach the backend. Check your connection and try again.',
      );
    }
  }

  Future<void> _warmGeography() async {
    try {
      await AdminAccountService(api: _api).getGeography(level: 'states');
    } catch (_) {
      // Login remains successful when geography is temporarily unavailable.
    }
  }

  @override
  Future<void> logout() async {
    _api.clearSession();
    _currentUser = null;
  }

  @override
  Future<bool> isAuthenticated() async =>
      _api.hasSession && _currentUser != null;

  @override
  Future<UserModel?> getCurrentUser() async => _currentUser;

  @override
  Future<String?> lookupUserId(String userId) async => null;

  @override
  Future<UserModel> register({required RegistrationForm form}) async {
    throw const AuthException(
      'Accounts are created by a Super Admin. Please sign in with your issued credentials.',
    );
  }

  @override
  Future<void> resetPassword({
    required String userId,
    required String newPassword,
    String? currentPassword,
  }) async {
    if (!_api.hasSession) {
      throw const AuthException('Sign in before changing your password.');
    }
    try {
      final session = await _api.patch('/api/v1/auth/password', {
        'newPassword': newPassword,
        'currentPassword': currentPassword,
      });
      final accessToken = session['accessToken'];
      final refreshToken = session['refreshToken'];
      if (accessToken is! String || accessToken.isEmpty || refreshToken is! String) {
        _api.clearSession();
        throw const AuthException(
          'Password changed, but the session could not be renewed. Sign in again with your new password.',
        );
      }
      _api.setSession(accessToken: accessToken, refreshToken: refreshToken);
    } on AuthException {
      rethrow;
    } on VercelApiException catch (error) {
      throw AuthException(error.message);
    }
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(mustChangePassword: false);
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
