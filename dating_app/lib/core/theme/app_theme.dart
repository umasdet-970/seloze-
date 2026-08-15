import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  static const primary = Color(0xFF7B5CFA); // purple accent
  static const primaryDark = Color(0xFF6A4CE0);
  static const like = Color(0xFFFF4D6D); // heart pink
  static const superLike = Color(0xFF7B5CFA); // star purple
  static const pass = Color(0xFF9CA3AF); // grey X

  static const bgLight = Color(0xFFF7F6FB);
  static const bgDark = Color(0xFF121016);
  static const cardDark = Color(0xFF1C1A22);

  static const success = Color(0xFF22C55E); // online dot
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);

  // Kept for the screens not yet migrated to Theme.of(context) — light-mode
  // values only. New/updated code should read Theme.of(context).colorScheme
  // (.onSurface / .onSurfaceVariant / .surface) instead, which actually
  // flips with system dark mode; these constants never do.
  static const textDark = Color(0xFF1F1B2E);
  static const textMuted = Color(0xFF8E8A9B);

  // Dark-mode counterparts, used only inside AppTheme.dark() below.
  static const textLightOnDark = Color(0xFFF2F1F7);
  static const textMutedOnDark = Color(0xFFA7A3B5);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgLight,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.like,
        surface: Colors.white,
        onSurface: AppColors.textDark,
        onSurfaceVariant: AppColors.textMuted,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textDark,
        displayColor: AppColors.textDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgLight,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textDark,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgDark,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.like,
        surface: AppColors.cardDark,
        onSurface: AppColors.textLightOnDark,
        onSurfaceVariant: AppColors.textMutedOnDark,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textLightOnDark,
        displayColor: AppColors.textLightOnDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textLightOnDark,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.cardDark,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMutedOnDark,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
      ),
    );
  }
}
