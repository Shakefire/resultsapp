import '../models/polling_unit_assignment.dart';
import '../models/recent_activity_item.dart';
import '../models/result_submission.dart';
import '../models/voter_register.dart';
import '../services/polling_unit_remote_service.dart';
import 'polling_unit_repository.dart';

/// Authenticated repository backed by the Vercel workflow API.
class VercelPollingUnitRepository implements PollingUnitRepository {
  VercelPollingUnitRepository({PollingUnitRemoteService? service}) : _service = service ?? PollingUnitRemoteService();
  final PollingUnitRemoteService _service;
  Future<Map<String, dynamic>>? _snapshot;

  Future<Map<String, dynamic>> _records() => _snapshot ??= _service.getMyRecords();

  @override
  Future<PollingUnitAssignment> getAssignment() async {
    _snapshot = _service.getMyRecords();
    final data = await _snapshot!;
    final assignment = Map<String, dynamic>.from(data['assignment'] as Map);
    return PollingUnitAssignment(
      pollingUnitId: assignment['pollingUnitId'] as String,
      pollingUnitName: assignment['pollingUnitName'] as String,
      ward: assignment['ward'] as String,
      lga: assignment['lga'] as String,
      state: assignment['state'] as String,
      delimitationCode: assignment['delimitationCode'] as String?,
    );
  }

  @override
  Future<ResultSubmission?> getCurrentResult() async {
    final data = await _records();
    final submissions = data['submissions'] as List<dynamic>? ?? const [];
    if (submissions.isEmpty) return ResultSubmission.initial();
    final row = Map<String, dynamic>.from(submissions.first as Map);
    final figures = Map<String, dynamic>.from(row['figures'] as Map? ?? const {});
    final decisions = row['decisions'] as List<dynamic>? ?? const [];
    final latestDecision = decisions.isNotEmpty ? Map<String, dynamic>.from(decisions.last as Map) : null;
    String? returnReason;
    if (latestDecision != null && latestDecision['action'] == 'returned') {
      returnReason = latestDecision['reason'] as String?;
    }
    final evidence = (row['evidence'] as List<dynamic>? ?? const []).whereType<Map>().map((item) {
      final file = Map<String, dynamic>.from(item);
      return ResultEvidence(objectKey: file['object_key'] as String, type: file['evidence_type'] as String, mimeType: file['mime_type'] as String);
    }).toList(growable: false);
    final votes = Map<String, dynamic>.from(figures['partyVotes'] as Map? ?? const {}).values
        .whereType<num>().fold<int>(0, (sum, count) => sum + count.toInt());
    return ResultSubmission(
      id: row['id'] as String,
      status: _status(row['status'] as String),
      submittedAt: DateTime.tryParse(row['submitted_at'] as String? ?? ''),
      returnReason: returnReason,
      registeredVoters: (figures['registeredVoters'] as num?)?.toInt(),
      accreditedVoters: (figures['accreditedVoters'] as num?)?.toInt(),
      ballotsCast: votes + ((figures['rejectedVotes'] as num?)?.toInt() ?? 0),
      reviewedBy: latestDecision?['action'] as String?,
      evidence: evidence,
    );
  }

  @override
  Future<VoterRegister?> getVoterRegister() async {
    final data = await _records();
    final value = data['voterRegister'];
    if (value == null) return VoterRegister.initial();
    final row = Map<String, dynamic>.from(value as Map);
    return VoterRegister(
      id: row['id'] as String,
      fileName: row['file_name'] as String? ?? (row['object_key'] as String).split('/').last,
      status: VoterRegisterStatus.uploaded,
      uploadedAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
      fileSizeBytes: (row['file_size_bytes'] as num?)?.toInt(),
    );
  }

  @override
  Future<List<RecentActivityItem>> getRecentActivity() async {
    final data = await _records();
    final items = <RecentActivityItem>[];
    for (final entry in data['submissions'] as List<dynamic>? ?? const []) {
      final row = Map<String, dynamic>.from(entry as Map);
      final timestamp = DateTime.tryParse(row['submitted_at'] as String? ?? '') ?? DateTime.now();
      items.add(RecentActivityItem(id: '${row['id']}-submitted', title: 'Result submitted', timestamp: timestamp, type: ActivityType.resultSubmitted, subtitle: 'Revision ${row['revision']}'));
      for (final event in row['decisions'] as List<dynamic>? ?? const []) {
        final decision = Map<String, dynamic>.from(event as Map);
        final action = decision['action'] as String;
        items.add(RecentActivityItem(
          id: '${row['id']}-$action-${decision['created_at']}',
          title: switch (action) { 'returned' => 'Result returned for correction', 'ward_verified' => 'Result verified by Ward Admin', 'lga_approved' => 'Result approved by LGA Admin', 'state_approved' => 'Result approved by State Admin', _ => 'Result updated' },
          timestamp: DateTime.tryParse(decision['created_at'] as String? ?? '') ?? timestamp,
          type: action == 'returned' ? ActivityType.resultReturned : ActivityType.resultVerified,
          subtitle: decision['reason'] as String?,
        ));
      }
    }
    final register = data['voterRegister'];
    if (register != null) {
      final row = Map<String, dynamic>.from(register as Map);
      items.add(RecentActivityItem(id: 'register-${row['id']}', title: 'Voter register uploaded', timestamp: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(), type: ActivityType.registerUploaded));
    }
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items.take(12).toList(growable: false);
  }

  @override
  Future<void> uploadVoterRegister(String path, {List<int>? bytes, String? fileName}) async {
    await _service.uploadVoterRegister(path, bytes: bytes, fileName: fileName);
    _snapshot = null;
  }

  @override
  Future<String?> getVoterRegisterDownloadUrl() async {
    final data = await _records();
    final value = data['voterRegister'];
    if (value == null) return null;
    final row = Map<String, dynamic>.from(value as Map);
    return _service.getDownloadUrl(row['object_key'] as String);
  }

  @override
  Future<String> getEvidenceDownloadUrl(String objectKey) => _service.getDownloadUrl(objectKey);

  ResultStatus _status(String value) => switch (value) {
      'submitted' => ResultStatus.submitted,
        'ward_verified' => ResultStatus.wardVerified,
        'returned' => ResultStatus.returned,
        'lga_approved' => ResultStatus.lgaVerified,
        'state_approved' => ResultStatus.verified,
        _ => ResultStatus.notSubmitted,
      };
}
