// lib/core/constants/app_text_styles.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typography system for Smart Electoral Results App.
/// Uses Inter via google_fonts for a clean institutional look.
class AppTextStyles {
  AppTextStyles._();

  /// Screen / page title  (24–28px, Bold)
  static TextStyle screenTitle({Color color = AppColors.textPrimary}) =>
      GoogleFonts.inter(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.3,
        height: 1.25,
      );

  /// Section title (18–20px, SemiBold)
  static TextStyle sectionTitle({Color color = AppColors.textPrimary}) =>
      GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.35,
      );

  /// Subtitle / description (15px, Regular)
  static TextStyle subtitle({Color color = AppColors.textSecondary}) =>
      GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.5,
      );

  /// Body (14–16px, Regular)
  static TextStyle body({Color color = AppColors.textPrimary}) =>
      GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.5,
      );

  /// Body small (13–14px)
  static TextStyle bodySmall({Color color = AppColors.textSecondary}) =>
      GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.4,
      );

  /// Input label (12–13px, SemiBold)
  static TextStyle inputLabel({Color color = AppColors.textPrimary}) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.4,
        height: 1.3,
      );

  /// Input text (15px)
  static TextStyle inputText({Color color = AppColors.textPrimary}) =>
      GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.4,
      );

  /// Helper / hint text (12px)
  static TextStyle helper({Color color = AppColors.textSecondary}) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.4,
      );

  /// Error text (12px)
  static TextStyle errorText() =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.error,
        height: 1.4,
      );

  /// Button text (15–16px, SemiBold)
  static TextStyle buttonText({Color color = Colors.white}) =>
      GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.1,
        height: 1.2,
      );

  /// User ID / important value display (17px, SemiBold)
  static TextStyle userIdDisplay({Color color = AppColors.primary}) =>
      GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.5,
        height: 1.3,
      );

  /// App name display (large, Bold)
  static TextStyle appName({Color color = AppColors.textPrimary}) =>
      GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.2,
        height: 1.2,
      );

  /// Caption / micro text (11px)
  static TextStyle caption({Color color = AppColors.textSecondary}) =>
      GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.4,
      );

  /// Link text (15px, SemiBold, primary color)
  static TextStyle link({Color color = AppColors.primary}) =>
      GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.4,
      );
}
