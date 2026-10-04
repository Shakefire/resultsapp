// lib/features/polling_unit/presentation/widgets/recent_activity_section.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_border_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../models/recent_activity_item.dart';

/// Compact recent activity section on the Polling Unit Dashboard.
class RecentActivitySection extends StatelessWidget {
  const RecentActivitySection({
    super.key,
    required this.activities,
  });

  final List<RecentActivityItem> activities;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            'RECENT ACTIVITY',
            style: AppTextStyles.inputLabel(color: AppColors.textSecondary).copyWith(
              letterSpacing: 0.8,
              fontSize: 11,
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppBorderRadius.card,
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: activities.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xl,
                  ),
                  child: Center(
                    child: Text(
                      'No recent activity',
                      style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  itemCount: activities.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 48,
                    color: AppColors.border,
                  ),
                  itemBuilder: (context, index) {
                    final item = activities[index];
                    return _ActivityTile(item: item);
                  },
                ),
        ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});
  final RecentActivityItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              item.type.icon,
              size: 15,
              color: item.type.iconColor,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTextStyles.body(color: AppColors.textPrimary).copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.formattedTimestamp,
                  style: AppTextStyles.caption(color: AppColors.textSecondary),
                ),
                if (item.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle!,
                    style: AppTextStyles.caption(color: AppColors.error),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
