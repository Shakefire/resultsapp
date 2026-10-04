// lib/features/authentication/controllers/auth_controller.dart
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/registration_form.dart';
import '../services/auth_service.dart';
import '../services/vercel_auth_service.dart';

/// Auth controller state enum.
enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

/// ChangeNotifier-based controller that bridges the UI and AuthService.
/// Keeps business logic out of widgets.
class AuthController extends ChangeNotifier {
  AuthController({AuthService? authService})
      : _authService = authService ?? VercelAuthService();

  final AuthService _authService;

  AuthStatus _status = AuthStatus.initial;
  UserModel? _currentUser;
  String? _errorMessage;

  AuthStatus get status => _status;
  UserModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  void _setLoading() {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _status = AuthStatus.error;
    _errorMessage = message;
    notifyListeners();
  }

  void _setAuthenticated(UserModel user) {
    _status = AuthStatus.authenticated;
    _currentUser = user;
    _errorMessage = null;
    notifyListeners();
  }

  void _setUnauthenticated() {
    _status = AuthStatus.unauthenticated;
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Clears any error state — useful when user starts typing again.
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      if (_status == AuthStatus.error) {
        _status = AuthStatus.unauthenticated;
      }
      notifyListeners();
    }
  }

  /// Looks up a User ID and returns the associated name, or null if unknown.
  /// Does NOT modify auth status — this is a lightweight read-only query.
  Future<String?> lookupUserId(String userId) async {
    try {
      return await _authService.lookupUserId(userId);
    } catch (_) {
      return null;
    }
  }

  /// Attempts login. Returns true on success.
  Future<bool> login({
    required String userId,
    required String password,
  }) async {
    _setLoading();
    try {
      final user = await _authService.login(userId: userId, password: password);
      _setAuthenticated(user);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('An unexpected error occurred. Please try again.');
      return false;
    }
  }

  /// Attempts registration. Returns the created UserModel on success, null on failure.
  Future<UserModel?> register({required RegistrationForm form}) async {
    _setLoading();
    try {
      final user = await _authService.register(form: form);
      // Do NOT set authenticated after registration — user must explicitly log in.
      _setUnauthenticated();
      return user;
    } on AuthException catch (e) {
      _setError(e.message);
      return null;
    } catch (_) {
      _setError('Registration failed. Please try again.');
      return null;
    }
  }

  /// Resets password for a given userId. Returns true on success.
  Future<bool> resetPassword({
    required String userId,
    required String newPassword,
    String? currentPassword,
  }) async {
    _setLoading();
    try {
      await _authService.resetPassword(userId: userId, newPassword: newPassword, currentPassword: currentPassword);
      if (_currentUser == null) {
        _setUnauthenticated();
      } else {
        _setAuthenticated(_currentUser!);
      }
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('Password reset failed. Please try again.');
      return false;
    }
  }

  /// Logs out the current session.
  Future<void> logout() async {
    _setLoading();
    await _authService.logout();
    _setUnauthenticated();
  }
}
