// lib/features/authentication/presentation/screens/reset_password_screen.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/route_names.dart';
import '../../controllers/auth_controller.dart';
import '../widgets/password_field.dart';
import '../widgets/primary_button.dart';
import '../../../result_submission/services/device_location_service.dart';

/// First-login password rotation after signing in with a temporary credential.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.userId,
    required this.currentPassword,
    required this.authController,
  });

  final String userId;
  final String currentPassword;
  final AuthController authController;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _success = false;
  String? _error;

  AuthController get _auth => widget.authController;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onReset() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);

    final ok = await _auth.resetPassword(
      userId: widget.userId,
      newPassword: _newPasswordController.text,
      currentPassword: widget.currentPassword,
    );

    if (!mounted) return;
    if (ok) {
      DeviceLocationService.warmUpPermissionsAndLocation();
      setState(() => _success = true);
    } else {
      setState(() => _error = _auth.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final hPadding = screenWidth < 390
        ? AppSpacing.horizontalPaddingSmall
        : AppSpacing.horizontalPaddingLarge;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.border,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: Text('Reset Password', style: AppTextStyles.sectionTitle()),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _auth,
          builder: (context, _) {
            final isLoading = _auth.isLoading;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: hPadding),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: _success
                  ? _SuccessState(
                      onGoToLogin: () => Navigator.of(context)
                          .pushNamedAndRemoveUntil(
                            _auth.currentUser == null
                                ? RouteNames.login
                                : RouteNames.dashboard,
                            (r) => false,
                          ),
                    )
                  : Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppSpacing.xxl),

                          // User ID display (read-only context)
                          Text(
                            'Resetting password for:',
                            style: AppTextStyles.subtitle(),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            widget.userId,
                            style: AppTextStyles.userIdDisplay(),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text('Choose a new 6-character alphanumeric password. The temporary password you used to sign in is verified securely before this change is accepted.', style: AppTextStyles.bodySmall(color: AppColors.textSecondary)),

                          const SizedBox(height: AppSpacing.xxl),

                          // New password
                          PasswordField(
                            label: 'New Password',
                            hint: 'Enter 6 alphanumeric characters',
                            controller: _newPasswordController,
                            textInputAction: TextInputAction.next,
                            enabled: !isLoading,
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'New password is required.';
                              }
                              if (!RegExp(r'^[a-zA-Z0-9]{6}$').hasMatch(v)) {
                                return 'Password must be 6 alphanumeric characters.';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: AppSpacing.fieldGap),

                          // Confirm new password
                          PasswordField(
                            label: 'Confirm New Password',
                            hint: 'Confirm your new password',
                            controller: _confirmPasswordController,
                            textInputAction: TextInputAction.done,
                            enabled: !isLoading,
                            onFieldSubmitted: (_) => _onReset(),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Please confirm your new password.';
                              }
                              if (v != _newPasswordController.text) {
                                return 'Passwords do not match.';
                              }
                              return null;
                            },
                          ),

                          // Error banner
                          if (_error != null) ...[
                            const SizedBox(height: AppSpacing.lg),
                            _ErrorBanner(message: _error!),
                          ],

                          const SizedBox(height: AppSpacing.xxl),

                          PrimaryButton(
                            label: 'RESET PASSWORD',
                            loadingLabel: 'Resetting password...',
                            isLoading: isLoading,
                            onPressed: _onReset,
                          ),

                          const SizedBox(height: AppSpacing.xxl),
                        ],
                      ),
                    ),
                  ),
                ),
            );
          },
        ),
      ),
    );
  }
}

/// Success state shown after successful password reset.
class _SuccessState extends StatelessWidget {
  const _SuccessState({required this.onGoToLogin});
  final VoidCallback onGoToLogin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: AppSpacing.huge),
        const SizedBox(height: AppSpacing.huge),

        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.successLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.success,
            size: 48,
          ),
        ),

        const SizedBox(height: AppSpacing.xxl),

        Text(
          'Password Reset Successfully',
          style: AppTextStyles.screenTitle(),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: AppSpacing.md),

        Text(
          'Your password has been updated. You can continue to your assigned dashboard.',
          style: AppTextStyles.subtitle(),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: AppSpacing.xxxl),

        PrimaryButton(
          label: 'CONTINUE',
          onPressed: onGoToLogin,
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
