import 'package:flutter/material.dart';

/// Central color definitions tailored for a modern, high-contrast financial management interface.
class AppColors {
  AppColors._();

  // Primary & Brand Hues
  static const Color primary = Color(0xFF1E3A8A); // Deep Royal Navy
  static const Color primaryLight = Color(0xFF3B82F6); // Electric Blue
  static const Color primaryDark = Color(0xFF0F172A); // Midnight Slate
  static const Color primaryContainer = Color(0xFFDBEAFE);

  // Secondary & Accents
  static const Color secondary = Color(0xFF475569); // Slate Grey
  static const Color secondaryLight = Color(0xFF94A3B8);
  static const Color secondaryContainer = Color(0xFFF1F5F9);
  static const Color onSecondaryContainer = Color(0xFF334155);
  static const Color outlineVariantLight = Color(0xFFE2E8F0);
  static const Color surfaceContainerLowestLight = Color(0xFFFFFFFF);

  // Status Colors (Collections, Plans & Installments)
  static const Color success = Color(0xFF10B981); // Emerald Green (Paid / Active)
  static const Color successContainer = Color(0xFFD1FAE5);
  static const Color onSuccessContainer = Color(0xFF065F46);

  static const Color warning = Color(0xFFF59E0B); // Amber (Pending / Due Soon)
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color onWarningContainer = Color(0xFF92400E);

  static const Color error = Color(0xFFEF4444); // Crimson / Rose (Overdue / Cancelled)
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color onErrorContainer = Color(0xFF991B1B);

  static const Color info = Color(0xFF0284C7); // Sky Blue
  static const Color infoContainer = Color(0xFFE0F2FE);

  // Light Theme Surfaces
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceCardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color dividerLight = Color(0xFFF1F5F9);

  // Dark Theme Surfaces
  static const Color backgroundDark = Color(0xFF0A0E17);
  static const Color surfaceDark = Color(0xFF121824);
  static const Color surfaceCardDark = Color(0xFF1A2234);
  static const Color borderDark = Color(0xFF26334A);
  static const Color dividerDark = Color(0xFF1F293D);

  // Text Colors
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textMutedLight = Color(0xFF94A3B8);

  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textMutedDark = Color(0xFF64748B);
}
