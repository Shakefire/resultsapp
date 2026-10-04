// lib/features/polling_unit/presentation/screens/results_tab_screen.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_border_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../controllers/polling_unit_dashboard_controller.dart';
import '../../models/result_submission.dart';

/// Screen rendered within the 'Results' tab of the bottom navigation.
class ResultsTabScreen extends StatelessWidget {
  const ResultsTabScreen({
    super.key,
    required this.controller,
    required this.onSubmitResultPressed,
    required this.onViewSubmissionPressed,
  });

  final PollingUnitDashboardController controller;
  final VoidCallback onSubmitResultPressed;
  final VoidCallback onViewSubmissionPressed;

  @override
  Widget build(BuildContext context) {
    final result = controller.result;
    final assignment = controller.assignment;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.horizontalPaddingLarge,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Results & Submission History', style: AppTextStyles.screenTitle()),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Track result processing and collation status for your assigned polling unit.',
            style: AppTextStyles.subtitle(),
          ),

          const SizedBox(height: AppSpacing.xxl),

          if (result == null || result.status == ResultStatus.notSubmitted) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppBorderRadius.card,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.assignment_late_outlined,
                    size: 48,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No Submission Yet',
                    style: AppTextStyles.sectionTitle(),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'When voting concludes, record figures and submit result for verification.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    onPressed: onSubmitResultPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppBorderRadius.button,
                      ),
                    ),
                    child: const Text('SUBMIT RESULT'),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppBorderRadius.card,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        assignment?.pollingUnitId ?? 'POLLING UNIT',
                        style: AppTextStyles.inputLabel(color: AppColors.primary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: result.status.statusLightColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          result.status.displayTitle,
                          style: AppTextStyles.caption(color: result.status.statusColor).copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    assignment?.pollingUnitName ?? '',
                    style: AppTextStyles.sectionTitle(),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    assignment != null ? '${assignment.wardAndLga}, ${assignment.state}' : '',
                    style: AppTextStyles.bodySmall(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Status', style: AppTextStyles.bodySmall()),
                      Text(
                        result.status.displayTitle,
                        style: AppTextStyles.body(color: result.status.statusColor).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onViewSubmissionPressed,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppBorderRadius.button,
                        ),
                      ),
                      child: const Text('VIEW SUBMISSION DETAILS'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
