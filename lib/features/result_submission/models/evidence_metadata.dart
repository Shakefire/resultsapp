// lib/features/result_submission/models/evidence_metadata.dart
import 'location_snapshot.dart';

/// Metadata for captured result sheet photograph or recorded declaration video.
class EvidenceMetadata {
  const EvidenceMetadata({
    required this.localPath,
    this.originalPath,
    this.remotePath,
    required this.mimeType,
    required this.fileSize,
    this.hash,
    this.location,
    required this.capturedAt,
    this.durationSeconds,
  });

  /// Path to processed evidence file (e.g. stamped with top-right metadata)
  final String localPath;

  /// Secure local copy of original raw camera capture (Section 16)
  final String? originalPath;

  /// Remote URL after backend upload confirmation
  final String? remotePath;

  /// e.g. "image/jpeg" or "video/mp4"
  final String mimeType;

  /// File size in bytes
  final int fileSize;

  /// Cryptographic SHA-256 hash of file content if computed
  final String? hash;

  /// Location snapshot acquired at evidence capture moment
  final LocationSnapshot? location;

  /// Device timestamp when capture was finalized
  final DateTime capturedAt;

  /// Duration for video evidence in seconds
  final int? durationSeconds;

  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Map<String, dynamic> toJson() {
    return {
      'localPath': localPath,
      'originalPath': originalPath,
      'remotePath': remotePath,
      'mimeType': mimeType,
      'fileSize': fileSize,
      'hash': hash,
      'location': location?.toJson(),
      'capturedAt': capturedAt.toIso8601String(),
      'durationSeconds': durationSeconds,
    };
  }

  factory EvidenceMetadata.fromJson(Map<String, dynamic> json) {
    return EvidenceMetadata(
      localPath: json['localPath'] as String,
      originalPath: json['originalPath'] as String?,
      remotePath: json['remotePath'] as String?,
      mimeType: json['mimeType'] as String,
      fileSize: json['fileSize'] as int,
      hash: json['hash'] as String?,
      location: json['location'] != null
          ? LocationSnapshot.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      durationSeconds: json['durationSeconds'] as int?,
    );
  }
}
