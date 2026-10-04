import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../core/services/vercel_api_client.dart';
import '../../controllers/auth_controller.dart';
import '../../services/admin_election_service.dart';
import '../../services/admin_management_service.dart';

/// Live Super Admin landing page with operational counts and working actions.
class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({
    super.key,
    required this.authController,
    this.managementService,
    this.electionService,
  });

  final AuthController authController;
  final AdminManagementService? managementService;
  final AdminElectionService? electionService;

  @override
  State<SuperAdminDashboardScreen> createState() =>
      _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  late final AdminManagementService _management =
      widget.managementService ?? AdminManagementService();
  late final AdminElectionService _elections =
      widget.electionService ?? AdminElectionService();

  List<ManagedAccount> _accounts = const [];
  List<AdminElection> _electionItems = const [];
  bool _loadingAccounts = true;
  bool _loadingElections = true;
  String? _accountError;
  String? _electionError;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await Future.wait([_loadAccounts(), _loadElections()]);
  }

  Future<void> _loadAccounts() async {
    if (mounted)
      setState(() {
        _loadingAccounts = true;
        _accountError = null;
      });
    try {
      final accounts = await _management.getAccounts();
      if (mounted)
        setState(() {
          _accounts = accounts;
          _loadingAccounts = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _accountError = _message(error);
          _loadingAccounts = false;
        });
    }
  }

  Future<void> _loadElections() async {
    if (mounted)
      setState(() {
        _loadingElections = true;
        _electionError = null;
      });
    try {
      final elections = await _elections.list();
      if (mounted)
        setState(() {
          _electionItems = elections;
          _loadingElections = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _electionError = _message(error);
          _loadingElections = false;
        });
    }
  }

  String _message(Object error) => error is VercelApiException
      ? error.message
      : 'Unable to load this dashboard data.';

  Future<void> _logout() async {
    await widget.authController.logout();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(RouteNames.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authController.currentUser;
    final activeCount = _accounts.where((account) => account.active).length;
    final now = DateTime.now().toUtc();
    final openCount = _electionItems.where((election) {
      final opensAt = election.opensAt == null ? null : DateTime.tryParse(election.opensAt!)?.toUtc();
      final closesAt = election.closesAt == null ? null : DateTime.tryParse(election.closesAt!)?.toUtc();
      return election.status == 'open' &&
          (opensAt == null || !opensAt.isAfter(now)) &&
          (closesAt == null || !closesAt.isBefore(now));
    }).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('National operations', style: AppTextStyles.sectionTitle()),
        actions: [
          IconButton(
            onPressed: _loadingAccounts || _loadingElections ? null : _refresh,
            tooltip: 'Refresh dashboard',
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _logout,
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_outlined),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Welcome, ${user?.fullName ?? 'Administrator'}',
              style: AppTextStyles.screenTitle(),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Manage accounts, geographic assignments, and election windows.',
              style: AppTextStyles.body(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 760 ? 4 : 2;
                final delegatedCount = _accounts
                    .where((a) => a.json['can_provision_users'] == true)
                    .length;
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  childAspectRatio: columns >= 4 ? 1.35 : 1.55,
                  children: [
                    _MetricCard(
                      label: 'Managed accounts',
                      value: _loadingAccounts ? null : '${_accounts.length}',
                      detail: _loadingAccounts
                          ? 'Loading accounts'
                          : '$activeCount active',
                      icon: Icons.groups_outlined,
                      error: _accountError,
                      onTap: () => Navigator.pushNamed(
                        context,
                        RouteNames.adminManagement,
                      ),
                    ),
                    _MetricCard(
                      label: 'Ongoing elections',
                      value: _loadingElections ? null : '$openCount',
                      detail: _loadingElections
                          ? 'Loading elections'
                          : '${_electionItems.length} configured',
                      icon: Icons.how_to_vote_outlined,
                      error: _electionError,
                      onTap: () => Navigator.pushNamed(
                        context,
                        RouteNames.adminElections,
                      ),
                    ),
                    _MetricCard(
                      label: 'Inactive accounts',
                      value: _loadingAccounts
                          ? null
                          : '${_accounts.length - activeCount}',
                      detail: _loadingAccounts
                          ? 'Loading accounts'
                          : 'Review account access',
                      icon: Icons.person_off_outlined,
                      error: _accountError,
                      onTap: () => Navigator.pushNamed(
                        context,
                        RouteNames.adminManagement,
                      ),
                    ),
                    _MetricCard(
                      label: 'Delegated admins',
                      value: _loadingAccounts ? null : '$delegatedCount',
                      detail: _loadingAccounts
                          ? 'Loading accounts'
                          : 'Can create accounts',
                      icon: Icons.supervisor_account_outlined,
                      error: _accountError,
                      onTap: () => Navigator.pushNamed(
                        context,
                        RouteNames.adminManagement,
                      ),
                    ),
                  ],
                );
              },
            ),
            if (_accountError != null || _electionError != null) ...[
              const SizedBox(height: AppSpacing.md),
              _ConnectionNotice(
                message:
                    'Some dashboard counts could not load. The management screens remain available; refresh after checking the API connection.',
                onRetry: _refresh,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Text('Administration', style: AppTextStyles.sectionTitle()),
            const SizedBox(height: AppSpacing.sm),
            _ActionTile(
              icon: Icons.person_add_alt_1_outlined,
              title: 'Create account',
              description:
                  'Assign a role and location, then issue first sign-in credentials.',
              onTap: () => Navigator.pushNamed(
                context,
                RouteNames.adminProvisionUser,
              ).then((_) => _refresh()),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ActionTile(
              icon: Icons.manage_accounts_outlined,
              title: 'Manage accounts and geography',
              description:
                  'Update assignments, deactivate accounts, reset passwords, and maintain locations.',
              onTap: () => Navigator.pushNamed(
                context,
                RouteNames.adminManagement,
              ).then((_) => _refresh()),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ActionTile(
              icon: Icons.event_available_outlined,
              title: 'Manage election window',
              description:
                  'Open or close the election that accepts result submissions.',
              onTap: () => Navigator.pushNamed(
                context,
                RouteNames.adminElections,
              ).then((_) => _refresh()),
            ),
            const SizedBox(height: AppSpacing.xl),
            _InfoPanel(
              userId: user?.userId ?? '—',
              role: user?.roleDisplayName ?? 'Super Administrator',
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.error,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String detail;
  final IconData icon;
  final String? error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.border),
      borderRadius: BorderRadius.circular(AppSpacing.md),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: AppTextStyles.caption()),
                  const SizedBox(height: 2),
                  if (error != null)
                    Text(
                      'Unavailable',
                      style: AppTextStyles.body().copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else if (value == null)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Text(value!, style: AppTextStyles.sectionTitle()),
                  Text(
                    detail,
                    style: AppTextStyles.caption(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.border),
      borderRadius: BorderRadius.circular(AppSpacing.md),
    ),
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.all(AppSpacing.md),
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryLight,
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title, style: AppTextStyles.sectionTitle()),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Text(description, style: AppTextStyles.bodySmall()),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
    ),
  );
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.userId, required this.role});
  final String userId;
  final String role;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.md),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.verified_user_outlined,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            '$role · $userId',
            style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
          ),
        ),
      ],
    ),
  );
}

class _ConnectionNotice extends StatelessWidget {
  const _ConnectionNotice({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.warningLight,
      borderRadius: BorderRadius.circular(AppSpacing.md),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.cloud_off_outlined, color: AppColors.warning),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: AppTextStyles.bodySmall(color: AppColors.warning),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
