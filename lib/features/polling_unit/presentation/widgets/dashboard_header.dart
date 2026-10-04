// lib/features/polling_unit/presentation/widgets/dashboard_header.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';

/// Standard authenticated screen header for the Polling Unit Staff Dashboard.
/// Features a minimal top utility bar (Menu / Notifications) and dynamic time-based greeting.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.userName,
    this.onMenuPressed,
    this.onNotificationsPressed,
    this.unreadNotificationsCount = 0,
  });

  final String userName;
  final VoidCallback? onMenuPressed;
  final VoidCallback? onNotificationsPressed;
  final int unreadNotificationsCount;

  /// Dynamic greeting computed from device time:
  /// - Morning: 05:00 - 11:59
  /// - Afternoon: 12:00 - 16:59
  /// - Evening: 17:00 - 04:59
  static String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    final greeting = getGreeting();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top utility row: Menu & Notifications
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary),
              onPressed: onMenuPressed,
              tooltip: 'Menu',
              splashRadius: 24,
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.textPrimary,
                  ),
                  onPressed: onNotificationsPressed,
                  tooltip: 'Notifications',
                  splashRadius: 24,
                ),
                if (unreadNotificationsCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.md),

        // Greeting and dynamic staff name
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: AppTextStyles.subtitle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                userName.isNotEmpty ? userName : 'Polling Unit Staff',
                style: AppTextStyles.screenTitle(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
