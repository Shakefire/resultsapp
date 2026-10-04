// lib/features/polling_unit/presentation/widgets/assignment_card.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_border_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../models/polling_unit_assignment.dart';

/// Clean institutional card displaying the staff member's assigned polling unit.
class AssignmentCard extends StatelessWidget {
  const AssignmentCard({
    super.key,
    required this.assignment,
  });

  final PollingUnitAssignment assignment;

  @override
  Widget build(BuildContext context) {
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
          // Section Label row with institutional icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'POLLING UNIT',
                style: AppTextStyles.inputLabel(color: AppColors.textSecondary).copyWith(
                  letterSpacing: 0.8,
                  fontSize: 11,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.how_to_vote_outlined,
                      size: 13,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ASSIGNED',
                      style: AppTextStyles.caption(color: AppColors.primary).copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // Primary Identifier: e.g. PU 0047
          Text(
            assignment.pollingUnitId,
            style: AppTextStyles.screenTitle(color: AppColors.textPrimary).copyWith(
              fontSize: 22,
              letterSpacing: -0.2,
            ),
          ),

          const SizedBox(height: AppSpacing.xs),

          // Supporting Administrative location
          Text(
            assignment.wardAndLga,
            style: AppTextStyles.body(color: AppColors.textPrimary).copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            assignment.state,
            style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
          ),

          const SizedBox(height: AppSpacing.sm + 2),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.sm + 2),

          // Facility / Location name
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Expanded(
                child: Text(
                  assignment.pollingUnitName,
                  style: AppTextStyles.body(color: AppColors.textPrimary).copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
