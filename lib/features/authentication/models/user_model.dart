// lib/features/authentication/models/user_model.dart
import 'user_role.dart';

/// Represents an authenticated user in the Smart Electoral Results App.
/// Passwords are NEVER stored or exposed in this model.
class UserModel {
  const UserModel({
    required this.id,
    required this.userId,
    required this.fullName,
    this.role,
    this.stateId,
    this.stateName,
    this.lgaId,
    this.lgaName,
    this.wardId,
    this.wardName,
    this.pollingUnitId,
    this.pollingUnitName,
    this.mustChangePassword = false,
    this.canProvisionUsers = false,
  });

  /// Internal auto-generated identifier (UUID in production)
  final String id;

  /// Pre-assigned identifier used for login (e.g. PU-LAG-AGE-W01-U001)
  final String userId;

  final String fullName;

  /// Role is assigned by the backend after login — nullable until determined.
  final UserRole? role;

  // Location fields — populated by backend based on role
  final String? stateId;
  final String? stateName;
  final String? lgaId;
  final String? lgaName;
  final String? wardId;
  final String? wardName;
  final String? pollingUnitId;
  final String? pollingUnitName;
  final bool mustChangePassword;

  /// True when Super Admin or State Admin has granted this account the ability
  /// to provision sub-accounts within its own geographic scope.
  final bool canProvisionUsers;

  /// Display name for the role.
  String get roleDisplayName => role?.displayName ?? 'Pending Assignment';

  UserModel copyWith({
    String? id,
    String? userId,
    String? fullName,
    UserRole? role,
    String? stateId,
    String? stateName,
    String? lgaId,
    String? lgaName,
    String? wardId,
    String? wardName,
    String? pollingUnitId,
    String? pollingUnitName,
    bool? mustChangePassword,
    bool? canProvisionUsers,
  }) {
    return UserModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      stateId: stateId ?? this.stateId,
      stateName: stateName ?? this.stateName,
      lgaId: lgaId ?? this.lgaId,
      lgaName: lgaName ?? this.lgaName,
      wardId: wardId ?? this.wardId,
      wardName: wardName ?? this.wardName,
      pollingUnitId: pollingUnitId ?? this.pollingUnitId,
      pollingUnitName: pollingUnitName ?? this.pollingUnitName,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      canProvisionUsers: canProvisionUsers ?? this.canProvisionUsers,
    );
  }

  @override
  String toString() =>
      'UserModel(userId: $userId, fullName: $fullName, role: $roleDisplayName)';
}
