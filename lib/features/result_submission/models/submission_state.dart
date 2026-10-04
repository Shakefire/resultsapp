// lib/features/result_submission/models/submission_state.dart
import 'result_figures.dart';
import 'evidence_metadata.dart';
import 'location_snapshot.dart';

/// State machine for result submission lifecycle (Section 24).
enum SubmissionLifecycleState {
  draft,
  readyForSubmission,
  uploading,
  submitting,
  submitted,
  uploadFailed,
}

extension SubmissionLifecycleStateExtension on SubmissionLifecycleState {
  String get displayTitle {
    switch (this) {
      case SubmissionLifecycleState.draft:
        return 'Draft in Progress';
      case SubmissionLifecycleState.readyForSubmission:
        return 'Ready for Submission';
      case SubmissionLifecycleState.uploading:
        return 'Uploading Evidence...';
      case SubmissionLifecycleState.submitting:
        return 'Submitting to Backend...';
      case SubmissionLifecycleState.submitted:
        return 'Submitted Successfully';
      case SubmissionLifecycleState.uploadFailed:
        return 'Upload Failed';
    }
  }
}

/// Comprehensive local submission draft model that survives app restarts (Section 25).
class ResultSubmissionDraft {
  ResultSubmissionDraft({
    required this.pollingUnitId,
    required this.electionId,
    ResultFigures? figures,
    this.resultPhoto,
    this.declarationVideo,
    this.location,
    DateTime? deviceTimestamp,
    this.state = SubmissionLifecycleState.draft,
    this.serverConfirmationCode,
    this.uploadError,
  })  : figures = figures ?? const ResultFigures(),
        deviceTimestamp = deviceTimestamp ?? DateTime.now();

  final String pollingUnitId;
  String electionId;
  ResultFigures figures;
  EvidenceMetadata? resultPhoto;
  EvidenceMetadata? declarationVideo;
  LocationSnapshot? location;
  DateTime deviceTimestamp;
  SubmissionLifecycleState state;
  String? serverConfirmationCode;
  String? uploadError;

  bool get hasFigures => figures.totalValidVotes > 0;
  bool get hasPhoto => resultPhoto != null;
  bool get hasVideo => declarationVideo != null;
  bool get hasLocation => location != null;

  /// Progress ratio across the 4 primary capture stages (0.0 to 1.0).
  double get completionRatio {
    int completed = 0;
    if (hasFigures) completed++;
    if (hasPhoto) completed++;
    if (hasVideo) completed++;
    if (hasLocation) completed++;
    return completed / 4.0;
  }

  /// True when all required evidence items are completed.
  bool get isComplete => hasFigures && hasPhoto && hasVideo && hasLocation;

  Map<String, dynamic> toJson() {
    return {
      'pollingUnitId': pollingUnitId,
      'electionId': electionId,
      'figures': figures.toJson(),
      'resultPhoto': resultPhoto?.toJson(),
      'declarationVideo': declarationVideo?.toJson(),
      'location': location?.toJson(),
      'deviceTimestamp': deviceTimestamp.toIso8601String(),
      'state': state.name,
      'serverConfirmationCode': serverConfirmationCode,
      'uploadError': uploadError,
    };
  }

  factory ResultSubmissionDraft.fromJson(Map<String, dynamic> json) {
    return ResultSubmissionDraft(
      pollingUnitId: json['pollingUnitId'] as String,
      electionId: json['electionId'] as String? ?? 'ELEC-2026-PRESIDENTIAL',
      figures: json['figures'] != null
          ? ResultFigures.fromJson(json['figures'] as Map<String, dynamic>)
          : const ResultFigures(),
      resultPhoto: json['resultPhoto'] != null
          ? EvidenceMetadata.fromJson(json['resultPhoto'] as Map<String, dynamic>)
          : null,
      declarationVideo: json['declarationVideo'] != null
          ? EvidenceMetadata.fromJson(json['declarationVideo'] as Map<String, dynamic>)
          : null,
      location: json['location'] != null
          ? LocationSnapshot.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      deviceTimestamp: json['deviceTimestamp'] != null
          ? DateTime.parse(json['deviceTimestamp'] as String)
          : DateTime.now(),
      state: SubmissionLifecycleState.values.firstWhere(
        (s) => s.name == json['state'],
        orElse: () => SubmissionLifecycleState.draft,
      ),
      serverConfirmationCode: json['serverConfirmationCode'] as String?,
      uploadError: json['uploadError'] as String?,
    );
  }
}
