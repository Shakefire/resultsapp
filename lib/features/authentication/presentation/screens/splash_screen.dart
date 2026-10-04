// lib/features/authentication/presentation/screens/splash_screen.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/route_names.dart';
import '../widgets/auth_header.dart';

/// Splash screen — shown on cold launch.
/// Performs session check and routes accordingly.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _animController.forward();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    // Allow the splash animation to play before opening sign-in.
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    // Sessions are held in memory; a cold launch requires sign-in again.
    Navigator.of(context).pushReplacementNamed(RouteNames.login);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              const Spacer(flex: 3),
              // Logo and app name
              const Center(child: AuthHeader(showSubtitle: true, logoSize: 72)),
              const Spacer(flex: 3),
              // Bottom tagline
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _DotSeparatedItem(text: 'Secure'),
                    _Dot(),
                    _DotSeparatedItem(text: 'Simple'),
                    _Dot(),
                    _DotSeparatedItem(text: 'Transparent'),
                  ],
                ),
              ),
              // Version
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Text(
                  'v1.0.0',
                  style: AppTextStyles.caption(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DotSeparatedItem extends StatelessWidget {
  const _DotSeparatedItem({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTextStyles.caption());
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Container(
        width: 3,
        height: 3,
        decoration: const BoxDecoration(
          color: AppColors.textDisabled,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
