import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Visual tokens matching tree_frontend family pages (Login / shell / dashboard).
class AppTheme {
  AppTheme._();

  static const Color forest = Color(0xFF3D6B4F);
  static const Color forestDark = Color(0xFF345A43);
  static const Color ink = Color(0xFF1F2A24);
  static const Color inkSoft = Color(0xFF2A1F14);
  static const Color border = Color(0xFFD9D2C8);
  static const Color borderSoft = Color(0xFFE5DFD6);
  static const Color muted = Color(0xFF6B726E);
  static const Color mutedSoft = Color(0xFF5C6560);
  static const Color canvas = Color(0xFFF7F4EF);
  static const Color cream = Color(0xFFF4EFE6);
  static const Color tabTrack = Color(0xFFEDE7DE);
  static const Color shellBg = Color(0xFFF4F6F5);
  static const Color accentPink = Color(0xFFFF5C8A);
  static const Color emerald50 = Color(0xFFECFDF5);
  static const Color emerald100 = Color(0xFFD1FAE5);
  static const Color emerald600 = Color(0xFF059669);
  static const Color amber50 = Color(0xFFFFFBEB);
  static const Color amber200 = Color(0xFFFDE68A);

  static TextStyle display({
    double size = 28,
    FontWeight weight = FontWeight.w700,
    Color color = ink,
    double height = 1.15,
  }) =>
      GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = ink,
    double height = 1.45,
  }) =>
      GoogleFonts.outfit(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: forest,
        primary: forest,
        surface: canvas,
      ),
      scaffoldBackgroundColor: canvas,
    );
    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderSoft),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: GoogleFonts.outfit(color: const Color(0xFF9AA19C)),
        labelStyle: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF3D4742),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: forest, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: forest,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: forest,
          side: const BorderSide(color: border),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cream,
        selectedColor: forest,
        labelStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: forest.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? forest : muted,
          );
        }),
      ),
      dividerColor: borderSoft,
    );
  }
}
