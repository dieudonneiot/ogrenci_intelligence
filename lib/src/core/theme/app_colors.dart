import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // Brand
  static const primary = Color(0xFF14B8A6);
  static const secondary = Color(0xFF6366F1);
  static const primaryHover = Color(0xFF0F9E8F);

  // Surfaces
  static const bg = Color(0xFFFAFAFA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF8FAFC);

  // Text
  static const ink = Color(0xFF0F172A);
  static const inkMuted = Color(0xFF64748B);

  // Borders
  static const borderLight = Color(0xFFE2E8F0);

  // Semantic accents
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);

  // Backward-compatible aliases for existing usage.
  static const brandPurple = primary;
  static const brandIndigo = secondary;
}
