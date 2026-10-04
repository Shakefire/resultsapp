// lib/features/authentication/presentation/widgets/primary_button.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_border_radius.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';

/// Primary call-to-action button with Normal / Loading / Disabled states.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.loadingLabel,
    this.enabled = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final String? loadingLabel;
  final bool enabled;
  final Widget? icon;

  bool get _isEnabled => enabled && !isLoading && onPressed != null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeight,
      child: ElevatedButton(
        onPressed: _isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isEnabled ? AppColors.primary : AppColors.buttonDisabled,
          foregroundColor: _isEnabled ? Colors.white : AppColors.buttonDisabledText,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: AppBorderRadius.button,
          ),
          padding: EdgeInsets.zero,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isLoading
              ? Row(
                  key: const ValueKey('loading'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    if (loadingLabel != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        loadingLabel!,
                        style: AppTextStyles.buttonText(),
                      ),
                    ],
                  ],
                )
              : Row(
                  key: const ValueKey('label'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      icon!,
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Text(
                      label,
                      style: AppTextStyles.buttonText(
                        color: _isEnabled ? Colors.white : AppColors.buttonDisabledText,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
