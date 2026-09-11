import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Industrial Safety Palette (Matching Streamlit Web UI CSS)
  static const Color scaffoldBg = Color(0xFFF8FAFC); // Web light root background (--light-bg)
  static const Color backgroundDark = Color(0xFF0F172A); // Slate 900 dark background
  static const Color surfaceCard = Color(0xFFFFFFFF); // Clean white container / card
  static const Color surfaceElevated = Color(0xFFF1F5F9); // Light slate header / chip background
  static const Color surfaceDeep = Color(0xFF0F172A); // Primary navy (--primary-navy)
  static const Color secondarySlate = Color(0xFF1E293B); // Dark slate header
  static const Color borderColor = Color(0xFFE2E8F0); // Subtle border (--border-color)
  static const Color borderStrong = Color(0xFFCBD5E1);

  // Text Hierarchy
  static const Color textPrimary = Color(0xFF0F172A); // High-contrast navy text
  static const Color textSecondary = Color(0xFF334155); // Slate 700
  static const Color textMuted = Color(0xFF64748B); // Slate 500
  static const Color textFaint = Color(0xFF94A3B8); // Slate 400

  // Brand & Safety Accents
  static const Color safetyOrange = Color(0xFFEA580C); // Safety Orange (--safety-orange)
  static const Color safetyOrangeLight = Color(0xFFF97316);
  static const Color safetyOrangeBg = Color(0xFFFFF7ED); // Light orange tint container
  static const Color primaryNavy = Color(0xFF0F172A);
  static const Color accentCyan = Color(0xFF0284C7); // Cyan / Blue Accent
  static const Color accentPurple = Color(0xFF8B5CF6); // Violet Accent

  // High-Contrast Risk Level Colors
  static const Color safeGreen = Color(0xFF10B981); // Emerald 500
  static const Color safeGreenBg = Color(0xFFECFDF5); // Light green container
  static const Color safeGreenDark = Color(0xFF065F46);
  
  static const Color cautionYellow = Color(0xFFF59E0B); // Amber 500
  static const Color cautionYellowBg = Color(0xFFFFFBEB); // Light amber container
  static const Color cautionYellowDark = Color(0xFFB45309);
  
  static const Color unsafeRed = Color(0xFFEF4444); // Red 500
  static const Color unsafeRedBg = Color(0xFFFEF2F2); // Light red container
  static const Color unsafeRedDark = Color(0xFF991B1B);

  // Gradients
  static const LinearGradient navyHeroGradient = LinearGradient(
    colors: [Color(0xFF0B1120), Color(0xFF1E293B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient orangeAccentGradient = LinearGradient(
    colors: [Color(0xFFEA580C), Color(0xFFFB923C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient safeGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cautionGradient = LinearGradient(
    colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient unsafeGradient = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Premium Box Shadows
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.02),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get orangeGlow => [
    BoxShadow(
      color: safetyOrange.withValues(alpha: 0.25),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: safetyOrange,
        secondary: primaryNavy,
        surface: surfaceCard,
        error: unsafeRed,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: scaffoldBg,
      
      // Typography with GoogleFonts Inter
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(fontWeight: FontWeight.w900, color: textPrimary, letterSpacing: -1.2),
        displayMedium: GoogleFonts.inter(fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.9),
        headlineLarge: GoogleFonts.inter(fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.6),
        headlineMedium: GoogleFonts.inter(fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.4),
        titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.3),
        titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textPrimary, letterSpacing: -0.2),
        bodyLarge: GoogleFonts.inter(color: textSecondary, fontSize: 14, height: 1.4),
        bodyMedium: GoogleFonts.inter(color: textMuted, fontSize: 13, height: 1.4),
        labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w700, letterSpacing: 0.3),
      ),
      
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1.5,
        shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.08),
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18, 
          fontWeight: FontWeight.w900, 
          color: textPrimary,
          letterSpacing: -0.4,
        ),
      ),
      
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: safetyOrange,
        unselectedItemColor: textMuted,
        elevation: 12,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 11),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: safetyOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.2),
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
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: borderColor, width: 1.0),
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: safetyOrange, width: 1.8),
        ),
        labelStyle: const TextStyle(color: textMuted, fontSize: 13),
        hintStyle: const TextStyle(color: textFaint, fontSize: 13),
      ),
    );
  }

  // Backwards-compatible getter
  static ThemeData get darkTheme => lightTheme;
}
