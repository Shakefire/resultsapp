// lib/features/polling_unit/models/result_submission.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Enum representing the verification lifecycle states of a polling unit result.
enum ResultStatus {
  notSubmitted,
  submitted,
  wardReview,
  wardVerified,
  returned,
  lgaReview,
  lgaVerified,
  stateReview,
  verified,
}

extension ResultStatusExtension on ResultStatus {
  /// Clean human-readable title for the status card.
  String get displayTitle {
    switch (this) {
      case ResultStatus.notSubmitted:
        return 'Not submitted';
      case ResultStatus.submitted:
        return 'Submitted';
      case ResultStatus.wardReview:
        return 'Under Ward Review';
      case ResultStatus.wardVerified:
        return 'Ward Verified';
      case ResultStatus.returned:
        return 'Correction required';
      case ResultStatus.lgaReview:
        return 'Under LGA Review';
      case ResultStatus.lgaVerified:
        return 'LGA Verified';
      case ResultStatus.stateReview:
        return 'Under State Review';
      case ResultStatus.verified:
        return 'Verified';
    }
  }

  /// Default descriptive text explaining current result status.
  String get defaultDescription {
    switch (this) {
      case ResultStatus.notSubmitted:
        return 'No result has been submitted for this polling unit yet.';
      case ResultStatus.submitted:
        return 'Result uploaded successfully and queued for review.';
      case ResultStatus.wardReview:
        return 'Your submission is being reviewed by the Ward Collation Officer.';
      case ResultStatus.wardVerified:
        return 'Ward Collation completed. Awaiting LGA review.';
      case ResultStatus.returned:
        return 'Your result was returned by the Ward Administrator.';
      case ResultStatus.lgaReview:
        return 'Result currently undergoing LGA collation review.';
      case ResultStatus.lgaVerified:
        return 'LGA Collation verified. Forwarded for State review.';
      case ResultStatus.stateReview:
        return 'Result is undergoing State-level verification.';
      case ResultStatus.verified:
        return 'Your result has completed the verification process.';
    }
  }

  /// Action button label for the card.
  String get actionLabel {
    switch (this) {
      case ResultStatus.notSubmitted:
        return 'SUBMIT RESULT';
      case ResultStatus.returned:
        return 'CORRECT & RESUBMIT';
      case ResultStatus.verified:
        return 'VIEW RESULT';
      default:
        return 'VIEW SUBMISSION';
    }
  }

  /// Primary icon representing this status (text + iconography, no color alone).
  IconData get statusIcon {
    switch (this) {
      case ResultStatus.notSubmitted:
        return Icons.radio_button_unchecked_rounded;
      case ResultStatus.submitted:
      case ResultStatus.wardReview:
      case ResultStatus.lgaReview:
      case ResultStatus.stateReview:
        return Icons.schedule_rounded;
      case ResultStatus.wardVerified:
      case ResultStatus.lgaVerified:
      case ResultStatus.verified:
        return Icons.check_circle_rounded;
      case ResultStatus.returned:
        return Icons.error_outline_rounded;
    }
  }

  /// Status tint color.
  Color get statusColor {
    switch (this) {
      case ResultStatus.notSubmitted:
        return AppColors.textSecondary;
      case ResultStatus.submitted:
      case ResultStatus.wardReview:
      case ResultStatus.lgaReview:
      case ResultStatus.stateReview:
        return AppColors.warning;
      case ResultStatus.wardVerified:
      case ResultStatus.lgaVerified:
      case ResultStatus.verified:
        return AppColors.success;
      case ResultStatus.returned:
        return AppColors.error;
    }
  }

  /// Light background tint for status indicator badge.
  Color get statusLightColor {
    switch (this) {
      case ResultStatus.notSubmitted:
        return AppColors.background;
      case ResultStatus.submitted:
      case ResultStatus.wardReview:
      case ResultStatus.lgaReview:
      case ResultStatus.stateReview:
        return AppColors.warningLight;
      case ResultStatus.wardVerified:
      case ResultStatus.lgaVerified:
      case ResultStatus.verified:
        return AppColors.successLight;
      case ResultStatus.returned:
        return AppColors.errorLight;
    }
  }
}

/// Model representing a Polling Unit's result submission record.
class ResultSubmission {
  const ResultSubmission({
    required this.id,
    required this.status,
    this.submittedAt,
    this.returnReason,
    this.registeredVoters,
    this.accreditedVoters,
    this.ballotsCast,
    this.reviewedBy,
    this.evidence = const [],
  });

  final String id;
  final ResultStatus status;
  final DateTime? submittedAt;
  final String? returnReason;
  final int? registeredVoters;
  final int? accreditedVoters;
  final int? ballotsCast;
  final String? reviewedBy;
  final List<ResultEvidence> evidence;

  /// Helper factory for an unsubmitted initial state.
  factory ResultSubmission.initial() {
    return const ResultSubmission(
      id: 'res_draft',
      status: ResultStatus.notSubmitted,
    );
  }

  ResultSubmission copyWith({
    String? id,
    ResultStatus? status,
    DateTime? submittedAt,
    String? returnReason,
    int? registeredVoters,
    int? accreditedVoters,
    int? ballotsCast,
    String? reviewedBy,
  }) {
    return ResultSubmission(
      id: id ?? this.id,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      returnReason: returnReason ?? this.returnReason,
      registeredVoters: registeredVoters ?? this.registeredVoters,
      accreditedVoters: accreditedVoters ?? this.accreditedVoters,
      ballotsCast: ballotsCast ?? this.ballotsCast,
      reviewedBy: reviewedBy ?? this.reviewedBy,
    );
  }
}

class ResultEvidence {
  const ResultEvidence({required this.objectKey, required this.type, required this.mimeType});
  final String objectKey;
  final String type;
  final String mimeType;
}
