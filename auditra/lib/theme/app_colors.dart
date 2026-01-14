import 'package:flutter/material.dart';

/// Centralized color palette for the application.
/// Matches the Auditra web app blue-based palette.
class AppColors {
  // Core Palette (Matches web theme.js)
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color primaryLight = Color(0xFF42A5F5);
  static const Color secondary = Color(0xFF60A5FA);
  static const Color accent = Color(0xFF3B82F6);
  
  // Backgrounds
  static const Color background = Color(0xFFF1F5F9); // Slightly lighter grey/blue
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardInner = Color(0xFFF8FAFC);
  static const Color paper = Color(0xFFFFFFFF);
  
  // Text (Matches web text.primary/secondary)
  static const Color text = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // Status Colors (Matches web success/warning/error)
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);

  // UI Specific
  static const Color divider = Color(0xFFE2E8F0);
  static const Color border = Color(0xFFE2E8F0);
  static const Color shadow = Color(0x0F000000); // 6% black shadow
  
  // Sidebar/Header specific (from web custom)
  static const Color headerText = Color(0xFF0F172A);
  static const Color headerBg = Color(0xFFFFFFFF);
  static const Color sidebarText = Color(0xFF64748B);

  // Card Gradients
  static const List<Color> cardGradient = [
    surface,
    cardInner,
  ];

  // Primary gradients
  static const List<Color> primaryGradient = [
    primaryLight,
    primary,
  ];

  static const List<Color> primaryDarkGradient = [
    primary,
    primaryDark,
  ];

  // Legacy Dashboard Colors (Restored for backward compatibility)
  static const Color darkNavy = Color(0xFF0F172A);
  static const Color strongBlue = Color(0xFF1565C0);
  static const Color blue = Color(0xFF2563EB);
  static const Color lightBlue = Color(0xFF60A5FA);
  static const Color cream = Color(0xFFF8FAFC);
  static const Color yellow = Color(0xFFEAB308);
  static const Color orange = Color(0xFFF97316);
  static const Color orangeRed = Color(0xFFEF4444);
  static const Color red = Color(0xFFDC2626);
  static const Color danger = Color(0xFFDC2626);
}
