// lib/features/authentication/presentation/screens/login_screen.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/route_names.dart';
import '../../controllers/auth_controller.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/password_field.dart';
import '../widgets/primary_button.dart';

/// Login screen for accounts provisioned by a Super Admin.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.authController});
  final AuthController authController;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  String? _inlineError;

  AuthController get _auth => widget.authController;

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  bool get _fieldsNotEmpty =>
      _userIdController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  Future<void> _onLogin() async {
    // Hide keyboard
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _inlineError = null);

    final success = await _auth.login(
      userId: _userIdController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      final user = _auth.currentUser;
      if (user?.mustChangePassword == true) {
        Navigator.of(context).pushReplacementNamed(
          RouteNames.resetPassword,
          arguments: {'userId': user!.userId, 'currentPassword': _passwordController.text},
        );
      } else {
        Navigator.of(context).pushReplacementNamed(RouteNames.dashboard);
      }
    } else {
      setState(() => _inlineError = _auth.errorMessage);
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.huge),

                    // Header
                    const Center(child: AuthHeader(showSubtitle: false, logoSize: 56)),

                    const SizedBox(height: AppSpacing.xxxl),

                    // Welcome text
                    Text('Welcome back', style: AppTextStyles.screenTitle()),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Sign in to continue to your account.',
                      style: AppTextStyles.subtitle(),
                    ),

                    // Global inline error banner placed at the top of the form
                    if (_inlineError != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _ErrorBanner(message: _inlineError!),
                      const SizedBox(height: AppSpacing.lg),
                    ] else
                      const SizedBox(height: AppSpacing.xxl),

                    // User ID field
                    AuthTextField(
                      label: 'User ID',
                      hint: 'Enter your User ID',
                      controller: _userIdController,
                      autofocus: true,
                      keyboardType: TextInputType.visiblePassword,
                      textInputAction: TextInputAction.next,
                      enabled: !isLoading,
                      prefixIcon: const Icon(Icons.badge_outlined),
                      onChanged: (_) => setState(() => _inlineError = null),
                      onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'User ID is required.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: AppSpacing.fieldGap),

                    // Password field
                    PasswordField(
                      label: 'Password',
                      hint: 'Enter your password',
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      textInputAction: TextInputAction.done,
                      enabled: !isLoading,
                      onChanged: (_) => setState(() => _inlineError = null),
                      onFieldSubmitted: (_) {
                        if (_fieldsNotEmpty) _onLogin();
                      },
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Password is required.';
                        }
                        return null;
                      },
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Forgot your password? Contact your Super Admin for a reset.',
                          textAlign: TextAlign.right,
                          style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Login button
                    ListenableBuilder(
                      listenable: _userIdController,
                      builder: (ctx, child) {
                        return ListenableBuilder(
                          listenable: _passwordController,
                          builder: (ctx2, child2) {
                            return PrimaryButton(
                              label: 'LOGIN',
                              loadingLabel: 'Signing in...',
                              isLoading: isLoading,
                              enabled: _fieldsNotEmpty,
                              onPressed: _onLogin,
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    Center(
                      child: Text(
                        'Accounts are created by a Super Admin. Contact your administrator if you need access.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall(),
                      ),
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

/// Inline error banner — styled alert box (not a SnackBar).
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
            child: Text(message, style: AppTextStyles.bodySmall(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
