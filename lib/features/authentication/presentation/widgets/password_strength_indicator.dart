// lib/features/authentication/presentation/widgets/password_strength_indicator.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';

/// Password strength levels.
enum PasswordStrength { none, weak, medium, strong }

/// Calculates password strength from the given value.
PasswordStrength calculatePasswordStrength(String password) {
  if (password.isEmpty) return PasswordStrength.none;

  int score = 0;
  if (password.length == 6 && RegExp(r'^[a-zA-Z0-9]+$').hasMatch(password)) score++;
  if (RegExp(r'[a-z]').hasMatch(password)) score++;
  if (RegExp(r'[A-Z]').hasMatch(password)) score++;
  if (RegExp(r'[0-9]').hasMatch(password)) score++;

  if (score <= 2) return PasswordStrength.weak;
  if (score == 3) return PasswordStrength.medium;
  return PasswordStrength.strong;
}

/// Visual password strength indicator bar with label.
class PasswordStrengthIndicator extends StatelessWidget {
  const PasswordStrengthIndicator({
    super.key,
    required this.password,
  });

  final String password;

  @override
  Widget build(BuildContext context) {
    final strength = calculatePasswordStrength(password);

    if (strength == PasswordStrength.none) return const SizedBox.shrink();

    final (label, color, filledBars) = switch (strength) {
      PasswordStrength.weak => ('Weak', AppColors.error, 1),
      PasswordStrength.medium => ('Medium', AppColors.warning, 2),
      PasswordStrength.strong => ('Strong', AppColors.success, 3),
      PasswordStrength.none => ('', AppColors.border, 0),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Text(
              'Password strength',
              style: AppTextStyles.helper(),
            ),
            const Spacer(),
            Text(
              label,
              style: AppTextStyles.helper(color: color),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        Row(
          children: List.generate(3, (index) {
            final isActive = index < filledBars;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: index < 2 ? 4 : 0),
                decoration: BoxDecoration(
                  color: isActive ? color : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '6 alphanumeric characters (mix of uppercase, lowercase, and numbers recommended).',
          style: AppTextStyles.helper(),
        ),
      ],
    );
  }
}
