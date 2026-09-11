import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Executive Slate & Industrial Accent Palette
  static const Color primaryNavy = Color(0xFF0F172A); // Deep Slate (900)
  static const Color primaryNavyLight = Color(0xFF64748B); // Slate Muted (500)
  static const Color primaryNavyDark = Color(0xFF020617); // Obsidian (950)
  static const Color safetyOrange = Color(0xFFEA580C); // Safety Orange #EA580C (OSHA / OISD accent)
  static const Color accentIndigo = Color(0xFF6366F1); // High-Tech Electric Indigo
  static const Color accentCyan = Color(0xFF06B6D4);
  
  // Backgrounds & Surfaces
  static const Color scaffoldBg = Color(0xFFF8FAFC); // Clean Ceramic Slate
  static const Color cardBg = Colors.white;
  static const Color borderColor = Color(0xFFE2E8F0); // Subtle Border
  static const Color darkCardBg = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);

  // High-Contrast Risk Level Colors (DGMS / OSHA Spec)
  static const Color safeGreen = Color(0xFF10B981); // Emerald 500
  static const Color safeGreenBg = Color(0xFFECFDF5);
  static const Color safeGreenBorder = Color(0xFFA7F3D0);
  
  static const Color cautionYellow = Color(0xFFF59E0B); // Amber 500
  static const Color cautionYellowBg = Color(0xFFFFFBEB);
  static const Color cautionYellowBorder = Color(0xFFFDE68A);
  
  static const Color unsafeRed = Color(0xFFEF4444); // Critical Red #EF4444 (Unsafe >= 50.0 ppm*hr)
  static const Color unsafeRedBg = Color(0xFFFEF2F2);
  static const Color unsafeRedBorder = Color(0xFFFECACA);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryNavy,
        primary: primaryNavy,
        secondary: safetyOrange,
        surface: cardBg,
        error: unsafeRed,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: scaffoldBg,
      
      // Modern Typography with Inter
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(fontWeight: FontWeight.w800, color: primaryNavy, letterSpacing: -1.0),
        displayMedium: GoogleFonts.inter(fontWeight: FontWeight.w700, color: primaryNavy, letterSpacing: -0.8),
        headlineLarge: GoogleFonts.inter(fontWeight: FontWeight.w800, color: primaryNavy, letterSpacing: -0.5),
        headlineMedium: GoogleFonts.inter(fontWeight: FontWeight.w700, color: primaryNavy, letterSpacing: -0.3),
        titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w700, color: primaryNavy, letterSpacing: -0.2),
        titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w600, color: primaryNavy),
        bodyLarge: GoogleFonts.inter(color: primaryNavy, fontSize: 14, fontWeight: FontWeight.w400),
        bodyMedium: GoogleFonts.inter(color: primaryNavyLight, fontSize: 13, fontWeight: FontWeight.w400),
        labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w700, letterSpacing: 0.2),
      ),
      
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: primaryNavy,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18, 
          fontWeight: FontWeight.w800, 
          color: primaryNavy,
          letterSpacing: -0.4,
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.2),
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
          borderRadius: BorderRadius.all(Radius.circular(18)),
          side: BorderSide(color: borderColor, width: 1.0),
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
        labelStyle: GoogleFonts.inter(color: primaryNavyLight, fontSize: 13, fontWeight: FontWeight.w500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderColor, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderColor, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryNavy, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: unsafeRed, width: 1.2),
        ),
      ),
    );
  }
}
