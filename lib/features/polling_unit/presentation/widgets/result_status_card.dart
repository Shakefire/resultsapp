// lib/features/polling_unit/presentation/widgets/result_status_card.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_border_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../authentication/presentation/widgets/primary_button.dart';
import '../../models/result_submission.dart';

/// The primary functional card on the Polling Unit Dashboard for result management.
class ResultStatusCard extends StatelessWidget {
  const ResultStatusCard({
    super.key,
    required this.result,
    required this.onActionPressed,
    this.isLoading = false,
  });

  final ResultSubmission result;
  final VoidCallback onActionPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final status = result.status;
    final statusTitle = status.displayTitle;
    final statusIcon = status.statusIcon;
    final statusColor = status.statusColor;
    final statusBgColor = status.statusLightColor;
    final actionLabel = status.actionLabel;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppBorderRadius.card,
        border: Border.all(
          color: status == ResultStatus.returned
              ? AppColors.error.withValues(alpha: 0.5)
              : AppColors.border,
          width: status == ResultStatus.returned ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Heading & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RESULT',
                style: AppTextStyles.inputLabel(color: AppColors.textSecondary).copyWith(
                  letterSpacing: 0.8,
                  fontSize: 11,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: statusColor.withValues(alpha: 0.2), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusTitle,
                      style: AppTextStyles.caption(color: statusColor).copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Primary Status Title
          Text(
            statusTitle,
            style: AppTextStyles.sectionTitle(color: AppColors.textPrimary).copyWith(
              fontSize: 19,
            ),
          ),

          const SizedBox(height: AppSpacing.xs),

          // Status Description / Context
          Text(
            _buildDescription(),
            style: AppTextStyles.bodySmall(color: AppColors.textSecondary).copyWith(
              height: 1.45,
            ),
          ),

          // Optional Return Reason Banner when returned
          if (status == ResultStatus.returned && result.returnReason != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Reason: ${result.returnReason}',
                      style: AppTextStyles.caption(color: AppColors.error).copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          // Dominant Call-To-Action Button (PrimaryButton treatment)
          PrimaryButton(
            label: actionLabel,
            isLoading: isLoading,
            onPressed: onActionPressed,
          ),
        ],
      ),
    );
  }

  String _buildDescription() {
    if (result.status == ResultStatus.submitted ||
        result.status == ResultStatus.wardReview ||
        result.status == ResultStatus.wardVerified ||
        result.status == ResultStatus.lgaReview ||
        result.status == ResultStatus.lgaVerified ||
        result.status == ResultStatus.stateReview) {
      if (result.submittedAt != null) {
        return 'Submitted ${_formatDate(result.submittedAt!)}';
      }
    }
    return result.status.defaultDescription;
  }

  String _formatDate(DateTime dt) {
    final hour = dt.hour > 12
        ? dt.hour - 12
        : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} · $hour:$minute $period';
  }
}
