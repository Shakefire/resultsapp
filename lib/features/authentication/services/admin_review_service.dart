import '../../../core/services/vercel_api_client.dart';
import 'package:url_launcher/url_launcher.dart';

class ReviewSubmission {
  const ReviewSubmission({required this.id, required this.electionId, required this.stateCode,
    required this.lgaCode, required this.wardCode, required this.pollingUnitCode,
    required this.status, required this.revision, required this.figures,
    this.submittedAt, this.decisions = const [], this.evidence = const []});

  final String id;
  final String electionId;
  final String stateCode;
  final String lgaCode;
  final String wardCode;
  final String pollingUnitCode;
  final String status;
  final int revision;
  final Map<String, dynamic> figures;
  final String? submittedAt;
  final List<Map<String, dynamic>> decisions;
  final List<ReviewEvidence> evidence;

  factory ReviewSubmission.fromJson(Map<String, dynamic> json) => ReviewSubmission(
        id: json['id'] as String,
        electionId: json['election_id'] as String,
        stateCode: json['state_code'] as String,
        lgaCode: json['lga_code'] as String,
        wardCode: json['ward_code'] as String,
        pollingUnitCode: json['polling_unit_code'] as String,
        status: json['status'] as String,
        revision: json['revision'] as int,
        figures: Map<String, dynamic>.from(json['figures'] as Map? ?? const {}),
        submittedAt: json['submitted_at'] as String?,
        decisions: (json['decisions'] as List<dynamic>? ?? const [])
            .whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(),
        evidence: (json['evidence'] as List<dynamic>? ?? const [])
            .whereType<Map>().map((item) => ReviewEvidence.fromJson(Map<String, dynamic>.from(item))).toList(),
      );
}

class ReviewEvidence {
  const ReviewEvidence({required this.id, required this.objectKey, required this.type, required this.mimeType});
  final String id;
  final String objectKey;
  final String type;
  final String mimeType;
  factory ReviewEvidence.fromJson(Map<String, dynamic> json) => ReviewEvidence(
    id: json['id'] as String,
    objectKey: json['object_key'] as String,
    type: json['evidence_type'] as String,
    mimeType: json['mime_type'] as String,
  );
}

class StateReport {
  const StateReport({required this.filename, required this.csv, required this.rowCount, required this.generatedAt, this.summaryId, this.sourceIdsHash});
  final String filename;
  final String csv;
  final int rowCount;
  final String generatedAt;
  final String? summaryId;
  final String? sourceIdsHash;
}

class SummaryReadiness {
  const SummaryReadiness({required this.electionId, required this.electionCode, required this.electionName,
    required this.expected, required this.ready, required this.missing, this.verified = 0, this.returned = 0,
    this.approved = 0, this.isApproved = false});
  final String electionId;
  final String electionCode;
  final String electionName;
  final int expected;
  final int verified;
  final int returned;
  final int approved;
  final int missing;
  final bool ready;
  final bool isApproved;

  factory SummaryReadiness.fromJson(Map<String, dynamic> json) => SummaryReadiness(
    electionId: json['electionId'] as String,
    electionCode: json['electionCode'] as String,
    electionName: json['electionName'] as String,
    expected: (json['expected'] as num).toInt(),
    verified: (json['verified'] as num?)?.toInt() ?? 0,
    returned: (json['returned'] as num?)?.toInt() ?? 0,
    approved: json['approved'] is num ? (json['approved'] as num).toInt() : 0,
    missing: (json['missing'] as num).toInt(),
    ready: json['ready'] as bool,
    isApproved: json['isApproved'] == true ||
        json['approved'] == true ||
        json['stateApproved'] == true,
  );
}

class ReviewDashboardOverview {
  const ReviewDashboardOverview({
    required this.ongoingElectionCount,
    required this.electionName,
    required this.electionCode,
    required this.expected,
    required this.approved,
    required this.awaiting,
    required this.submittedUnits,
    required this.returned,
    required this.missing,
    required this.approvalComplete,
    required this.partyVotes,
    required this.partySource,
    this.approvedAt,
  });

  final int ongoingElectionCount;
  final String? electionName;
  final String? electionCode;
  final int expected;
  final int approved;
  final int awaiting;
  final int submittedUnits;
  final int returned;
  final int missing;
  final bool approvalComplete;
  final Map<String, dynamic> partyVotes;
  final String partySource;
  final String? approvedAt;

  factory ReviewDashboardOverview.fromJson(Map<String, dynamic> json) {
    final metrics = Map<String, dynamic>.from(json['metrics'] as Map? ?? const {});
    final election = json['election'] is Map
        ? Map<String, dynamic>.from(json['election'] as Map)
        : const <String, dynamic>{};
    return ReviewDashboardOverview(
      ongoingElectionCount: (json['ongoingElectionCount'] as num?)?.toInt() ?? 0,
      electionName: election['name'] as String?,
      electionCode: election['electionCode'] as String?,
      expected: (metrics['expected'] as num?)?.toInt() ?? 0,
      approved: (metrics['approved'] as num?)?.toInt() ?? 0,
      awaiting: (metrics['awaiting'] as num?)?.toInt() ?? 0,
      submittedUnits: (metrics['submittedUnits'] as num?)?.toInt() ?? 0,
      returned: (metrics['returned'] as num?)?.toInt() ?? 0,
      missing: (metrics['missing'] as num?)?.toInt() ?? 0,
      approvalComplete: metrics['approvalComplete'] as bool? ?? false,
      partyVotes: Map<String, dynamic>.from(json['partyVotes'] as Map? ?? const {}),
      partySource: json['partySource'] as String? ?? 'No approved results yet',
      approvedAt: metrics['approvedAt'] as String?,
    );
  }
}

class ReportElection {
  const ReportElection({required this.id, required this.label});
  final String id;
  final String label;
}

class AdminReviewService {
  AdminReviewService({VercelApiClient? api}) : _api = api ?? VercelApiClient.instance;
  final VercelApiClient _api;

  Future<List<ReviewSubmission>> getQueue() async {
    final response = await _api.get('/api/v1/workflow/review-queue');
    return (response['items'] as List<dynamic>)
        .map((item) => ReviewSubmission.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  Future<void> decide({required String submissionId, required String action, String? reason}) async {
    await _api.post('/api/v1/workflow/decisions', {
      'submissionId': submissionId,
      'action': action,
      'reason': reason,
    });
  }

  Future<List<SummaryReadiness>> getSummaryReadiness() async {
    final response = await _api.get('/api/v1/workflow/summary-readiness');
    return (response['entries'] as List<dynamic>? ?? const [])
        .map((item) => SummaryReadiness.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<ReviewDashboardOverview> getDashboardOverview() async {
    final response = await _api.get('/api/v1/workflow/review-queue?view=overview');
    return ReviewDashboardOverview.fromJson(
      Map<String, dynamic>.from(response['overview'] as Map),
    );
  }

  Future<Map<String, dynamic>> approveSummary(String electionId) async =>
      _api.post('/api/v1/workflow/summary-approvals', {'electionId': electionId});

  Future<void> openEvidence(ReviewEvidence evidence) async {
    final response = await _api.get('/api/v1/evidence/download-url?objectKey=${Uri.encodeQueryComponent(evidence.objectKey)}');
    final opened = await launchUrl(Uri.parse(response['url'] as String), mode: LaunchMode.externalApplication);
    if (!opened) throw const VercelApiException('Could not open the secure evidence link.');
  }

  Future<StateReport> exportStateReport(String electionId) async {
    final response = await _api.get('/api/v1/reports/state-summary?electionId=${Uri.encodeQueryComponent(electionId)}');
    return StateReport(filename: response['filename'] as String, csv: response['csv'] as String,
      rowCount: response['rowCount'] as int, generatedAt: response['generatedAt'] as String,
      summaryId: response['summaryId'] as String?, sourceIdsHash: response['sourceIdsHash'] as String?);
  }

  Future<List<ReportElection>> getReportableElections() async {
    final response = await _api.get('/api/v1/reports/state-summary');
    return (response['elections'] as List<dynamic>? ?? const [])
        .map((item) {
          final election = Map<String, dynamic>.from(item as Map);
          return ReportElection(id: election['id'] as String,
              label: '${election['election_code']} · ${election['name']}');
        }).toList(growable: false);
  }
}
