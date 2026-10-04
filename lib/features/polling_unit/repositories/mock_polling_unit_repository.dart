// lib/features/polling_unit/repositories/mock_polling_unit_repository.dart
import '../models/polling_unit_assignment.dart';
import '../models/result_submission.dart';
import '../models/voter_register.dart';
import '../models/recent_activity_item.dart';
import 'polling_unit_repository.dart';

/// In-memory mock implementation of [PollingUnitRepository].
/// Populates realistic Nigerian electoral data corresponding to the specification wireframe.
class MockPollingUnitRepository implements PollingUnitRepository {
  MockPollingUnitRepository({
    PollingUnitAssignment? initialAssignment,
    ResultSubmission? initialResult,
    VoterRegister? initialRegister,
    List<RecentActivityItem>? initialActivity,
    this.shouldFail = false,
  })  : _assignment = initialAssignment ??
            const PollingUnitAssignment(
              pollingUnitId: 'PU 0047',
              pollingUnitName: 'Gwarinpa Primary School',
              ward: 'Ward 03',
              lga: 'AMAC',
              state: 'FCT',
              location: 'Gwarinpa Primary School, Abuja',
              delimitationCode: '03-01-03-047',
            ),
        _result = initialResult ?? ResultSubmission.initial(),
        _register = initialRegister ?? VoterRegister.initial(),
        _activities = initialActivity != null ? List.from(initialActivity) : [];

  static final MockPollingUnitRepository _instance = MockPollingUnitRepository();
  factory MockPollingUnitRepository.instance() => _instance;

  PollingUnitAssignment _assignment;
  ResultSubmission _result;
  VoterRegister _register;
  final List<RecentActivityItem> _activities;

  /// Simulates network error for verifying Section 19 error states.
  bool shouldFail;

  Future<void> _simulateNetworkDelay([int ms = 300]) async {
    await Future.delayed(Duration(milliseconds: ms));
  }

  @override
  Future<PollingUnitAssignment> getAssignment() async {
    await _simulateNetworkDelay();
    if (shouldFail) {
      throw Exception('Unable to connect to the electoral network.');
    }
    return _assignment;
  }

  @override
  Future<ResultSubmission?> getCurrentResult() async {
    await _simulateNetworkDelay();
    if (shouldFail) {
      throw Exception('Unable to retrieve current result status.');
    }
    return _result;
  }

  @override
  Future<VoterRegister?> getVoterRegister() async {
    await _simulateNetworkDelay();
    if (shouldFail) {
      throw Exception('Unable to retrieve voter register record.');
    }
    return _register;
  }

  @override
  Future<List<RecentActivityItem>> getRecentActivity() async {
    await _simulateNetworkDelay();
    if (shouldFail) {
      throw Exception('Unable to retrieve activity log.');
    }
    return List.unmodifiable(_activities);
  }

  @override
  Future<void> uploadVoterRegister(String path, {List<int>? bytes, String? fileName}) async {
    await _simulateNetworkDelay();
    simulateVoterRegisterStatus(VoterRegisterStatus.uploaded);
  }

  @override
  Future<String?> getVoterRegisterDownloadUrl() async => null;

  @override
  Future<String> getEvidenceDownloadUrl(String objectKey) async => '';

  // ─── Testing / Operational helpers ───────────────────────────────────────

  void setAssignment(PollingUnitAssignment assignment) {
    _assignment = assignment;
  }

  void setResult(ResultSubmission result) {
    _result = result;
  }

  void setVoterRegister(VoterRegister register) {
    _register = register;
  }

  void addActivity(RecentActivityItem item) {
    _activities.insert(0, item);
  }

  /// Helper to transition Result status for UI verification.
  void simulateResultStatus(ResultStatus status, {String? returnReason}) {
    _result = _result.copyWith(
      status: status,
      submittedAt: status == ResultStatus.notSubmitted ? null : DateTime.now(),
      returnReason: returnReason,
    );
    if (status == ResultStatus.submitted || status == ResultStatus.wardReview) {
      addActivity(RecentActivityItem(
        id: 'act_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Result submitted',
        timestamp: DateTime.now(),
        type: ActivityType.resultSubmitted,
      ));
    } else if (status == ResultStatus.returned) {
      addActivity(RecentActivityItem(
        id: 'act_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Result returned for correction',
        timestamp: DateTime.now(),
        type: ActivityType.resultReturned,
        subtitle: returnReason,
      ));
    } else if (status == ResultStatus.verified) {
      addActivity(RecentActivityItem(
        id: 'act_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Result verified by collation officer',
        timestamp: DateTime.now(),
        type: ActivityType.resultVerified,
      ));
    }
  }

  /// Helper to transition Voter Register status for UI verification.
  void simulateVoterRegisterStatus(VoterRegisterStatus status) {
    _register = _register.copyWith(
      status: status,
      uploadedAt: (status == VoterRegisterStatus.uploaded ||
              status == VoterRegisterStatus.available)
          ? DateTime.now()
          : null,
      fileName: (status != VoterRegisterStatus.notUploaded)
          ? 'PU0047_VOTER_REGISTER.pdf'
          : null,
    );
    if (status == VoterRegisterStatus.uploaded ||
        status == VoterRegisterStatus.available) {
      addActivity(RecentActivityItem(
        id: 'act_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Voter register uploaded',
        timestamp: DateTime.now(),
        type: ActivityType.registerUploaded,
      ));
    }
  }
}
