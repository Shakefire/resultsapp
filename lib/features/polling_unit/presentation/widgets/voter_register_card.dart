// lib/features/polling_unit/presentation/widgets/voter_register_card.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_border_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../models/voter_register.dart';

/// Secondary operational card on the Polling Unit Dashboard for voter register management.
/// Uses secondary button styling to maintain clear visual hierarchy below the Result CTA.
class VoterRegisterCard extends StatelessWidget {
  const VoterRegisterCard({
    super.key,
    required this.voterRegister,
    required this.onActionPressed,
  });

  final VoterRegister voterRegister;
  final VoidCallback onActionPressed;

  @override
  Widget build(BuildContext context) {
    final status = voterRegister.status;
    final statusTitle = status.displayTitle;
    final statusIcon = status.statusIcon;
    final statusColor = status.statusColor;
    final actionLabel = status.actionLabel;
    final isUploading = status == VoterRegisterStatus.uploading;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppBorderRadius.card,
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with section label & status indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'VOTER REGISTER',
                style: AppTextStyles.inputLabel(color: AppColors.textSecondary).copyWith(
                  letterSpacing: 0.8,
                  fontSize: 11,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.border, width: 1),
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

          // Status title
          Text(
            statusTitle,
            style: AppTextStyles.sectionTitle(color: AppColors.textPrimary).copyWith(
              fontSize: 19,
            ),
          ),

          const SizedBox(height: AppSpacing.xs),

          // Supporting descriptive text
          Text(
            _buildDescription(),
            style: AppTextStyles.bodySmall(color: AppColors.textSecondary).copyWith(
              height: 1.45,
            ),
          ),

          // Uploading progress bar
          if (isUploading) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: voterRegister.uploadProgress,
                backgroundColor: AppColors.primaryLight,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 6,
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          // Secondary button treatment (Outlined institutional button)
          SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeight,
            child: OutlinedButton(
              onPressed: isUploading ? null : onActionPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppBorderRadius.button,
                ),
                padding: EdgeInsets.zero,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    status == VoterRegisterStatus.notUploaded || status == VoterRegisterStatus.uploadFailed
                        ? Icons.upload_file_outlined
                        : Icons.description_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    actionLabel,
                    style: AppTextStyles.buttonText(color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildDescription() {
    if (voterRegister.status == VoterRegisterStatus.uploaded ||
        voterRegister.status == VoterRegisterStatus.available) {
      if (voterRegister.uploadedAt != null) {
        return 'Voter register PDF\nUploaded ${_formatDate(voterRegister.uploadedAt!)}';
      }
      return 'Voter register PDF is available for this polling unit.';
    }
    return voterRegister.status.defaultDescription;
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
