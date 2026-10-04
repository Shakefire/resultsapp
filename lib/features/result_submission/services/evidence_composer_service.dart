// lib/features/result_submission/services/evidence_composer_service.dart
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/location_snapshot.dart';
import '../models/evidence_metadata.dart';

class _ImageProcessingParams {
  final Uint8List rawBytes;
  final String pollingUnitId;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final int timestampMillis;

  const _ImageProcessingParams({
    required this.rawBytes,
    required this.pollingUnitId,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestampMillis,
  });
}

Uint8List _processImageInIsolate(_ImageProcessingParams params) {
  final img.Image? decodedImage = img.decodeImage(params.rawBytes);
  if (decodedImage == null) {
    throw Exception('Unable to decode captured camera image.');
  }

  // Ensure image is oriented correctly
  img.Image orientedImage = img.bakeOrientation(decodedImage);

  // Downscale if wider than 1600px for high performance while maintaining full document legibility
  if (orientedImage.width > 1600) {
    orientedImage = img.copyResize(orientedImage, width: 1600);
  }

  final int imageWidth = orientedImage.width;
  final double scale = (imageWidth / 1200.0).clamp(1.0, 3.5);
  final int margin = (24 * scale).round();
  final int boxWidth = (300 * scale).round();
  final int boxHeight = (150 * scale).round();

  final int boxX = imageWidth - boxWidth - margin;
  final int boxY = margin;

  // Semi-transparent dark background for maximum legibility over white sheets
  img.fillRect(
    orientedImage,
    x1: boxX,
    y1: boxY,
    x2: boxX + boxWidth,
    y2: boxY + boxHeight,
    color: img.ColorRgba8(18, 28, 22, 210), // Deep institutional charcoal tint
  );

  // Subtle 2px primary green top-accent border
  img.fillRect(
    orientedImage,
    x1: boxX,
    y1: boxY,
    x2: boxX + boxWidth,
    y2: boxY + (4 * scale).round(),
    color: img.ColorRgba8(8, 116, 67, 255), // AppColors.primary green
  );

  final dt = DateTime.fromMillisecondsSinceEpoch(params.timestampMillis);
  final timeFormat = DateFormat('HH:mm:ss');
  final dateFormat = DateFormat('dd MMM yyyy').format(dt).toUpperCase();
  final tzName = EvidenceComposerService.getTimeZoneAbbreviation(dt);

  final List<String> lines = [
    params.pollingUnitId.toUpperCase(),
    'LAT ${params.latitude.toStringAsFixed(5)}',
    'LON ${params.longitude.toStringAsFixed(5)}',
    'ACCURACY ±${params.accuracyMeters.toStringAsFixed(0)}m',
    '$dateFormat · ${timeFormat.format(dt)} $tzName',
  ];

  int textY = boxY + (14 * scale).round();
  final int textX = boxX + (16 * scale).round();
  final int lineSpacing = (24 * scale).round();

  for (final line in lines) {
    img.drawString(
      orientedImage,
      line,
      font: scale > 1.8 ? img.arial24 : img.arial14,
      x: textX,
      y: textY,
      color: img.ColorRgba8(255, 255, 255, 255),
    );
    textY += lineSpacing;
  }

  final List<int> encodedBytes = img.encodeJpg(orientedImage, quality: 88);
  return Uint8List.fromList(encodedBytes);
}

/// High-performance evidence composition service.
/// Stamps official verification metadata into the TOP-RIGHT CORNER of captured result sheets (Section 12–17).
class EvidenceComposerService {
  EvidenceComposerService();

  /// Composes a high-readability verification overlay onto the captured image.
  /// Retains the original raw image (Section 16) and generates a processed evidence copy.
  Future<EvidenceMetadata> composeResultSheetEvidence({
    required String sourceImagePath,
    required String pollingUnitId,
    required LocationSnapshot location,
    required DateTime deviceTimestamp,
  }) async {
    final Uint8List rawBytes;
    if (kIsWeb) {
      try {
        final xfile = XFile(sourceImagePath);
        rawBytes = await xfile.readAsBytes();
      } catch (_) {
        throw Exception('Source evidence image not accessible on web.');
      }
    } else {
      final sourceFile = File(sourceImagePath);
      if (!await sourceFile.exists()) {
        throw Exception('Source evidence image not found at $sourceImagePath');
      }
      rawBytes = await sourceFile.readAsBytes();
    }

    final String originalCopyPath;
    final String processedPath;
    final timestampStr = DateFormat('yyyyMMdd_HHmmss').format(deviceTimestamp);

    if (kIsWeb) {
      originalCopyPath = 'RAW_${pollingUnitId.replaceAll(' ', '_')}_$timestampStr.jpg';
      processedPath = sourceImagePath;
    } else {
      // Target evidence directory setup
      final appDir = await getApplicationDocumentsDirectory();
      final originalsDir = Directory('${appDir.path}/evidence/originals');
      final processedDir = Directory('${appDir.path}/evidence/processed');
      await originalsDir.create(recursive: true);
      await processedDir.create(recursive: true);

      originalCopyPath =
          '${originalsDir.path}/RAW_${pollingUnitId.replaceAll(' ', '_')}_$timestampStr.jpg';
      processedPath =
          '${processedDir.path}/EVIDENCE_${pollingUnitId.replaceAll(' ', '_')}_$timestampStr.jpg';

      // Preserve original capture safely (Section 16)
      await File(sourceImagePath).copy(originalCopyPath);
    }

    // Run heavy image operations in a background isolate
    final params = _ImageProcessingParams(
      rawBytes: rawBytes,
      pollingUnitId: pollingUnitId,
      latitude: location.latitude,
      longitude: location.longitude,
      accuracyMeters: location.accuracyMeters,
      timestampMillis: deviceTimestamp.millisecondsSinceEpoch,
    );

    final Uint8List encodedBytes = await compute(_processImageInIsolate, params);

    if (!kIsWeb) {
      final processedFile = File(processedPath);
      await processedFile.writeAsBytes(encodedBytes);
    }

    // Calculate SHA-256 checksum for audit validation
    final digest = sha256.convert(encodedBytes);

    return EvidenceMetadata(
      localPath: processedPath,
      originalPath: originalCopyPath,
      mimeType: 'image/jpeg',
      fileSize: encodedBytes.length,
      hash: digest.toString(),
      location: location,
      capturedAt: deviceTimestamp,
    );
  }

  static String getTimeZoneAbbreviation(DateTime dt) {
    final offsetHours = dt.timeZoneOffset.inHours;
    if (offsetHours == 1) return 'WAT'; // West Africa Time (Nigeria)
    if (offsetHours == 0) return 'UTC';
    final sign = offsetHours >= 0 ? '+' : '-';
    return 'UTC$sign${offsetHours.abs()}';
  }
}
