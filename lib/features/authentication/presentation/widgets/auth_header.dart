// lib/features/authentication/presentation/widgets/auth_header.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';

/// Application logo mark — a simple geometric design representing a ballot/check.
/// Replace with an actual SVG logo asset when branding is finalized.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background shield/ballot shape
          Icon(
            Icons.how_to_vote_outlined,
            color: Colors.white.withValues(alpha: 0.15),
            size: size * 0.75,
          ),
          // Foreground check mark
          Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: size * 0.5,
          ),
        ],
      ),
    );
  }
}

/// Auth screen header — logo mark + app name + optional subtitle.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    this.showSubtitle = true,
    this.logoSize = 56,
  });

  final bool showSubtitle;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppLogoMark(size: logoSize),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'SMART ELECTORAL',
          style: AppTextStyles.appName().copyWith(
            letterSpacing: 1.5,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          'RESULTS APP',
          style: AppTextStyles.appName().copyWith(
            letterSpacing: 1.5,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
          textAlign: TextAlign.center,
        ),
        if (showSubtitle) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Results Management System',
            style: AppTextStyles.caption(),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
