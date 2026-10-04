// lib/features/authentication/models/user_role.dart

/// Enum representing all possible user roles in the system.
enum UserRole {
  superAdmin,
  stateAdmin,
  lgaAdmin,
  wardAdmin,
  pollingUnitStaff,
}

/// Extension for human-readable display names and registration eligibility.
extension UserRoleExtension on UserRole {
  /// Clean human-readable name for display in the UI.
  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Administrator';
      case UserRole.stateAdmin:
        return 'State Administrator';
      case UserRole.lgaAdmin:
        return 'LGA Administrator';
      case UserRole.wardAdmin:
        return 'Ward Administrator';
      case UserRole.pollingUnitStaff:
        return 'Polling Unit Staff';
    }
  }

  /// Whether this role can be selected during public registration.
  /// Super Admin is NEVER available during normal registration.
  bool get isRegisterable {
    return this != UserRole.superAdmin;
  }

  /// Short code for API/internal use.
  String get code {
    switch (this) {
      case UserRole.superAdmin:
        return 'super_admin';
      case UserRole.stateAdmin:
        return 'state_admin';
      case UserRole.lgaAdmin:
        return 'lga_admin';
      case UserRole.wardAdmin:
        return 'ward_admin';
      case UserRole.pollingUnitStaff:
        return 'polling_unit_staff';
    }
  }

  /// All roles that can be selected during registration.
  static List<UserRole> get registrationRoles =>
      UserRole.values.where((r) => r.isRegisterable).toList();
}
