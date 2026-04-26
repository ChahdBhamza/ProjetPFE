import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CybersightTheme {
  // Navy + neo-glass palette (dark, clean, vibrant accents)
  static const Color obsidian = Color(0xFF060817); // deep navy base
  static const Color onyx = Color(0xFF060A1F); // darker input fill
  static const Color navy1 = Color(0xFF0A0F2D);
  static const Color navy2 = Color(0xFF071124);

  // Vibrant accents (kept tasteful via opacity/gradients)
  static const Color accent = Color(0xFF2DE2FF); // electric cyan
  static const Color accent2 = Color(0xFFB84DFF); // vibrant violet
  static const Color warning = Color(0xFFFFB020);
  static const Color ok = Color(0xFF00F5A0);

  static const Color surfaceHigh = Color(0xFF0A0F2B);
  static const Color borderSubtle = Color(0xFF1A234A);
  static const Color borderStrong = Color(0xFF2A3A7A);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: obsidian,
      primaryColor: accent,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accent2,
        surface: surfaceHigh,
        error: warning,
      ),
      dividerTheme: const DividerThemeData(color: borderSubtle, thickness: 1),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 1.8, color: Colors.white),
        headlineMedium: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 1.3, color: Colors.white),
        bodyLarge: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.white70),
        labelLarge: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: accent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: onyx,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderSubtle)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderSubtle)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: accent, width: 2)),
        labelStyle: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w600),
        floatingLabelStyle: GoogleFonts.plusJakartaSans(color: accent, fontSize: 13, fontWeight: FontWeight.w700),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white.withOpacity(0.55),
          fontSize: 14,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }

  static TextStyle get brandingStyle => GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: 1.8,
      );

  static TextStyle get labelStyle => GoogleFonts.plusJakartaSans(
        fontSize: 8,
        fontWeight: FontWeight.w800,
        color: Colors.white38,
        letterSpacing: 1.3,
      );
}
