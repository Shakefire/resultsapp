// lib/features/result_submission/presentation/widgets/metadata_safe_zone_badge.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/location_snapshot.dart';

/// Top-Right Metadata Safe Zone Badge for live camera preview and image inspection (Section 12–15).
class MetadataSafeZoneBadge extends StatelessWidget {
  const MetadataSafeZoneBadge({
    super.key,
    required this.pollingUnitId,
    required this.location,
    required this.deviceTimestamp,
  });

  final String pollingUnitId;
  final LocationSnapshot? location;
  final DateTime deviceTimestamp;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy').format(deviceTimestamp).toUpperCase();
    final timeFormat = DateFormat('HH:mm:ss').format(deviceTimestamp);
    final tz = _getTimeZone(deviceTimestamp);

    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(6),
        border: const Border(
          top: BorderSide(color: AppColors.primary, width: 2.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            pollingUnitId.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          if (location != null) ...[
            Text(
              'LAT ${location!.latitude.toStringAsFixed(4)}',
              style: const TextStyle(
                color: Color(0xFFDDE6E0),
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              'LON ${location!.longitude.toStringAsFixed(4)}',
              style: const TextStyle(
                color: Color(0xFFDDE6E0),
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.gps_fixed_rounded,
                  size: 9,
                  color: location!.isAccurate ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24),
                ),
                const SizedBox(width: 3),
                Text(
                  '±${location!.accuracyMeters.toStringAsFixed(0)} m',
                  style: TextStyle(
                    color: location!.isAccurate ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ] else ...[
            const Text(
              'ACQUIRING GPS...',
              style: TextStyle(color: Color(0xFFFBBF24), fontSize: 9.5),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            '$dateFormat · $timeFormat $tz',
            style: const TextStyle(
              color: Color(0xFFB5C4BC),
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  static String _getTimeZone(DateTime dt) {
    final offset = dt.timeZoneOffset.inHours;
    if (offset == 1) return 'WAT';
    if (offset == 0) return 'UTC';
    return 'UTC${offset >= 0 ? '+' : ''}$offset';
  }
}
