// lib/features/result_submission/presentation/widgets/step_progress_indicator.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';

/// Clean step progress indicator for the 5-step result submission workflow.
class StepProgressIndicator extends StatelessWidget {
  const StepProgressIndicator({
    super.key,
    required this.currentStep,
    this.totalSteps = 5,
    required this.stepTitle,
  });

  final int currentStep;
  final int totalSteps;
  final String stepTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.horizontalPaddingLarge,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STEP $currentStep OF $totalSteps',
                style: AppTextStyles.inputLabel(color: AppColors.primary).copyWith(
                  letterSpacing: 0.8,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.lock_clock_outlined, size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Draft Auto-Saved',
                    style: AppTextStyles.caption(color: AppColors.textSecondary).copyWith(
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            stepTitle,
            style: AppTextStyles.sectionTitle(color: AppColors.textPrimary).copyWith(
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: currentStep / totalSteps.toDouble(),
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}
