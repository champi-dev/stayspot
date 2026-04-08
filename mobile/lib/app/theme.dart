import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFFFF5A5F);
  static const primaryDark = Color(0xFFE04850);
  static const secondary = Color(0xFF00A699);
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF7F7F7);
  static const divider = Color(0xFFEBEBEB);
  static const textPrimary = Color(0xFF222222);
  static const textSecondary = Color(0xFF717171);
  static const textTertiary = Color(0xFFB0B0B0);
  static const overlay = Color(0x80000000);
  static const star = Color(0xFFFFB400);
  static const error = Color(0xFFC13515);
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

class AppRadius {
  static const double card = 12;
  static const double button = 8;
  static const double chip = 20;
  static const double avatar = 100;
  static const double bottomSheet = 16;
  static const double searchBar = 32;
  static const double input = 8;
}

class AppShadows {
  static List<BoxShadow> get card => [
        const BoxShadow(
          offset: Offset(0, 1),
          blurRadius: 2,
          color: Color(0x14000000),
        ),
        const BoxShadow(
          offset: Offset(0, 4),
          blurRadius: 12,
          color: Color(0x0D000000),
        ),
      ];

  static List<BoxShadow> get cardPressed => [
        const BoxShadow(
          offset: Offset(0, 0),
          blurRadius: 0,
          color: Color(0x14000000),
        ),
      ];

  static List<BoxShadow> get bottomNav => [
        const BoxShadow(
          offset: Offset(0, -1),
          blurRadius: 4,
          color: Color(0x14000000),
        ),
      ];

  static List<BoxShadow> get stickyBar => [
        const BoxShadow(
          offset: Offset(0, -2),
          blurRadius: 8,
          color: Color(0x1A000000),
        ),
      ];

  static List<BoxShadow> get bottomSheet => [
        const BoxShadow(
          offset: Offset(0, -4),
          blurRadius: 16,
          color: Color(0x26000000),
        ),
      ];

  static List<BoxShadow> get searchBar => [
        const BoxShadow(
          offset: Offset(0, 2),
          blurRadius: 8,
          color: Color(0x1F000000),
        ),
      ];

  static List<BoxShadow> get floatingButton => [
        const BoxShadow(
          offset: Offset(0, 2),
          blurRadius: 8,
          color: Color(0x33000000),
        ),
      ];
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.background,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.divider,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          height: 40 / 32,
          color: AppColors.textPrimary,
        ),
        displayMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          height: 34 / 26,
          color: AppColors.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          height: 28 / 22,
          color: AppColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 24 / 18,
          color: AppColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 24 / 16,
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 20 / 14,
          color: AppColors.textPrimary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 16 / 12,
          color: AppColors.textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 20 / 16,
          color: Colors.white,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.textPrimary,
        unselectedItemColor: AppColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        unselectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w400),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.textPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        hintStyle: const TextStyle(color: AppColors.textTertiary),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 0,
      ),
    );
  }
}
