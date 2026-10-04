// lib/features/authentication/presentation/screens/registration_success_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/route_names.dart';
import '../../models/user_model.dart';
import '../widgets/primary_button.dart';

/// Registration success screen — shows the exact User ID the user entered.
/// Provides a copy button and directs user to login.
class RegistrationSuccessScreen extends StatelessWidget {
  const RegistrationSuccessScreen({super.key, required this.user});
  final UserModel user;

  void _copyUserId(BuildContext context) {
    Clipboard.setData(ClipboardData(text: user.userId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('User ID copied to clipboard'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sm),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
      ),
    );
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
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: hPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppSpacing.huge),
              const SizedBox(height: AppSpacing.huge),

              // Success icon
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.success,
                  size: 52,
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Title
              Text(
                'Account Created',
                style: AppTextStyles.screenTitle(),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.md),

              // Message
              Text(
                'Your Smart Electoral Results account has been created successfully.',
                style: AppTextStyles.subtitle(),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xxxl),

              // User ID display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'YOUR USER ID',
                      style: AppTextStyles.inputLabel(color: AppColors.primary),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SelectableText(
                      user.userId,
                      style: AppTextStyles.userIdDisplay(),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Copy button
              OutlinedButton.icon(
                onPressed: () => _copyUserId(context),
                icon: const Icon(Icons.content_copy_rounded, size: 16),
                label: const Text('Copy User ID'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                  ),
                  textStyle: AppTextStyles.buttonText(color: AppColors.primary),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Info text
              Text(
                'You can now sign in using your\nUser ID and password.',
                style: AppTextStyles.subtitle(),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xxxl),

              // Go to login button
              PrimaryButton(
                label: 'GO TO LOGIN',
                onPressed: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil(RouteNames.login, (r) => false),
              ),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
