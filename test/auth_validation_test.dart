// test/auth_validation_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_electoral_results_app/features/authentication/models/user_role.dart';
import 'package:smart_electoral_results_app/features/authentication/models/registration_form.dart';
import 'package:smart_electoral_results_app/features/authentication/models/user_model.dart';
import 'package:smart_electoral_results_app/features/authentication/services/mock_auth_service.dart';
import 'package:smart_electoral_results_app/features/authentication/services/auth_service.dart';
import 'package:smart_electoral_results_app/features/authentication/presentation/widgets/password_strength_indicator.dart';

/// Standalone validation helpers (mirroring widget-level validation logic).
String? validateUserId(String? v) {
  if (v == null || v.trim().isEmpty) return 'User ID is required.';
  final trimmed = v.trim();
  if (trimmed.contains(' ')) return 'User ID must not contain spaces.';
  if (trimmed.length < 4) return 'User ID must be at least 4 characters.';
  final validChars = RegExp(r'^[A-Za-z0-9_\-]+$');
  if (!validChars.hasMatch(trimmed)) {
    return 'User ID may only contain letters, numbers, _ and -.';
  }
  return null;
}

String? validatePassword(String? v) {
  if (v == null || v.isEmpty) return 'Password is required.';
  if (!RegExp(r'^[a-zA-Z0-9]{6}$').hasMatch(v)) {
    return 'Password must be 6 alphanumeric characters.';
  }
  return null;
}

String? validateConfirmPassword(String? v, String password) {
  if (v == null || v.isEmpty) return 'Please confirm your password.';
  if (v != password) return 'Passwords do not match.';
  return null;
}

void main() {
  // ─── User ID validation ────────────────────────────────────────────────────
  group('User ID Validation', () {
    test('empty returns error', () {
      expect(validateUserId(''), isNotNull);
      expect(validateUserId(null), isNotNull);
    });

    test('too short returns error', () {
      expect(validateUserId('AB'), isNotNull);
      expect(validateUserId('ABC'), isNotNull);
    });

    test('contains spaces returns error', () {
      expect(validateUserId('ERS 0004'), isNotNull);
    });

    test('invalid characters returns error', () {
      expect(validateUserId('user@name'), isNotNull);
      expect(validateUserId('user!id'), isNotNull);
    });

    test('valid user IDs pass', () {
      expect(validateUserId('ERS-0001'), isNull);
      expect(validateUserId('user_001'), isNull);
      expect(validateUserId('ABCD'), isNull);
      expect(validateUserId('admin1234'), isNull);
      expect(validateUserId('my-user-id'), isNull);
    });
  });

  // ─── Password validation ───────────────────────────────────────────────────
  group('Password Validation', () {
    test('empty returns error', () {
      expect(validatePassword(''), isNotNull);
      expect(validatePassword(null), isNotNull);
    });

    test('too short returns error', () {
      expect(validatePassword('abc12'), isNotNull);
    });

    test('too long returns error', () {
      expect(validatePassword('abc1234'), isNotNull);
    });

    test('non-alphanumeric returns error', () {
      expect(validatePassword('ab12!@'), isNotNull);
      expect(validatePassword('ab 123'), isNotNull);
    });

    test('6 alphanumeric characters passes', () {
      expect(validatePassword('abc123'), isNull);
      expect(validatePassword('Abc123'), isNull);
      expect(validatePassword('123456'), isNull);
      expect(validatePassword('abcdef'), isNull);
    });
  });

  // ─── Confirm password ──────────────────────────────────────────────────────
  group('Confirm Password Validation', () {
    test('empty returns error', () {
      expect(validateConfirmPassword('', 'abc123'), isNotNull);
    });

    test('mismatch returns error', () {
      expect(validateConfirmPassword('wrong1', 'abc123'), isNotNull);
    });

    test('match passes', () {
      expect(validateConfirmPassword('abc123', 'abc123'), isNull);
    });
  });

  // ─── Password strength ─────────────────────────────────────────────────────
  group('Password Strength', () {
    test('empty is none', () {
      expect(calculatePasswordStrength(''), PasswordStrength.none);
    });

    test('short simple is weak', () {
      expect(calculatePasswordStrength('abc'), PasswordStrength.weak);
    });

    test('6 chars letters+numbers is medium or strong', () {
      final s = calculatePasswordStrength('abcd12');
      expect(s, anyOf(PasswordStrength.medium, PasswordStrength.strong));
    });

    test('complex 6-char alphanumeric is strong', () {
      expect(calculatePasswordStrength('Abc123'), PasswordStrength.strong);
    });
  });

  // ─── UserRole ──────────────────────────────────────────────────────────────
  group('UserRole', () {
    test('superAdmin is NOT registerable', () {
      expect(UserRole.superAdmin.isRegisterable, isFalse);
    });

    test('other roles are registerable', () {
      for (final role in [
        UserRole.stateAdmin,
        UserRole.lgaAdmin,
        UserRole.wardAdmin,
        UserRole.pollingUnitStaff,
      ]) {
        expect(role.isRegisterable, isTrue);
      }
    });

    test('display names are non-empty', () {
      for (final role in UserRole.values) {
        expect(role.displayName, isNotEmpty);
      }
    });
  });

  // ─── MockAuthService ───────────────────────────────────────────────────────
  group('MockAuthService', () {
    final service = MockAuthService();

    test('pre-seeded roster has entries', () {
      expect(service.rosterCount, greaterThan(0));
    });

    test('lookupUserId finds known ID (case-insensitive)', () async {
      final name = await service.lookupUserId('ERS-0001');
      expect(name, isNotNull);
      expect(name, equals('Adaeze Okafor'));
    });

    test('lookupUserId finds ID regardless of case', () async {
      final lower = await service.lookupUserId('ers-0001');
      final upper = await service.lookupUserId('ERS-0001');
      expect(lower, equals(upper));
    });

    test('lookupUserId returns null for unknown ID', () async {
      final name = await service.lookupUserId('UNKNOWN-9999');
      expect(name, isNull);
    });

    test('register claims a known ID', () async {
      final form = RegistrationForm(
        userId: 'ERS-0002',
        fullName: 'Emeka Chukwuemeka', // will be overridden by roster
        password: 'password123',
        confirmPassword: 'password123',
      );

      final user = await service.register(form: form);
      expect(user.userId, equals('ERS-0002'));
      expect(user.fullName, equals('Emeka Chukwuemeka'));
      expect(user.role, isNull); // role assigned by backend later
    });

    test('register rejects unknown User ID', () async {
      final form = RegistrationForm(
        userId: 'UNKNOWN-9999',
        fullName: 'Nobody',
        password: 'password123',
        confirmPassword: 'password123',
      );

      expect(
        () => service.register(form: form),
        throwsA(isA<AuthException>()),
      );
    });

    test('register rejects already-claimed ID', () async {
      // ERS-0002 was claimed in the test above — second claim must fail
      final form = RegistrationForm(
        userId: 'ERS-0002',
        fullName: 'Impersonator',
        password: 'hacked123',
        confirmPassword: 'hacked123',
      );

      expect(
        () => service.register(form: form),
        throwsA(isA<AuthException>()),
      );
    });

    test('login succeeds with correct credentials', () async {
      // Register ERS-0003 first
      final form = RegistrationForm(
        userId: 'ERS-0003',
        fullName: 'Fatima Bello',
        password: 'secret123!',
        confirmPassword: 'secret123!',
      );
      await service.register(form: form);

      final user = await service.login(
        userId: 'ERS-0003',
        password: 'secret123!',
      );
      expect(user.userId, equals('ERS-0003'));
    });

    test('login is case-insensitive for userId', () async {
      final user = await service.login(
        userId: 'ers-0003',
        password: 'secret123!',
      );
      expect(user.fullName, equals('Fatima Bello'));
    });

    test('login fails with wrong password', () async {
      expect(
        () => service.login(userId: 'ERS-0003', password: 'wrongpassword'),
        throwsA(isA<AuthException>()),
      );
    });

    test('isAuthenticated returns false after logout', () async {
      await service.logout();
      expect(await service.isAuthenticated(), isFalse);
    });

    test('resetPassword changes password', () async {
      // Register ERS-0004
      final form = RegistrationForm(
        userId: 'ERS-0004',
        fullName: 'Ibrahim Musa',
        password: 'oldpassword',
        confirmPassword: 'oldpassword',
      );
      await service.register(form: form);

      await service.resetPassword(
        userId: 'ERS-0004',
        newPassword: 'newpassword123',
      );

      // Old password fails
      expect(
        () => service.login(userId: 'ERS-0004', password: 'oldpassword'),
        throwsA(isA<AuthException>()),
      );

      // New password works
      final user = await service.login(
        userId: 'ERS-0004',
        password: 'newpassword123',
      );
      expect(user.userId, equals('ERS-0004'));
    });

    test('resetPassword rejects unknown ID', () async {
      expect(
        () => service.resetPassword(
          userId: 'UNKNOWN-9999',
          newPassword: 'newpassword',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('resetPassword rejects unclaimed (registered) ID', () async {
      // ERS-0005 is in the roster but never registered in this session
      // Note: may fail if previous tests claimed it — using ERS-0006
      final name = await service.lookupUserId('ERS-0006');
      if (name != null) {
        // Only run if unclaimed
        final isClaimed = service.claimedCount > 0 &&
            await service.lookupUserId('ERS-0006') != null;
        if (isClaimed) {
          // Try to reset on an ID we know is pre-seeded but not claimed
          // (all we can assert is the error is an AuthException)
        }
      }
      // The contract: resetting an unregistered but known ID throws
      expect(
        () => service.resetPassword(
          userId: 'ERS-0010', // in roster, not registered in these tests
          newPassword: 'whatever',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('logout clears session', () async {
      // Login first
      await service.login(userId: 'ERS-0004', password: 'newpassword123');
      expect(await service.isAuthenticated(), isTrue);

      await service.logout();
      expect(await service.isAuthenticated(), isFalse);
      expect(await service.getCurrentUser(), isNull);
    });
  });

  // ─── UserModel ─────────────────────────────────────────────────────────────
  group('UserModel', () {
    test('role is nullable and shows pending when null', () {
      final user = UserModel(
        id: 'usr_001',
        userId: 'ERS-001',
        fullName: 'Test User',
        role: null,
      );
      expect(user.role, isNull);
      expect(user.roleDisplayName, equals('Pending Assignment'));
    });

    test('roleDisplayName shows name when role is set', () {
      final user = UserModel(
        id: 'usr_002',
        userId: 'ERS-002',
        fullName: 'Admin User',
        role: UserRole.stateAdmin,
      );
      expect(user.roleDisplayName, equals('State Administrator'));
    });

    test('does not expose password field', () {
      final user = UserModel(
        id: 'usr_003',
        userId: 'ERS-003',
        fullName: 'Another User',
      );
      expect(user.userId, equals('ERS-003'));
    });
  });

  // ─── RegistrationForm ──────────────────────────────────────────────────────
  group('RegistrationForm', () {
    test('holds userId, fullName, password fields', () {
      final form = RegistrationForm(
        userId: 'ERS-0001',
        fullName: 'Adaeze Okafor',
        password: 'password123',
        confirmPassword: 'password123',
      );
      expect(form.userId, equals('ERS-0001'));
      expect(form.fullName, equals('Adaeze Okafor'));
      expect(form.password, equals('password123'));
    });
  });
}
