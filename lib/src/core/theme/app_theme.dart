import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandPurple,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bg,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.onSurface.withAlpha(31);
            }
            return colorScheme.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.onSurface.withAlpha(97);
            }
            return colorScheme.onPrimary;
          }),
          iconColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.onSurface.withAlpha(97);
            }
            return colorScheme.onPrimary;
          }),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(colorScheme.primary),
          iconColor: WidgetStatePropertyAll(colorScheme.primary),
          side: WidgetStatePropertyAll(
            BorderSide(color: colorScheme.primary.withAlpha(89)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(colorScheme.primary),
          iconColor: WidgetStatePropertyAll(colorScheme.primary),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
