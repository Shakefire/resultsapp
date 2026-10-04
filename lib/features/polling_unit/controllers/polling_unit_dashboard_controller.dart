// lib/features/polling_unit/controllers/polling_unit_dashboard_controller.dart
import 'package:flutter/foundation.dart';
import '../models/polling_unit_assignment.dart';
import '../models/result_submission.dart';
import '../models/voter_register.dart';
import '../models/recent_activity_item.dart';
import '../repositories/polling_unit_repository.dart';
import '../repositories/vercel_polling_unit_repository.dart';

/// State status for the Polling Unit Dashboard.
enum DashboardStateStatus {
  initial,
  loading,
  loaded,
  error,
}

/// Controller managing data and interaction states for the Polling Unit Staff Dashboard.
class PollingUnitDashboardController extends ChangeNotifier {
  PollingUnitDashboardController({PollingUnitRepository? repository})
      : _repository = repository ?? VercelPollingUnitRepository();

  final PollingUnitRepository _repository;

  DashboardStateStatus _status = DashboardStateStatus.initial;
  String? _errorMessage;

  PollingUnitAssignment? _assignment;
  ResultSubmission? _result;
  VoterRegister? _voterRegister;
  List<RecentActivityItem> _recentActivity = [];

  int _selectedTabIndex = 0;

  // ─── Getters ─────────────────────────────────────────────────────────────
  DashboardStateStatus get status => _status;
  bool get isLoading => _status == DashboardStateStatus.loading || _status == DashboardStateStatus.initial;
  bool get hasError => _status == DashboardStateStatus.error;
  String? get errorMessage => _errorMessage;

  PollingUnitAssignment? get assignment => _assignment;
  ResultSubmission? get result => _result;
  VoterRegister? get voterRegister => _voterRegister;
  List<RecentActivityItem> get recentActivity => _recentActivity;

  int get selectedTabIndex => _selectedTabIndex;

  // ─── Public Actions ──────────────────────────────────────────────────────

  void setTabIndex(int index) {
    if (_selectedTabIndex != index) {
      _selectedTabIndex = index;
      notifyListeners();
    }
  }

  /// Fetches all dashboard state from the repository.
  Future<void> loadDashboard() async {
    _status = DashboardStateStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final assignmentFuture = _repository.getAssignment();
      final resultFuture = _repository.getCurrentResult();
      final registerFuture = _repository.getVoterRegister();
      final activityFuture = _repository.getRecentActivity();

      final results = await Future.wait([
        assignmentFuture,
        resultFuture,
        registerFuture,
        activityFuture,
      ]);

      _assignment = results[0] as PollingUnitAssignment;
      _result = results[1] as ResultSubmission?;
      _voterRegister = results[2] as VoterRegister?;
      _recentActivity = results[3] as List<RecentActivityItem>;

      _status = DashboardStateStatus.loaded;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _status = DashboardStateStatus.error;
      _errorMessage = 'Unable to load dashboard.\nPlease check your connection and try again.';
      notifyListeners();
    }
  }

  /// Retries fetching dashboard data.
  Future<void> retry() => loadDashboard();

  /// Refreshes dashboard data quietly (e.g. pull-to-refresh).
  Future<void> refresh() async {
    try {
      final assignmentFuture = _repository.getAssignment();
      final resultFuture = _repository.getCurrentResult();
      final registerFuture = _repository.getVoterRegister();
      final activityFuture = _repository.getRecentActivity();

      final results = await Future.wait([
        assignmentFuture,
        resultFuture,
        registerFuture,
        activityFuture,
      ]);

      _assignment = results[0] as PollingUnitAssignment;
      _result = results[1] as ResultSubmission?;
      _voterRegister = results[2] as VoterRegister?;
      _recentActivity = results[3] as List<RecentActivityItem>;

      notifyListeners();
    } catch (_) {
      // Quiet refresh error, retain previous state
    }
  }

  Future<void> uploadVoterRegister(String path, {List<int>? bytes, String? fileName}) async {
    await _repository.uploadVoterRegister(path, bytes: bytes, fileName: fileName);
    await refresh();
  }

  Future<String?> getVoterRegisterDownloadUrl() => _repository.getVoterRegisterDownloadUrl();

  Future<String> getEvidenceDownloadUrl(String objectKey) => _repository.getEvidenceDownloadUrl(objectKey);
}
