// lib/features/polling_unit/presentation/screens/polling_unit_dashboard_screen.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/route_names.dart';
import '../../../authentication/controllers/auth_controller.dart';
import '../../../authentication/presentation/widgets/primary_button.dart';
import '../../controllers/polling_unit_dashboard_controller.dart';
import '../../models/result_submission.dart';
import '../../models/voter_register.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/assignment_card.dart';
import '../widgets/result_status_card.dart';
import '../widgets/voter_register_card.dart';
import '../widgets/recent_activity_section.dart';
import '../widgets/polling_unit_bottom_nav.dart';
import 'results_tab_screen.dart';
import 'alerts_tab_screen.dart';
import 'profile_tab_screen.dart';

/// The official Polling Unit Staff Dashboard screen.
/// Implements the quiet, institutional, mobile-first operational workspace.
class PollingUnitDashboardScreen extends StatefulWidget {
  const PollingUnitDashboardScreen({
    super.key,
    required this.authController,
    this.dashboardController,
  });

  final AuthController authController;
  final PollingUnitDashboardController? dashboardController;

  @override
  State<PollingUnitDashboardScreen> createState() =>
      _PollingUnitDashboardScreenState();
}

class _PollingUnitDashboardScreenState extends State<PollingUnitDashboardScreen> {
  late final PollingUnitDashboardController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.dashboardController ?? PollingUnitDashboardController();
    _controller.loadDashboard();
  }

  @override
  void dispose() {
    if (widget.dashboardController == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _navigateToResultAction() {
    final result = _controller.result;
    if (result == null ||
        result.status == ResultStatus.notSubmitted ||
        result.status == ResultStatus.returned) {
      Navigator.of(context).pushNamed(RouteNames.submitResult);
    } else {
      Navigator.of(context).pushNamed(RouteNames.submissionDetails);
    }
  }

  void _navigateToRegisterAction() {
    final register = _controller.voterRegister;
    if (register == null ||
        register.status == VoterRegisterStatus.notUploaded ||
        register.status == VoterRegisterStatus.uploadFailed) {
      Navigator.of(context).pushNamed(RouteNames.voterRegisterUpload);
    } else {
      Navigator.of(context).pushNamed(RouteNames.voterRegister);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: _buildBody(context),
          ),
          bottomNavigationBar: PollingUnitBottomNav(
            currentIndex: _controller.selectedTabIndex,
            onTap: _controller.setTabIndex,
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    // 1. Loading State (Section 18)
    if (_controller.isLoading) {
      return const _DashboardLoadingSkeleton();
    }

    // 2. Error State (Section 19)
    if (_controller.hasError) {
      return _DashboardErrorView(
        errorMessage: _controller.errorMessage ?? 'Unable to load dashboard',
        onRetry: _controller.retry,
      );
    }

    // 3. Tab switching
    switch (_controller.selectedTabIndex) {
      case 1:
        return ResultsTabScreen(
          controller: _controller,
          onSubmitResultPressed: _navigateToResultAction,
          onViewSubmissionPressed: _navigateToResultAction,
        );
      case 2:
        return AlertsTabScreen(controller: _controller);
      case 3:
        return ProfileTabScreen(
          authController: widget.authController,
          dashboardController: _controller,
        );
      case 0:
      default:
        return _buildHomeOperationalTab(context);
    }
  }

  /// Primary operational home tab (Section 2 wireframe & visual hierarchy)
  Widget _buildHomeOperationalTab(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final hPadding = screenWidth < 390
        ? AppSpacing.horizontalPaddingSmall
        : AppSpacing.horizontalPaddingLarge;

    final user = widget.authController.currentUser;
    final userName = user?.fullName ?? 'Kabir Muhammad Hassan';
    final assignment = _controller.assignment;
    final result = _controller.result;
    final voterRegister = _controller.voterRegister;
    final activities = _controller.recentActivity;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: RefreshIndicator(
          onRefresh: _controller.refresh,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: hPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.sm),

                // 1. Header (Menu, Notifications, Dynamic Greeting)
                DashboardHeader(
                  userName: userName,
                  onMenuPressed: () => _controller.setTabIndex(3), // Navigate to Profile
                  onNotificationsPressed: () => _controller.setTabIndex(2), // Navigate to Alerts
                  unreadNotificationsCount: result?.status == ResultStatus.returned ? 1 : 0,
                ),

                const SizedBox(height: AppSpacing.xl),

                // 2. Assignment Information (Section 5)
                if (assignment != null) AssignmentCard(assignment: assignment),

                const SizedBox(height: AppSpacing.lg),

                // 3. Result Section (Section 6 & 7) - Dominant operational action
                if (result != null)
                  ResultStatusCard(
                    result: result,
                    onActionPressed: _navigateToResultAction,
                  ),

                const SizedBox(height: AppSpacing.lg),

                // 4. Voter Register Section (Section 8 & 9) - Secondary action
                if (voterRegister != null)
                  VoterRegisterCard(
                    voterRegister: voterRegister,
                    onActionPressed: _navigateToRegisterAction,
                  ),

                const SizedBox(height: AppSpacing.xl),

                // 5. Recent Activity (Section 11)
                RecentActivitySection(activities: activities),

                const SizedBox(height: AppSpacing.xxxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Clean institutional skeleton / loading view (Section 18).
class _DashboardLoadingSkeleton extends StatelessWidget {
  const _DashboardLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            'Loading operational workspace...',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Error state view with retry mechanism (Section 19).
class _DashboardErrorView extends StatelessWidget {
  const _DashboardErrorView({
    required this.errorMessage,
    required this.onRetry,
  });

  final String errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: AppColors.error,
                size: 28,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Unable to load dashboard',
              style: AppTextStyles.sectionTitle(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Please check your connection\nand try again.',
              style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
              label: 'TRY AGAIN',
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
