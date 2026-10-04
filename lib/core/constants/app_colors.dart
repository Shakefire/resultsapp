// lib/core/constants/app_colors.dart
import 'package:flutter/material.dart';

/// Application color system for Smart Electoral Results App.
/// All colors derive from the institutional green/white palette.
class AppColors {
  AppColors._();

  // Primary greens
  static const Color primary = Color(0xFF087443);
  static const Color primaryDark = Color(0xFF075B36);
  static const Color primaryLight = Color(0xFFE8F5EE);

  // Background
  static const Color background = Color(0xFFF8FAF9);
  static const Color surface = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF17221C);
  static const Color textSecondary = Color(0xFF68756D);
  static const Color textPlaceholder = Color(0xFF596660);
  static const Color textDisabled = Color(0xFFA0ADA6);

  // Border
  static const Color border = Color(0xFFE1E7E3);
  static const Color borderFocused = Color(0xFF087443);
  static const Color borderError = Color(0xFFC62828);

  // Status
  static const Color error = Color(0xFFC62828);
  static const Color errorLight = Color(0xFFFDEDED);
  static const Color warning = Color(0xFFB7791F);
  static const Color warningLight = Color(0xFFFEF3E2);
  static const Color success = Color(0xFF087443);
  static const Color successLight = Color(0xFFE8F5EE);

  // Button states
  static const Color buttonDisabled = Color(0xFFCDD5CF);
  static const Color buttonDisabledText = Color(0xFF8A9E92);

  // Overlay
  static const Color overlay = Color(0x0A000000);
}
