import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Central typography styles ensuring hierarchy across dashboard and data views
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Roboto';

  static TextTheme createTextTheme({required bool isDark}) {
    final Color primaryColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final Color secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final Color mutedColor = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    return TextTheme(
      // Display
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 32.0,
        fontWeight: FontWeight.bold,
        color: primaryColor,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 28.0,
        fontWeight: FontWeight.bold,
        color: primaryColor,
      ),
      displaySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 24.0,
        fontWeight: FontWeight.bold,
        color: primaryColor,
      ),

      // Headlines
      headlineLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 22.0,
        fontWeight: FontWeight.w700,
        color: primaryColor,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 20.0,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
      headlineSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 18.0,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),

      // Titles
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16.0,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14.0,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
      titleSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 13.0,
        fontWeight: FontWeight.w600,
        color: secondaryColor,
      ),

      // Body
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16.0,
        fontWeight: FontWeight.normal,
        color: primaryColor,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14.0,
        fontWeight: FontWeight.normal,
        color: secondaryColor,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12.0,
        fontWeight: FontWeight.normal,
        color: mutedColor,
      ),

      // Labels & Badges
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14.0,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
      labelMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12.0,
        fontWeight: FontWeight.w500,
        color: secondaryColor,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 11.0,
        fontWeight: FontWeight.w500,
        color: mutedColor,
        letterSpacing: 0.5,
      ),
    );
  }
}
