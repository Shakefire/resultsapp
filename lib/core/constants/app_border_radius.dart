// lib/core/constants/app_border_radius.dart
import 'package:flutter/material.dart';

/// Border radius constants for consistent rounding throughout the app.
class AppBorderRadius {
  AppBorderRadius._();

  static const double sm = 6.0;
  static const double md = 10.0;
  static const double lg = 12.0;
  static const double xl = 16.0;
  static const double full = 100.0;

  /// Standard input field radius
  static const BorderRadius input = BorderRadius.all(Radius.circular(md));

  /// Standard button radius
  static const BorderRadius button = BorderRadius.all(Radius.circular(md));

  /// Card / container radius
  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));

  /// Chip / badge radius
  static const BorderRadius chip = BorderRadius.all(Radius.circular(full));
}
