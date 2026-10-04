// lib/features/polling_unit/presentation/screens/alerts_tab_screen.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_border_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../controllers/polling_unit_dashboard_controller.dart';
import '../../models/result_submission.dart';

/// Screen rendered within the 'Alerts' tab of the bottom navigation.
class AlertsTabScreen extends StatelessWidget {
  const AlertsTabScreen({
    super.key,
    required this.controller,
  });

  final PollingUnitDashboardController controller;

  @override
  Widget build(BuildContext context) {
    final result = controller.result;
    final isReturned = result?.status == ResultStatus.returned;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.horizontalPaddingLarge,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Operational Alerts', style: AppTextStyles.screenTitle()),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'System notices and review communications from your Ward Collation Officer.',
            style: AppTextStyles.subtitle(),
          ),

          const SizedBox(height: AppSpacing.xxl),

          if (isReturned) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: AppBorderRadius.card,
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Correction Required',
                        style: AppTextStyles.sectionTitle(color: AppColors.error),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Your submitted polling unit result was returned by the Ward Collation Officer.',
                    style: AppTextStyles.body(color: AppColors.textPrimary),
                  ),
                  if (result?.returnReason != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Note: ${result!.returnReason!}',
                      style: AppTextStyles.caption(color: AppColors.error),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Broadcast alerts / system notice
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppBorderRadius.card,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.campaign_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Electoral Operations Active',
                        style: AppTextStyles.body(color: AppColors.textPrimary).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Please ensure voter register verification is confirmed before concluding accreditation.',
                        style: AppTextStyles.bodySmall(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
