import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors - Minimalist Palette
  static const Color primaryNavy = Color(0xFF1E293B); // Softer navy
  static const Color primaryNavyLight = Color(0xFF334155);
  static const Color safetyOrange = Color(0xFFEA580C);
  
  // Backgrounds & Surfaces
  static const Color scaffoldBg = Color(0xFFF8FAFC);
  static const Color cardBg = Colors.white;
  static const Color borderColor = Color(0xFFE2E8F0);

  // Risk Level Colors (Sleeker versions)
  static const Color safeGreen = Color(0xFF10B981);
  static const Color cautionYellow = Color(0xFFF59E0B);
  static const Color unsafeRed = Color(0xFFEF4444);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryNavy,
        primary: primaryNavy,
        secondary: safetyOrange,
        background: scaffoldBg,
        surface: cardBg,
      ),
      scaffoldBackgroundColor: scaffoldBg,
      
      // Premium Typography using Inter
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(fontWeight: FontWeight.w800, color: primaryNavy),
        displayMedium: GoogleFonts.inter(fontWeight: FontWeight.w700, color: primaryNavy),
        headlineLarge: GoogleFonts.inter(fontWeight: FontWeight.w700, color: primaryNavy),
        headlineMedium: GoogleFonts.inter(fontWeight: FontWeight.w600, color: primaryNavy),
        titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, color: primaryNavy),
        bodyLarge: GoogleFonts.inter(color: primaryNavyLight),
        bodyMedium: GoogleFonts.inter(color: primaryNavyLight),
      ),
      
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: primaryNavy,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20, 
          fontWeight: FontWeight.bold, 
          color: primaryNavy,
          letterSpacing: -0.5,
        ),
      ),
      
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: safetyOrange,
        unselectedItemColor: const Color(0xFF94A3B8),
        elevation: 16,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 12),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      
      cardTheme: const CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: borderColor, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
    );
  }
}
