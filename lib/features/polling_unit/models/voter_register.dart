// lib/features/polling_unit/models/voter_register.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Enum representing the status of the Polling Unit's voter register PDF.
enum VoterRegisterStatus {
  notUploaded,
  uploading,
  uploaded,
  processing,
  available,
  uploadFailed,
}

extension VoterRegisterStatusExtension on VoterRegisterStatus {
  String get displayTitle {
    switch (this) {
      case VoterRegisterStatus.notUploaded:
        return 'Not uploaded';
      case VoterRegisterStatus.uploading:
        return 'Uploading...';
      case VoterRegisterStatus.uploaded:
        return 'Uploaded';
      case VoterRegisterStatus.processing:
        return 'Processing';
      case VoterRegisterStatus.available:
        return 'Available';
      case VoterRegisterStatus.uploadFailed:
        return 'Upload failed';
    }
  }

  String get defaultDescription {
    switch (this) {
      case VoterRegisterStatus.notUploaded:
        return 'Upload the voter register PDF assigned to this polling unit.';
      case VoterRegisterStatus.uploading:
        return 'Uploading voter register file to the secure server...';
      case VoterRegisterStatus.uploaded:
        return 'Voter register PDF has been uploaded and queued.';
      case VoterRegisterStatus.processing:
        return 'Register document is currently being indexed by the system.';
      case VoterRegisterStatus.available:
        return 'Official voter register verified and available for accreditation.';
      case VoterRegisterStatus.uploadFailed:
        return 'The register could not be uploaded. Please verify the file and retry.';
    }
  }

  String get actionLabel {
    switch (this) {
      case VoterRegisterStatus.notUploaded:
        return 'UPLOAD REGISTER';
      case VoterRegisterStatus.uploadFailed:
        return 'TRY AGAIN';
      case VoterRegisterStatus.uploading:
        return 'UPLOADING...';
      default:
        return 'VIEW REGISTER';
    }
  }

  IconData get statusIcon {
    switch (this) {
      case VoterRegisterStatus.notUploaded:
        return Icons.radio_button_unchecked_rounded;
      case VoterRegisterStatus.uploading:
        return Icons.cloud_upload_outlined;
      case VoterRegisterStatus.uploaded:
      case VoterRegisterStatus.available:
        return Icons.check_circle_rounded;
      case VoterRegisterStatus.processing:
        return Icons.hourglass_top_rounded;
      case VoterRegisterStatus.uploadFailed:
        return Icons.error_outline_rounded;
    }
  }

  Color get statusColor {
    switch (this) {
      case VoterRegisterStatus.notUploaded:
        return AppColors.textSecondary;
      case VoterRegisterStatus.uploading:
      case VoterRegisterStatus.processing:
        return AppColors.warning;
      case VoterRegisterStatus.uploaded:
      case VoterRegisterStatus.available:
        return AppColors.success;
      case VoterRegisterStatus.uploadFailed:
        return AppColors.error;
    }
  }
}

/// Model representing a Polling Unit's Voter Register file.
class VoterRegister {
  const VoterRegister({
    this.id,
    this.fileName,
    required this.status,
    this.uploadedAt,
    this.fileSizeBytes,
    this.uploadProgress,
    this.errorMessage,
  });

  final String? id;
  final String? fileName;
  final VoterRegisterStatus status;
  final DateTime? uploadedAt;
  final int? fileSizeBytes;
  final double? uploadProgress;
  final String? errorMessage;

  factory VoterRegister.initial() {
    return const VoterRegister(
      status: VoterRegisterStatus.notUploaded,
    );
  }

  VoterRegister copyWith({
    String? id,
    String? fileName,
    VoterRegisterStatus? status,
    DateTime? uploadedAt,
    int? fileSizeBytes,
    double? uploadProgress,
    String? errorMessage,
  }) {
    return VoterRegister(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      status: status ?? this.status,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
