// lib/features/polling_unit/models/recent_activity_item.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

enum ActivityType {
  resultSubmitted,
  resultReturned,
  resultVerified,
  registerUploaded,
  general,
}

extension ActivityTypeExtension on ActivityType {
  IconData get icon {
    switch (this) {
      case ActivityType.resultSubmitted:
        return Icons.send_outlined;
      case ActivityType.resultReturned:
        return Icons.assignment_return_outlined;
      case ActivityType.resultVerified:
        return Icons.verified_outlined;
      case ActivityType.registerUploaded:
        return Icons.upload_file_outlined;
      case ActivityType.general:
        return Icons.circle_notifications_outlined;
    }
  }

  Color get iconColor {
    switch (this) {
      case ActivityType.resultReturned:
        return AppColors.error;
      case ActivityType.resultVerified:
      case ActivityType.registerUploaded:
        return AppColors.success;
      case ActivityType.resultSubmitted:
        return AppColors.primary;
      case ActivityType.general:
        return AppColors.textSecondary;
    }
  }
}

/// Compact representation of an operational action performed at the Polling Unit.
class RecentActivityItem {
  const RecentActivityItem({
    required this.id,
    required this.title,
    required this.timestamp,
    required this.type,
    this.subtitle,
  });

  final String id;
  final String title;
  final DateTime timestamp;
  final ActivityType type;
  final String? subtitle;

  /// Returns a humanized relative timestamp string, e.g. "Today · 10:42 AM"
  String get formattedTimestamp {
    final now = DateTime.now();
    final isToday = now.year == timestamp.year &&
        now.month == timestamp.month &&
        now.day == timestamp.day;

    final hour = timestamp.hour > 12
        ? timestamp.hour - 12
        : (timestamp.hour == 0 ? 12 : timestamp.hour);
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minute $period';

    if (isToday) {
      return 'Today · $timeStr';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = yesterday.year == timestamp.year &&
        yesterday.month == timestamp.month &&
        yesterday.day == timestamp.day;

    if (isYesterday) {
      return 'Yesterday · $timeStr';
    }

    return '${timestamp.day} ${_monthName(timestamp.month)} · $timeStr';
  }

  static String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }
}
