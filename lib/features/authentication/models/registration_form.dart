// lib/features/authentication/models/registration_form.dart

/// Simplified registration form — User ID lookup based.
/// Email, phone, role and location are removed:
/// - Role is determined automatically by the backend after login.
/// - Email/phone are not collected at registration time.
class RegistrationForm {
  RegistrationForm({
    this.userId = '',
    this.fullName = '',
    this.password = '',
    this.confirmPassword = '',
  });

  /// The pre-assigned User ID the user is claiming.
  String userId;

  /// Full name retrieved from the backend (read-only from user perspective).
  String fullName;

  String password;
  String confirmPassword;
}
