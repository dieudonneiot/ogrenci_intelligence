import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const brandPurple = Color(0xFF6D28D9);
  static const brandIndigo = Color(0xFF4F46E5);

  // Light surfaces (used sparingly; prefer Theme.of(context).colorScheme)
  static const bg = Color(0xFFF9FAFB);
  static const surface = Color(0xFFFFFFFF);

  // Text (avoid pure black for a softer look)
  static const ink = Color(0xFF1F2937); // gray-800
  static const inkMuted = Color(0xFF4B5563); // gray-600

  // Semantic accents
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
}
