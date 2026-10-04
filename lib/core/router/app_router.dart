// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import '../constants/route_names.dart';
import '../../features/authentication/controllers/auth_controller.dart';
import '../../features/authentication/models/user_role.dart';
import '../../features/authentication/presentation/screens/splash_screen.dart';
import '../../features/authentication/presentation/screens/login_screen.dart';
import '../../features/authentication/presentation/screens/forgot_password_screen.dart';
import '../../features/authentication/presentation/screens/reset_password_screen.dart';
import '../../features/authentication/presentation/screens/admin_account_provision_screen.dart';
import '../../features/authentication/presentation/screens/admin_review_dashboard_screen.dart';
import '../../features/authentication/presentation/screens/super_admin_dashboard_screen.dart';
import '../../features/authentication/presentation/screens/admin_election_screen.dart';
import '../../features/authentication/presentation/screens/admin_management_screen.dart';
import '../../features/authentication/presentation/screens/admin_account_assignment_screen.dart';
import '../../features/polling_unit/controllers/polling_unit_dashboard_controller.dart';
import '../../features/polling_unit/repositories/vercel_polling_unit_repository.dart';
import '../../features/polling_unit/presentation/screens/polling_unit_dashboard_screen.dart';
import '../../features/polling_unit/presentation/screens/submission_details_screen.dart';
import '../../features/polling_unit/presentation/screens/voter_register_screen.dart';
import '../../features/polling_unit/presentation/screens/voter_register_upload_screen.dart';
import '../../features/result_submission/presentation/screens/result_submission_flow_screen.dart';

/// Centralised named route configuration.
/// Coordinates authentication and role-based dashboard routing.
class AppRouter {
  AppRouter({
    required this.authController,
    PollingUnitDashboardController? pollingUnitController,
  }) : pollingUnitController =
           pollingUnitController ??
           PollingUnitDashboardController(
             repository: VercelPollingUnitRepository(),
           );

  final AuthController authController;
  final PollingUnitDashboardController pollingUnitController;

  /// Generates routes from named route strings.
  Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.splash:
        return _buildRoute(const SplashScreen(), settings);

      case RouteNames.login:
        return _buildRoute(
          LoginScreen(authController: authController),
          settings,
        );

      case RouteNames.forgotPassword:
        return _buildRoute(const ForgotPasswordScreen(), settings);

      case RouteNames.resetPassword:
        if (authController.currentUser == null) return _deniedRoute(settings);
        final args = settings.arguments is Map
            ? settings.arguments as Map
            : const {};
        final userId = args['userId'] as String? ?? '';
        return _buildRoute(
          ResetPasswordScreen(
            userId: userId,
            currentPassword: args['currentPassword'] as String? ?? '',
            authController: authController,
          ),
          settings,
        );

      case RouteNames.dashboard:
        final user = authController.currentUser;
        if (user == null) {
          return _buildRoute(
            LoginScreen(authController: authController),
            settings,
          );
        }
        // Role-based routing: administrative dashboards are added in later slices.
        if (user.role == UserRole.pollingUnitStaff) {
          return _buildRoute(
            PollingUnitDashboardScreen(
              authController: authController,
              dashboardController: pollingUnitController,
            ),
            settings,
          );
        }
        if (user.role == UserRole.wardAdmin ||
            user.role == UserRole.lgaAdmin ||
            user.role == UserRole.stateAdmin) {
          return _buildRoute(AdminReviewDashboardScreen(user: user), settings);
        }
        if (user.role == UserRole.superAdmin) {
          return _buildRoute(
            SuperAdminDashboardScreen(authController: authController),
            settings,
          );
        }
        return _buildRoute(const _AccessDeniedScreen(), settings);

      case RouteNames.adminProvisionUser: {
        final user = authController.currentUser;
        final allowed = user != null &&
            !user.mustChangePassword &&
            (user.role == UserRole.superAdmin || user.canProvisionUsers);
        if (!allowed) return _deniedRoute(settings);
        return _buildRoute(AdminAccountProvisionScreen(actingUser: user), settings);
      }

      case RouteNames.adminManagement: {
        final user = authController.currentUser;
        final allowed = user != null &&
            !user.mustChangePassword &&
            (user.role == UserRole.superAdmin || user.canProvisionUsers);
        if (!allowed) return _deniedRoute(settings);
        return _buildRoute(AdminManagementScreen(actingUser: user), settings);
      }

      case RouteNames.adminAccountAssignment:
        if (authController.currentUser?.role != UserRole.superAdmin ||
            authController.currentUser?.mustChangePassword == true ||
            settings.arguments is! Map<String, dynamic>) {
          return _deniedRoute(settings);
        }
        return _buildRoute(
          AdminAccountAssignmentScreen(
            account: settings.arguments! as Map<String, dynamic>,
          ),
          settings,
        );

      case RouteNames.register:
      case RouteNames.registrationSuccess:
        return _buildRoute(
          LoginScreen(authController: authController),
          settings,
        );

      case RouteNames.adminElections:
        if (authController.currentUser?.role != UserRole.superAdmin ||
            authController.currentUser?.mustChangePassword == true) {
          return _deniedRoute(settings);
        }
        return _buildRoute(const AdminElectionScreen(), settings);

      // ─── Polling Unit Operational Flows ────────────────────────────────────
      case RouteNames.submitResult:
        if (!_canAccessPollingUnitRoutes()) return _deniedRoute(settings);
        final puId = authController.currentUser?.pollingUnitId ?? '';
        return _buildRoute(
          ResultSubmissionFlowScreen(
            pollingUnitId: puId,
            onSubmitted: pollingUnitController.refresh,
          ),
          settings,
        );

      case RouteNames.submissionDetails:
        if (!_canAccessPollingUnitRoutes()) return _deniedRoute(settings);
        return _buildRoute(
          SubmissionDetailsScreen(controller: pollingUnitController),
          settings,
        );

      case RouteNames.voterRegister:
        if (!_canAccessPollingUnitRoutes()) return _deniedRoute(settings);
        return _buildRoute(
          VoterRegisterScreen(controller: pollingUnitController),
          settings,
        );

      case RouteNames.voterRegisterUpload:
        if (!_canAccessPollingUnitRoutes()) return _deniedRoute(settings);
        return _buildRoute(
          VoterRegisterUploadScreen(controller: pollingUnitController),
          settings,
        );

      default:
        return _buildRoute(
          _NotFoundScreen(routeName: settings.name ?? 'unknown'),
          settings,
        );
    }
  }

  bool _canAccessPollingUnitRoutes() =>
      authController.currentUser?.role == UserRole.pollingUnitStaff;

  MaterialPageRoute<dynamic> _deniedRoute(RouteSettings settings) =>
      _buildRoute(const _AccessDeniedScreen(), settings);

  static MaterialPageRoute<dynamic> _buildRoute(
    Widget page,
    RouteSettings settings,
  ) {
    return MaterialPageRoute<dynamic>(builder: (_) => page, settings: settings);
  }
}

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Text('Your account is not authorized for this action.'),
    ),
  );
}

/// Fallback screen for unknown routes.
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen({required this.routeName});
  final String routeName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('Route not found: $routeName')));
  }
}
