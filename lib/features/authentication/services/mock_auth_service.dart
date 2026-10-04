// lib/features/authentication/services/mock_auth_service.dart
import 'dart:math';
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../models/registration_form.dart';
import 'auth_service.dart';

/// In-memory mock authentication service.
/// Simulates a system where User IDs are pre-assigned by administrators.
/// Registration = claiming a pre-assigned ID with a password.
/// Replace this with ApiAuthService when the backend is ready.
class MockAuthService implements AuthService {
  MockAuthService._();

  static final MockAuthService _instance = MockAuthService._();
  factory MockAuthService() => _instance;

  // ─── Pre-seeded roster ────────────────────────────────────────────────────
  // These represent staff IDs pre-assigned by the electoral commission admin.
  // In production this data lives in the backend database.
  static const Map<String, String> _preSeededRoster = {
    'ers-0001': 'Adaeze Okafor',
    'ers-0002': 'Emeka Chukwuemeka',
    'ers-0003': 'Fatima Bello',
    'ers-0004': 'Ibrahim Musa',
    'ers-0005': 'Chidinma Eze',
    'ers-0006': 'Oluwaseun Adesanya',
    'ers-0007': 'Ngozi Nwosu',
    'ers-0008': 'Abdullahi Garba',
    'ers-0009': 'Blessing Okonkwo',
    'ers-0010': 'Mohammed Yusuf',
    'ers-1001': 'Aisha Lawal',
    'ers-1002': 'Chukwudi Obiora',
    'ers-1003': 'Hauwa Suleiman',
    'ers-1004': 'Tunde Bakare',
    'ers-1005': 'Amaka Igwe',
    'admin-001': 'State Administrator — FCT',
    'admin-002': 'State Administrator — Lagos',
    'ward-001': 'Garki 1 Ward Officer',
    'lga-001': 'AMAC LGA Coordinator',
    'test': 'Test User',
  };

  // ─── Claimed accounts (userId → password) ─────────────────────────────────
  // Keyed by lowercased userId for case-insensitive lookup.
  final Map<String, _ClaimedAccount> _claimedAccounts = {};

  // Current authenticated session
  UserModel? _currentUser;

  final Random _rng = Random();

  // ─── Simulate network latency ─────────────────────────────────────────────
  Future<void> _shortDelay() async {
    await Future.delayed(Duration(milliseconds: 300 + _rng.nextInt(200)));
  }

  Future<void> _authDelay() async {
    await Future.delayed(Duration(milliseconds: 500 + _rng.nextInt(300)));
  }

  // ─── Interface implementation ─────────────────────────────────────────────

  @override
  Future<String?> lookupUserId(String userId) async {
    await _shortDelay();
    final key = userId.trim().toLowerCase();
    return _preSeededRoster[key];
  }

  @override
  Future<UserModel> login({
    required String userId,
    required String password,
  }) async {
    await _authDelay();

    final key = userId.trim().toLowerCase();
    var account = _claimedAccounts[key];

    // For testing convenience: allow instant login for pre-seeded IDs with password123 if not yet registered
    if (account == null && _preSeededRoster.containsKey(key) && password == 'password123') {
      final name = _preSeededRoster[key]!;
      final user = UserModel(
        id: _generateInternalId(),
        userId: userId.trim(),
        fullName: name,
        role: _determineRole(key),
        pollingUnitId: 'PU 0047',
        pollingUnitName: 'Gwarinpa Primary School',
        wardName: 'Ward 03',
        lgaName: 'AMAC',
        stateName: 'FCT',
      );
      account = _ClaimedAccount(user: user, password: password);
      _claimedAccounts[key] = account;
    }

    if (account == null || account.password != password) {
      throw const AuthException('Invalid User ID or password.');
    }

    // Role and location assigned by backend after successful authentication
    final userWithRole = account.user.copyWith(
      role: account.user.role ?? _determineRole(key),
      pollingUnitId: account.user.pollingUnitId ?? 'PU 0047',
      pollingUnitName: account.user.pollingUnitName ?? 'Gwarinpa Primary School',
      wardName: account.user.wardName ?? 'Ward 03',
      lgaName: account.user.lgaName ?? 'AMAC',
      stateName: account.user.stateName ?? 'FCT',
    );

    _currentUser = userWithRole;
    return userWithRole;
  }

  UserRole _determineRole(String key) {
    if (key.startsWith('admin-')) {
      return UserRole.stateAdmin;
    } else if (key.startsWith('lga-')) {
      return UserRole.lgaAdmin;
    } else if (key.startsWith('ward-')) {
      return UserRole.wardAdmin;
    }
    return UserRole.pollingUnitStaff;
  }

  @override
  Future<UserModel> register({required RegistrationForm form}) async {
    await _authDelay();

    final key = form.userId.trim().toLowerCase();

    // Must be a pre-assigned ID
    final name = _preSeededRoster[key];
    if (name == null) {
      throw const AuthException(
        'This User ID is not recognised. Please contact your administrator.',
      );
    }

    // Cannot claim an already-claimed ID
    if (_claimedAccounts.containsKey(key)) {
      throw const AuthException(
        'This User ID has already been registered. Please log in instead.',
      );
    }

    final newUser = UserModel(
      id: _generateInternalId(),
      userId: form.userId.trim(),
      fullName: name, // always use the authoritative pre-seeded name
      role: null,     // assigned by backend after login
    );

    _claimedAccounts[key] = _ClaimedAccount(user: newUser, password: form.password);
    return newUser;
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _currentUser = null;
  }

  @override
  Future<bool> isAuthenticated() async => _currentUser != null;

  @override
  Future<UserModel?> getCurrentUser() async => _currentUser;

  @override
  Future<void> resetPassword({
    required String userId,
    required String newPassword,
    String? currentPassword,
  }) async {
    await _authDelay();

    final key = userId.trim().toLowerCase();
    final account = _claimedAccounts[key];

    if (account == null) {
      // Check if the ID exists in the roster but hasn't been claimed yet
      if (_preSeededRoster.containsKey(key)) {
        throw const AuthException(
          'This User ID has not been registered yet. Please register first.',
        );
      }
      throw const AuthException('No account found with this User ID.');
    }

    _claimedAccounts[key] = _ClaimedAccount(
      user: account.user,
      password: newPassword,
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _generateInternalId() {
    return 'usr_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Exposed for testing — number of claimed (registered) accounts.
  int get claimedCount => _claimedAccounts.length;

  /// Exposed for testing — number of pre-seeded IDs in the roster.
  int get rosterCount => _preSeededRoster.length;
}

/// Internal claimed account record — password never exposed through UserModel.
class _ClaimedAccount {
  const _ClaimedAccount({required this.user, required this.password});
  final UserModel user;
  final String password; // Would be hashed in production
}
