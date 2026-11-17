import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Visual tokens matching tree_frontend family pages (Login / shell / dashboard).
/// Light/dark + accent are driven by [apply] from ThemeSettingsProvider.
class AppTheme {
  AppTheme._();

  static const Color defaultAccent = Color(0xFF3D6B4F);
  static const Color forestDark = Color(0xFF345A43);
  static const Color accentPink = Color(0xFFFF5C8A);
  static const Color emerald50 = Color(0xFFECFDF5);
  static const Color emerald100 = Color(0xFFD1FAE5);
  static const Color emerald600 = Color(0xFF059669);
  static const Color amber50 = Color(0xFFFFFBEB);
  static const Color amber200 = Color(0xFFFDE68A);

  static bool _isDark = false;
  static Color _accent = defaultAccent;

  static void apply({required bool isDark, required Color accent}) {
    _isDark = isDark;
    _accent = accent;
  }

  static bool get isDark => _isDark;
  static Color get accent => _accent;

  /// Brand / primary — follows selected accent.
  static Color get forest => _accent;

  static Color get ink =>
      _isDark ? const Color(0xFFF1F5F3) : const Color(0xFF1F2A24);
  static Color get inkSoft =>
      _isDark ? const Color(0xFFE2E8E4) : const Color(0xFF2A1F14);
  static Color get muted =>
      _isDark ? const Color(0xFF9CA8A2) : const Color(0xFF6B726E);
  static Color get mutedSoft =>
      _isDark ? const Color(0xFF8A9590) : const Color(0xFF5C6560);
  static Color get border =>
      _isDark ? const Color(0xFF3A4540) : const Color(0xFFD9D2C8);
  static Color get borderSoft =>
      _isDark ? const Color(0xFF2F3A35) : const Color(0xFFE5DFD6);
  static Color get canvas =>
      _isDark ? const Color(0xFF121816) : const Color(0xFFF7F4EF);
  static Color get cream =>
      _isDark ? const Color(0xFF1A221E) : const Color(0xFFF4EFE6);
  static Color get tabTrack =>
      _isDark ? const Color(0xFF24302B) : const Color(0xFFEDE7DE);
  static Color get shellBg =>
      _isDark ? const Color(0xFF0E1411) : const Color(0xFFF4F6F5);
  static Color get card =>
      _isDark ? const Color(0xFF1A221E) : Colors.white;
  static Color get drawerBg =>
      _isDark ? const Color(0xFF15201B) : Colors.white;

  static TextStyle display({
    double size = 28,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double height = 1.15,
  }) =>
      GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: weight,
        color: color ?? ink,
        height: height,
      );

  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.45,
  }) =>
      GoogleFonts.outfit(
        fontSize: size,
        fontWeight: weight,
        color: color ?? ink,
        height: height,
      );

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  /// Colors for a given brightness — never read [_isDark] here so light/dark
  /// ThemeData stay correct even when the opposite mode is currently selected.
  static Color _inkFor(bool dark) =>
      dark ? const Color(0xFFF1F5F3) : const Color(0xFF1F2A24);
  static Color _inkSoftFor(bool dark) =>
      dark ? const Color(0xFFE2E8E4) : const Color(0xFF2A1F14);
  static Color _mutedFor(bool dark) =>
      dark ? const Color(0xFF9CA8A2) : const Color(0xFF6B726E);
  static Color _borderFor(bool dark) =>
      dark ? const Color(0xFF3A4540) : const Color(0xFFD9D2C8);
  static Color _borderSoftFor(bool dark) =>
      dark ? const Color(0xFF2F3A35) : const Color(0xFFE5DFD6);
  static Color _canvasFor(bool dark) =>
      dark ? const Color(0xFF121816) : const Color(0xFFF7F4EF);
  static Color _creamFor(bool dark) =>
      dark ? const Color(0xFF1A221E) : const Color(0xFFF4EFE6);
  static Color _shellBgFor(bool dark) =>
      dark ? const Color(0xFF0E1411) : const Color(0xFFF4F6F5);
  static Color _cardFor(bool dark) =>
      dark ? const Color(0xFF1A221E) : Colors.white;
  static Color _drawerBgFor(bool dark) =>
      dark ? const Color(0xFF15201B) : Colors.white;

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final inkC = _inkFor(dark);
    final inkSoftC = _inkSoftFor(dark);
    final mutedC = _mutedFor(dark);
    final borderC = _borderFor(dark);
    final borderSoftC = _borderSoftFor(dark);
    final canvasC = _canvasFor(dark);
    final creamC = _creamFor(dark);
    final shellC = _shellBgFor(dark);
    final cardC = _cardFor(dark);
    final drawerC = _drawerBgFor(dark);

    // Keep filled/chip labels black on brand-colored surfaces (app-wide).
    final scheme = ColorScheme.fromSeed(
      seedColor: _accent,
      primary: _accent,
      brightness: brightness,
      surface: dark ? const Color(0xFF121816) : canvasC,
    ).copyWith(
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onTertiary: Colors.black,
      onPrimaryContainer: Colors.black,
      onSecondaryContainer: Colors.black,
      onTertiaryContainer: Colors.black,
      onError: Colors.black,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: shellC,
    );
    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: drawerC,
        foregroundColor: inkC,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: inkC,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardC,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderSoftC),
        ),
      ),
      drawerTheme: DrawerThemeData(backgroundColor: drawerC),
      dividerColor: borderSoftC,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardC,
        hintStyle: GoogleFonts.outfit(color: mutedC),
        labelStyle: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: inkSoftC,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderC),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderC),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _accent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.black,
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Colors.black,
          ),
          iconColor: Colors.black,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.black,
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
          iconColor: Colors.black,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: inkC,
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: inkC,
          ),
          iconColor: inkC,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: inkC,
          side: BorderSide(color: borderC),
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            color: inkC,
          ),
          iconColor: inkC,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        foregroundColor: Colors.black,
        backgroundColor: _accent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: creamC,
        selectedColor: _accent,
        disabledColor: creamC,
        secondarySelectedColor: _accent,
        labelStyle: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
        secondaryLabelStyle: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
        checkmarkColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardC,
        indicatorColor: _accent.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? _accent : mutedC,
          );
        }),
      ),
    );
  }
}
