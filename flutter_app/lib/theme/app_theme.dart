import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Executive Dark Industrial Safety Palette (Matching DoseBand Web UI)
  static const Color scaffoldBg = Color(0xFF0E1117); // Web dark root background
  static const Color backgroundDark = scaffoldBg; // Backward-compatible alias
  static const Color surfaceCard = Color(0xFF1E293B); // Elevated container / card surface
  static const Color surfaceDeep = Color(0xFF0F172A); // Deep inset surface
  static const Color borderColor = Color(0xFF334155); // Slate 700 border
  static const Color borderSubtle = Color(0xFF1E293B);

  // Text Hierarchy
  static const Color textPrimary = Color(0xFFF8FAFC); // White / Slate 50
  static const Color textSecondary = Color(0xFFCBD5E1); // Slate 300
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400
  static const Color textFaint = Color(0xFF64748B); // Slate 500

  // Brand & Safety Accents
  static const Color safetyOrange = Color(0xFFF97316); // Vibrant Safety Orange
  static const Color safetyOrangeDark = Color(0xFFEA580C);
  static const Color primaryNavy = Color(0xFF0F172A);
  static const Color primaryNavyLight = Color(0xFF94A3B8);
  static const Color accentCyan = Color(0xFF38BDF8); // Cyan Accent

  // High-Contrast Risk Level Colors
  static const Color safeGreen = Color(0xFF10B981); // Emerald 500
  static const Color safeGreenBg = Color(0xFF064E3B); // Dark green container
  
  static const Color cautionYellow = Color(0xFFF59E0B); // Amber 500
  static const Color cautionYellowBg = Color(0xFF78350F); // Dark amber container
  
  static const Color unsafeRed = Color(0xFFEF4444); // Red 500
  static const Color unsafeRedBg = Color(0xFF7F1D1D); // Dark red container

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: safetyOrange,
        secondary: accentCyan,
        surface: surfaceCard,
        error: unsafeRed,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: scaffoldBg,
      
      // Typography with Inter
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -1.0),
        displayMedium: GoogleFonts.inter(fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.8),
        headlineLarge: GoogleFonts.inter(fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.5),
        headlineMedium: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textPrimary, letterSpacing: -0.3),
        titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textPrimary, letterSpacing: -0.2),
        titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: GoogleFonts.inter(color: textSecondary, fontSize: 14),
        bodyMedium: GoogleFonts.inter(color: textMuted, fontSize: 13),
        labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, letterSpacing: 0.2),
      ),
      
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceDeep,
        foregroundColor: textPrimary,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18, 
          fontWeight: FontWeight.w700, 
          color: textPrimary,
          letterSpacing: -0.4,
        ),
      ),
      
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceDeep,
        selectedItemColor: safetyOrange,
        unselectedItemColor: textFaint,
        elevation: 12,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 11),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: safetyOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
      
      cardTheme: const CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: borderColor, width: 1.0),
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDeep,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: safetyOrange, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textMuted),
        hintStyle: const TextStyle(color: textFaint),
      ),
    );
  }
}
