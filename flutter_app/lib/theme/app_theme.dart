import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Executive Slate & Industrial Accent Palette
  static const Color primaryNavy = Color(0xFF0F172A); // Deep Slate (900)
  static const Color primaryNavyLight = Color(0xFF64748B); // Slate Muted (500)
  static const Color primaryNavyDark = Color(0xFF020617); // Obsidian (950)
  static const Color safetyOrange = Color(0xFFF97316); // Vibrant Safety Orange
  static const Color accentIndigo = Color(0xFF6366F1); // High-Tech Electric Indigo
  
  // Backgrounds & Surfaces
  static const Color scaffoldBg = Color(0xFFF8FAFC); // Clean Ceramic Slate
  static const Color cardBg = Colors.white;
  static const Color borderColor = Color(0xFFE2E8F0); // Subtle Border

  // High-Contrast Risk Level Colors
  static const Color safeGreen = Color(0xFF10B981); // Emerald 500
  static const Color safeGreenBg = Color(0xFFECFDF5);
  
  static const Color cautionYellow = Color(0xFFF59E0B); // Amber 500
  static const Color cautionYellowBg = Color(0xFFFFFBEB);
  
  static const Color unsafeRed = Color(0xFFE11D48); // Rose Crimson 600
  static const Color unsafeRedBg = Color(0xFFFFF1F2);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryNavy,
        primary: primaryNavy,
        secondary: safetyOrange,
        surface: cardBg,
        error: unsafeRed,
      ),
      scaffoldBackgroundColor: scaffoldBg,
      
      // Typography with Inter
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(fontWeight: FontWeight.w800, color: primaryNavy, letterSpacing: -1.0),
        displayMedium: GoogleFonts.inter(fontWeight: FontWeight.w700, color: primaryNavy, letterSpacing: -0.8),
        headlineLarge: GoogleFonts.inter(fontWeight: FontWeight.w700, color: primaryNavy, letterSpacing: -0.5),
        headlineMedium: GoogleFonts.inter(fontWeight: FontWeight.w600, color: primaryNavy, letterSpacing: -0.3),
        titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, color: primaryNavy, letterSpacing: -0.2),
        titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w600, color: primaryNavy),
        bodyLarge: GoogleFonts.inter(color: primaryNavyLight, fontSize: 14),
        bodyMedium: GoogleFonts.inter(color: primaryNavyLight, fontSize: 13),
        labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, letterSpacing: 0.2),
      ),
      
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: primaryNavy,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18, 
          fontWeight: FontWeight.w700, 
          color: primaryNavy,
          letterSpacing: -0.4,
        ),
      ),
      
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryNavy,
        unselectedItemColor: const Color(0xFF94A3B8),
        elevation: 12,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 12),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
      
      cardTheme: const CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: borderColor, width: 0.8),
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryNavy, width: 1.5),
        ),
      ),
    );
  }
}
