import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  static const primary = Color(0xFF7B5CFA); // matches the consumer app's purple
  static const bg = Color(0xFFF5F6FA);
  static const card = Colors.white;
  static const sidebar = Color(0xFF17141F);
  static const sidebarSelected = Color(0xFF2A2438);
  static const textDark = Color(0xFF1F1B2E);
  static const textMuted = Color(0xFF8E8A9B);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: base.colorScheme.copyWith(primary: AppColors.primary),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textDark,
        displayColor: AppColors.textDark,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textDark,
      ),
    );
  }
}
