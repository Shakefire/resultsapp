// lib/features/authentication/presentation/screens/forgot_password_screen.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/primary_button.dart';

/// Operational accounts are reset by a Super Admin, who issues a temporary password.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userIdController = TextEditingController();

  bool get _hasInput => _userIdController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  void _onContinue() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: const Text('Contact your Super Admin'),
      content: const Text('Only a Super Admin can issue a temporary password. After receiving it, sign in and choose a new password.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Understood'))],
    ));
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
        title: Text('Forgot Password', style: AppTextStyles.sectionTitle()),
      ),
      body: SafeArea(
        child: Center(
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
                const SizedBox(height: AppSpacing.xxl),

                // Lock icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.lock_reset_outlined,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                Text(
                  'Forgot Password?',
                  style: AppTextStyles.screenTitle(),
                ),

                const SizedBox(height: AppSpacing.sm),

                Text(
                  'Enter your User ID to view password reset instructions.',
                  style: AppTextStyles.subtitle(),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // User ID field
                ListenableBuilder(
                  listenable: _userIdController,
                  builder: (ctx, child) {
                    return AuthTextField(
                      label: 'User ID',
                      hint: 'Enter your User ID',
                      controller: _userIdController,
                      autofocus: true,
                      keyboardType: TextInputType.visiblePassword,
                      textInputAction: TextInputAction.done,
                      prefixIcon: const Icon(Icons.badge_outlined),
                      onFieldSubmitted: (_) {
                        if (_hasInput) _onContinue();
                      },
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'User ID is required.';
                        }
                        return null;
                      },
                    );
                  },
                ),

                const SizedBox(height: AppSpacing.xxl),

                // Continue button
                ListenableBuilder(
                  listenable: _userIdController,
                  builder: (ctx2, child2) {
                    return PrimaryButton(
                      label: 'VIEW INSTRUCTIONS',
                      enabled: _hasInput,
                      onPressed: _onContinue,
                    );
                  },
                ),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
  }
}
