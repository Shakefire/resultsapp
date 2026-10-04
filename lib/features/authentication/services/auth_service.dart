// lib/features/authentication/services/auth_service.dart
import '../models/user_model.dart';
import '../models/registration_form.dart';

/// Abstract authentication service interface.
/// Production uses VercelAuthService; explicit mock implementations are for previews only.
abstract class AuthService {
  /// Looks up a pre-assigned User ID and returns the associated full name.
  /// Returns null if the User ID is not recognised.
  /// In production this will hit an API endpoint.
  Future<String?> lookupUserId(String userId);

  /// Logs in with userId and password.
  /// Throws [AuthException] on failure.
  Future<UserModel> login({
    required String userId,
    required String password,
  });

  /// Registers (claims) a pre-assigned User ID with a new password.
  /// Throws [AuthException] on failure (e.g. already claimed, unknown ID).
  Future<UserModel> register({required RegistrationForm form});

  /// Logs out the current session.
  Future<void> logout();

  /// Returns true if a session currently exists.
  Future<bool> isAuthenticated();

  /// Returns the current user model, or null if not authenticated.
  Future<UserModel?> getCurrentUser();

  /// Resets password for the given userId.
  /// Throws [AuthException] on failure.
  Future<void> resetPassword({
    required String userId,
    required String newPassword,
    String? currentPassword,
  });
}

/// Typed exception for authentication errors.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => 'AuthException: $message';
}
