// lib/features/polling_unit/repositories/polling_unit_repository.dart
import '../models/polling_unit_assignment.dart';
import '../models/result_submission.dart';
import '../models/voter_register.dart';
import '../models/recent_activity_item.dart';

/// Abstract repository defining data operations for the Polling Unit operational screen.
/// Swap this with an API-backed repository when the backend is connected.
abstract class PollingUnitRepository {
  /// Fetches the authenticated staff member's assigned polling unit info.
  Future<PollingUnitAssignment> getAssignment();

  /// Fetches the latest result submission record for this polling unit.
  Future<ResultSubmission?> getCurrentResult();

  /// Fetches the voter register status and metadata.
  Future<VoterRegister?> getVoterRegister();

  /// Fetches the recent operational activity log entries.
  Future<List<RecentActivityItem>> getRecentActivity();

  /// Uploads a voter register through the private object-storage flow.
  Future<void> uploadVoterRegister(String path, {List<int>? bytes, String? fileName});

  /// Returns a short-lived URL for the assigned polling unit's voter register.
  Future<String?> getVoterRegisterDownloadUrl();

  Future<String> getEvidenceDownloadUrl(String objectKey);
}
