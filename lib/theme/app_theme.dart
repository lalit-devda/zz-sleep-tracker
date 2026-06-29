import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Mockup palettes
  static const Color accent = Color(0xFF7CB342); // Beautiful plant green
  static const Color accentDark = Color(0xFF558B2F);
  static const Color textPrimary = Color(0xFF2C3E50); // Dark slate for premium readability
  static const Color textSecondary = Color(0xFF7F8C8D);
  static const Color xpColor = Color(0xFFFFB300); // Gold XP
  static const Color sleepBlue = Color(0xFF1E88E5);
  static const Color pinkAccent = Color(0xFFE91E63);

  // Dynamic skies
  static const List<Color> daySkyGradient = [
    Color(0xFF90CAF9),
    Color(0xFFE3F2FD),
  ];

  static const List<Color> nightSkyGradient = [
    Color(0xFF081B33),
    Color(0xFF061021),
  ];

  // Grassy field
  static const List<Color> grassGradient = [
    Color(0xFF9CCC65),
    Color(0xFF689F38),
  ];

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF9FBFC),
    colorScheme: const ColorScheme.light(
      primary: accent,
      secondary: xpColor,
      surface: Colors.white,
      onPrimary: Colors.white,
    ),
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme).copyWith(
      bodyLarge: GoogleFonts.poppins(color: textPrimary),
      bodyMedium: GoogleFonts.poppins(color: textPrimary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.withOpacity(0.04),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: accent, width: 2),
      ),
      hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(vertical: 18),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
        elevation: 0,
      ),
    ),
  );

  // Keep compatibility for any references to darkTheme
  static ThemeData get darkTheme => lightTheme;
  static Color get bgNight => const Color(0xFF081B33);
  static Color get bgDay => const Color(0xFFE3F2FD);
  static Color get surface => Colors.white;
  static Color get cardNight => Colors.white;
}
