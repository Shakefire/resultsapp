// lib/features/result_submission/presentation/widgets/camera_overlay_widget.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/location_snapshot.dart';
import 'metadata_safe_zone_badge.dart';

/// Guided camera overlay with document bounding box, corner guides, touch-focus, and metadata safe zone (Section 6–15).
class CameraOverlayWidget extends StatelessWidget {
  const CameraOverlayWidget({
    super.key,
    required this.pollingUnitId,
    required this.location,
    required this.deviceTimestamp,
    required this.onCapturePressed,
    required this.onFlashTogglePressed,
    required this.flashModeLabel,
    required this.isCapturing,
    this.focusPoint,
    this.isDocumentAligned = false,
    this.currentZoom = 1.0,
    this.onZoomIn,
    this.onZoomOut,
  });

  final String pollingUnitId;
  final LocationSnapshot? location;
  final DateTime deviceTimestamp;
  final VoidCallback onCapturePressed;
  final VoidCallback onFlashTogglePressed;
  final String flashModeLabel;
  final bool isCapturing;
  final Offset? focusPoint;
  final bool isDocumentAligned;
  final double currentZoom;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Dimmed mask with transparent document cutout & corner guides (Section 7)
        CustomPaint(
          painter: _BoundingBoxPainter(isAligned: isDocumentAligned),
        ),

        // 2. Touch Focus Indicator (Section 9)
        if (focusPoint != null)
          Positioned(
            left: focusPoint!.dx - 28,
            top: focusPoint!.dy - 28,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

        // 3. Top-Right Metadata Safe Zone (Section 12 & 13)
        Positioned(
          top: 16,
          right: 16,
          child: MetadataSafeZoneBadge(
            pollingUnitId: pollingUnitId,
            location: location,
            deviceTimestamp: deviceTimestamp,
          ),
        ),

        // 4. Top Controls (Flash toggle, alignment badge)
        Positioned(
          top: 16,
          left: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: Icon(
                  _getFlashIcon(flashModeLabel),
                  color: Colors.white,
                  size: 22,
                ),
                tooltip: 'Flash: $flashModeLabel',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                ),
                onPressed: onFlashTogglePressed,
              ),
              const SizedBox(height: 8),
              // Document Alignment feedback pill (Section 8)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDocumentAligned
                      ? AppColors.primary.withValues(alpha: 0.85)
                      : Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDocumentAligned ? Icons.check_circle_outline : Icons.crop_free,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isDocumentAligned ? 'Document Aligned' : 'Align Result Form',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 5. Guidance text above bottom shutter
        Positioned(
          bottom: 110,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Hold steady · Ensure result figures are sharp and visible',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),

        // 6. Bottom Controls: Shutter button & zoom (Section 6 & 10)
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Zoom out
              if (onZoomOut != null)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
                  onPressed: onZoomOut,
                  tooltip: 'Zoom Out',
                )
              else
                const SizedBox(width: 48),

              // Capture Shutter Button
              GestureDetector(
                onTap: isCapturing ? null : onCapturePressed,
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCapturing ? AppColors.textDisabled : AppColors.primary,
                    ),
                    child: isCapturing
                        ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          )
                        : const Icon(Icons.camera_alt, color: Colors.white, size: 28),
                  ),
                ),
              ),

              // Zoom in
              if (onZoomIn != null)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                  onPressed: onZoomIn,
                  tooltip: 'Zoom In (${currentZoom.toStringAsFixed(1)}x)',
                )
              else
                const SizedBox(width: 48),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getFlashIcon(String label) {
    if (label == 'On') return Icons.flash_on;
    if (label == 'Auto') return Icons.flash_auto;
    return Icons.flash_off;
  }
}

/// Custom painter rendering document frame cutout with crisp corner guides (Section 7).
class _BoundingBoxPainter extends CustomPainter {
  _BoundingBoxPainter({required this.isAligned});
  final bool isAligned;

  @override
  void paint(Canvas canvas, Size size) {
    // Standard A4 result sheet aspect ratio box (~1:1.4)
    final double boxWidth = (size.width * 0.82).clamp(260.0, 480.0);
    final double boxHeight = boxWidth * 1.35;

    final double left = (size.width - boxWidth) / 2;
    final double top = (size.height - boxHeight) / 2 - 20;
    final rect = Rect.fromLTWH(left, top, boxWidth, boxHeight);

    // Subtle dark scrim outside the document zone
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)))
      ..fillType = PathFillType.evenOdd;

    final scrimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawPath(backgroundPath, scrimPaint);

    // Subtle guide line
    final guidePaint = Paint()
      ..color = isAligned
          ? const Color(0xFF4ADE80).withValues(alpha: 0.8)
          : Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), guidePaint);

    // Prominent corner brackets (Section 7)
    final cornerPaint = Paint()
      ..color = isAligned ? const Color(0xFF4ADE80) : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const cornerLength = 26.0;

    // Top-Left
    canvas.drawLine(Offset(left, top + cornerLength), Offset(left, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), cornerPaint);

    // Top-Right
    canvas.drawLine(Offset(left + boxWidth - cornerLength, top), Offset(left + boxWidth, top), cornerPaint);
    canvas.drawLine(Offset(left + boxWidth, top), Offset(left + boxWidth, top + cornerLength), cornerPaint);

    // Bottom-Left
    canvas.drawLine(Offset(left, top + boxHeight - cornerLength), Offset(left, top + boxHeight), cornerPaint);
    canvas.drawLine(Offset(left, top + boxHeight), Offset(left + cornerLength, top + boxHeight), cornerPaint);

    // Bottom-Right
    canvas.drawLine(Offset(left + boxWidth - cornerLength, top + boxHeight), Offset(left + boxWidth, top + boxHeight), cornerPaint);
    canvas.drawLine(Offset(left + boxWidth, top + boxHeight - cornerLength), Offset(left + boxWidth, top + boxHeight), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _BoundingBoxPainter oldDelegate) =>
      oldDelegate.isAligned != isAligned;
}
