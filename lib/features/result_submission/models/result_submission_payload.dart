// lib/features/result_submission/models/result_submission_payload.dart
import 'result_figures.dart';
import 'evidence_metadata.dart';
import 'location_snapshot.dart';

/// Payload prepared for network transmission to the electoral backend API (Section 31).
class ResultSubmissionPayload {
  const ResultSubmissionPayload({
    required this.electionId,
    required this.pollingUnitId,
    required this.figures,
    required this.resultPhoto,
    required this.declarationVideo,
    required this.location,
    required this.deviceTimestamp,
  });

  final String electionId;
  final String pollingUnitId;
  final ResultFigures figures;
  final EvidenceMetadata resultPhoto;
  final EvidenceMetadata declarationVideo;
  final LocationSnapshot location;
  final DateTime deviceTimestamp;

  Map<String, dynamic> toJson() {
    return {
      'electionId': electionId,
      'pollingUnitId': pollingUnitId,
      'figures': figures.toJson(),
      'resultPhoto': resultPhoto.toJson(),
      'declarationVideo': declarationVideo.toJson(),
      'location': location.toJson(),
      'deviceTimestamp': deviceTimestamp.toIso8601String(),
    };
  }
}
