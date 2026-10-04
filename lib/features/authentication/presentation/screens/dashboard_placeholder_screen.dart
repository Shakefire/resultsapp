// lib/features/authentication/presentation/screens/dashboard_placeholder_screen.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/route_names.dart';
import '../../controllers/auth_controller.dart';
import '../../models/user_role.dart';

/// Temporary authenticated placeholder — proves auth/session/navigation works.
/// Will be replaced by the actual role-based dashboards.
class DashboardPlaceholderScreen extends StatelessWidget {
  const DashboardPlaceholderScreen({super.key, required this.authController});
  final AuthController authController;

  Future<void> _onLogout(BuildContext context) async {
    await authController.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(RouteNames.login, (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final hPadding = screenWidth < 390
        ? AppSpacing.horizontalPaddingSmall
        : AppSpacing.horizontalPaddingLarge;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.border,
        automaticallyImplyLeading: false,
        title: Text('Dashboard', style: AppTextStyles.sectionTitle()),
        actions: [
          ListenableBuilder(
            listenable: authController,
            builder: (ctx, child) {
              return IconButton(
                icon: authController.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout_rounded),
                tooltip: 'Logout',
                onPressed: authController.isLoading
                    ? null
                    : () => _onLogout(context),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: authController,
        builder: (context, _) {
          final user = authController.currentUser;

          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Smart Electoral Results App',
                        style: AppTextStyles.bodySmall(color: Colors.white.withValues(alpha: 0.8)),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Welcome, ${user.fullName}',
                        style: AppTextStyles.sectionTitle(color: Colors.white),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // User details
                _InfoCard(
                  title: 'Account Details',
                  items: [
                    _InfoItem(
                      icon: Icons.badge_outlined,
                      label: 'User ID',
                      value: user.userId,
                      valueStyle: AppTextStyles.userIdDisplay(),
                    ),
                    _InfoItem(
                      icon: Icons.person_outline,
                      label: 'Full Name',
                      value: user.fullName,
                    ),
                    _InfoItem(
                      icon: Icons.shield_outlined,
                      label: 'Role',
                      value: user.roleDisplayName,
                      valueStyle: AppTextStyles.body().copyWith(
                        color: user.role != null
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                if (user.stateName != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _InfoCard(
                    title: 'Location Assignment',
                    items: [
                      if (user.stateName != null)
                        _InfoItem(
                          icon: Icons.map_outlined,
                          label: 'State',
                          value: user.stateName!,
                        ),
                      if (user.lgaName != null)
                        _InfoItem(
                          icon: Icons.location_city_outlined,
                          label: 'LGA',
                          value: user.lgaName!,
                        ),
                      if (user.wardName != null)
                        _InfoItem(
                          icon: Icons.location_on_outlined,
                          label: 'Ward',
                          value: user.wardName!,
                        ),
                      if (user.pollingUnitName != null)
                        _InfoItem(
                          icon: Icons.how_to_vote_outlined,
                          label: 'Polling Unit',
                          value: user.pollingUnitName!,
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: AppSpacing.xxl),

                if (user.role == UserRole.superAdmin) ...[
                  _AdminActionCard(
                    title: 'Manage accounts and geography',
                    description: 'Create, deactivate, reassign, reset credentials, and manage location records.',
                    icon: Icons.admin_panel_settings_outlined,
                    onPressed: () => Navigator.of(context).pushNamed(RouteNames.adminManagement),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _AdminActionCard(
                    onPressed: () => Navigator.of(context).pushNamed(RouteNames.adminProvisionUser),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _AdminActionCard(
                    title: 'Manage elections',
                    description: 'Open or close the election that accepts submissions.',
                    icon: Icons.how_to_vote_outlined,
                    onPressed: () => Navigator.of(context).pushNamed(RouteNames.adminElections),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],

                // Placeholder note
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'This is a placeholder dashboard. Role-based dashboards will be implemented in the next phase.',
                          style: AppTextStyles.bodySmall(color: AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  const _AdminActionCard({required this.onPressed, this.title = 'Create user account', this.description = 'Assign a role and location, then issue first sign-in credentials.', this.icon = Icons.person_add_alt_1});
  final VoidCallback onPressed;
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppSpacing.md),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(AppSpacing.md),
          leading: CircleAvatar(
            backgroundColor: AppColors.primaryLight,
            child: Icon(icon, color: AppColors.primary),
          ),
          title: Text(title, style: AppTextStyles.sectionTitle()),
          subtitle: Text(description, style: AppTextStyles.bodySmall()),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          onTap: onPressed,
        ),
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.items});
  final String title;
  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
            child: Text(title, style: AppTextStyles.sectionTitle()),
          ),
          const Divider(height: 1),
          ...items.map((item) => _InfoItemTile(item: item)),
        ],
      ),
    );
  }
}

class _InfoItem {
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueStyle,
  });
  final IconData icon;
  final String label;
  final String value;
  final TextStyle? valueStyle;
}

class _InfoItemTile extends StatelessWidget {
  const _InfoItemTile({required this.item});
  final _InfoItem item;

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
          Icon(item.icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: AppTextStyles.caption()),
                const SizedBox(height: 2),
                Text(
                  item.value,
                  style: item.valueStyle ?? AppTextStyles.body(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
