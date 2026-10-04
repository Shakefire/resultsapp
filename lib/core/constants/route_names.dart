// lib/core/constants/route_names.dart

/// Named route constants for the Smart Electoral Results App.
/// Centralises all route names to avoid magic strings.
class RouteNames {
  RouteNames._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String registrationSuccess = '/registration-success';
  static const String dashboard = '/dashboard';
  static const String adminProvisionUser = '/admin/users/create';
  static const String adminManagement = '/admin/management';
  static const String adminAccountAssignment = '/admin/users/assignment';
  static const String adminElections = '/admin/elections';

  // Polling Unit routes
  static const String submitResult = '/submit-result';
  static const String submissionDetails = '/submission-details';
  static const String voterRegister = '/voter-register';
  static const String voterRegisterUpload = '/voter-register/upload';
  static const String results = '/results';
  static const String alerts = '/alerts';
  static const String profile = '/profile';
}
