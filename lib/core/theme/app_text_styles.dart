import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tipografia fixa do app — cores [AppColors.bark] / [AppColors.barkMuted]
/// independentes do [ThemeMode] ou do tema do sistema.
abstract final class AppTextStyles {
  static TextTheme get textTheme =>
      buildWith(AppColors.bark, AppColors.barkMuted);

  static TextTheme buildWith(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'DMSerifDisplay',
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: primary,
        height: 1.2,
      ),
      displayMedium: TextStyle(
        fontFamily: 'DMSerifDisplay',
        fontSize: 28,
        fontWeight: FontWeight.w400,
        color: primary,
        height: 1.2,
      ),
      displaySmall: TextStyle(
        fontFamily: 'DMSerifDisplay',
        fontSize: 22,
        fontWeight: FontWeight.w400,
        color: primary,
        height: 1.3,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'Nunito',
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: primary,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Nunito',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Nunito',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Nunito',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Nunito',
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleSmall: TextStyle(
        fontFamily: 'Nunito',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Nunito',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: primary,
        height: 1.6,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Nunito',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: primary,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Nunito',
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: secondary,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Nunito',
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      labelMedium: TextStyle(
        fontFamily: 'Nunito',
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: secondary,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Nunito',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: secondary,
      ),
    );
  }
}

extension AppTextThemeContext on BuildContext {
  /// Textos com paleta clara fixa — não muda com tema escuro do sistema.
  TextTheme get appText => AppTextStyles.textTheme;
}
