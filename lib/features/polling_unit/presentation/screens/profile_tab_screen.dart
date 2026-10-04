// lib/features/polling_unit/presentation/screens/profile_tab_screen.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_border_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/route_names.dart';
import '../../../authentication/controllers/auth_controller.dart';
import '../../controllers/polling_unit_dashboard_controller.dart';

/// Screen rendered within the 'Profile' tab of the bottom navigation.
/// Displays authenticated staff credentials, assignment details, and provides working logout.
class ProfileTabScreen extends StatelessWidget {
  const ProfileTabScreen({
    super.key,
    required this.authController,
    required this.dashboardController,
  });

  final AuthController authController;
  final PollingUnitDashboardController dashboardController;

  Future<void> _onLogout(BuildContext context) async {
    await authController.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(RouteNames.login, (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = authController.currentUser;
    final assignment = dashboardController.assignment;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.horizontalPaddingLarge,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Staff Profile', style: AppTextStyles.screenTitle()),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Official accreditation credentials and assigned polling station.',
            style: AppTextStyles.subtitle(),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // User info card
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
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? 'Kabir Muhammad Hassan',
                            style: AppTextStyles.sectionTitle(),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.userId != null ? 'User ID: ${user!.userId}' : 'User ID: ERS-0047',
                            style: AppTextStyles.userIdDisplay().copyWith(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                const Divider(color: AppColors.border),
                const SizedBox(height: AppSpacing.md),
                _ProfileRow(label: 'Role', value: 'Polling Unit Staff'),
                const SizedBox(height: AppSpacing.sm),
                _ProfileRow(
                  label: 'Assigned PU',
                  value: assignment?.pollingUnitId ?? 'PU 0047',
                ),
                const SizedBox(height: AppSpacing.sm),
                _ProfileRow(
                  label: 'Station',
                  value: assignment?.pollingUnitName ?? 'Gwarinpa Primary School',
                ),
                const SizedBox(height: AppSpacing.sm),
                _ProfileRow(
                  label: 'Ward & LGA',
                  value: assignment?.wardAndLga ?? 'Ward 03 · AMAC',
                ),
                const SizedBox(height: AppSpacing.sm),
                _ProfileRow(
                  label: 'State',
                  value: assignment?.state ?? 'FCT',
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // Logout Button
          SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeight,
            child: OutlinedButton.icon(
              onPressed: () => _onLogout(context),
              icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
              label: Text(
                'LOGOUT',
                style: AppTextStyles.buttonText(color: AppColors.error),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error, width: 1.5),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppBorderRadius.button,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodySmall(color: AppColors.textSecondary)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTextStyles.body(color: AppColors.textPrimary).copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
