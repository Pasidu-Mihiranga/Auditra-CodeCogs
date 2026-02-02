
import 'package:flutter/material.dart';
import '../../../widgets/shared_dashboard_widgets.dart';

class FieldOfficerStyles {
  // Brand Colors
  static const Color primaryBlue = Color(0xFF0570B0);
  static const Color lightBlue = Color(0xFF84BCDA);
  
  // Reuse shared colors
  static const Color background = DashboardColors.background;
  static const Color darkNavy = DashboardColors.darkNavy;
  
  // Text Styles
  static const TextStyle headerTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: 0.5,
  );
  
  static const TextStyle headerSubtitle = TextStyle(
    fontSize: 14,
    color: Colors.white70,
    letterSpacing: 0.3,
  );
  
  static BoxDecoration headerGradient = const BoxDecoration(
    gradient: LinearGradient(
      colors: [primaryBlue, lightBlue],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );
  
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );
}
