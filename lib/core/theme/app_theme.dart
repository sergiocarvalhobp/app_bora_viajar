import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// ThemeData do Bora Viajar.
/// Reproduz a identidade visual do site (DM Serif Display + Nunito,
/// paleta Terra Brasileira, bordas arredondadas generosas).
abstract final class AppTheme {
  // ── Raio padrão de bordas (site usa --radius: 1rem = 16px) ────────────────
  static const _radius = 16.0;
  static final _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(_radius),
  );

  // ── Tipografia ────────────────────────────────────────────────────────────
  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    return AppTextStyles.buildWith(primary, secondary);
  }

  // ── Tema claro ────────────────────────────────────────────────────────────
  static ThemeData light() {
    final text = _buildTextTheme(AppColors.bark, AppColors.barkMuted);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Nunito',
      textTheme: text,

      colorScheme: const ColorScheme.light(
        primary:          AppColors.forest,
        onPrimary:        AppColors.cream,
        primaryContainer: Color(0xFFD4EDDF),
        onPrimaryContainer: AppColors.forestDk,

        secondary:        AppColors.terra,
        onSecondary:      AppColors.cream,
        secondaryContainer: Color(0xFFF5D5C3),
        onSecondaryContainer: Color(0xFF8B3A14),

        surface:          AppColors.cream,
        onSurface:        AppColors.bark,
        surfaceContainerLow: Colors.white,
        surfaceContainerHighest: AppColors.sand,

        outline:          AppColors.sand,
        outlineVariant:   Color(0xFFDDD0C0),

        error:            AppColors.error,
        onError:          Colors.white,
      ),

      scaffoldBackgroundColor: AppColors.cream,
      dividerColor: AppColors.sand,

      // ── AppBar ─────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.bark,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.sand,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        iconTheme: const IconThemeData(color: AppColors.bark),
      ),

      // ── BottomNavigationBar ────────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.forest,
        unselectedItemColor: AppColors.barkMuted,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),

      // ── NavigationBar (Material 3) ─────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFD4EDDF),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.forest);
          }
          return const IconThemeData(color: AppColors.barkMuted);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            );
          }
          return const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.barkMuted,
          );
        }),
      ),

      // ── ElevatedButton ─────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.forest,
          foregroundColor: AppColors.cream,
          minimumSize: const Size.fromHeight(52),
          shape: _shape,
          textStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          elevation: 0,
        ),
      ),

      // ── OutlinedButton ─────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.forest,
          minimumSize: const Size.fromHeight(52),
          shape: _shape,
          side: const BorderSide(color: AppColors.forest, width: 2),
          textStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // ── TextButton ─────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.forest,
          textStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Card ───────────────────────────────────────────────────────────
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: const BorderSide(color: AppColors.sand),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── InputDecoration ────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: AppColors.sand),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: AppColors.sand),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: AppColors.forest, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Nunito',
          color: AppColors.barkMuted,
          fontSize: 14,
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Nunito',
          color: AppColors.barkMuted,
          fontSize: 14,
        ),
      ),

      // ── Chip ───────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.sand,
        selectedColor: const Color(0xFFD4EDDF),
        labelStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.bark,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),

      // ── SnackBar ───────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bark,
        contentTextStyle: const TextStyle(
          fontFamily: 'Nunito',
          color: AppColors.cream,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Tema escuro ───────────────────────────────────────────────────────────
  static ThemeData dark() {
    final text = _buildTextTheme(AppColors.darkText, AppColors.darkMuted);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Nunito',
      textTheme: text,

      colorScheme: const ColorScheme.dark(
        primary:          AppColors.forestLt,
        onPrimary:        AppColors.darkBg,
        primaryContainer: AppColors.forestDk,
        onPrimaryContainer: Color(0xFFB8E4C9),

        secondary:        AppColors.terraLt,
        onSecondary:      AppColors.darkBg,
        secondaryContainer: Color(0xFF5C2A12),
        onSecondaryContainer: Color(0xFFF5C4A8),

        surface:          AppColors.darkSurface,
        onSurface:        AppColors.darkText,
        surfaceContainerLow: AppColors.darkBg,
        surfaceContainerHighest: AppColors.darkBorder,

        outline:          AppColors.darkBorder,
        outlineVariant:   Color(0xFF2E2218),

        error:            Color(0xFFFF6B6B),
        onError:          AppColors.darkBg,
      ),

      scaffoldBackgroundColor: AppColors.darkBg,
      dividerColor: AppColors.darkBorder,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkText,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.darkBorder,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.forestLt,
        unselectedItemColor: AppColors.darkMuted,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),

      cardTheme: CardTheme(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
        margin: EdgeInsets.zero,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.forestLt,
          foregroundColor: AppColors.darkBg,
          minimumSize: const Size.fromHeight(52),
          shape: _shape,
          textStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          elevation: 0,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: AppColors.forestLt, width: 2),
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Nunito',
          color: AppColors.darkMuted,
          fontSize: 14,
        ),
      ),
    );
  }
}
