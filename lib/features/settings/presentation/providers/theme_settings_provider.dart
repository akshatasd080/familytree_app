import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/theme.dart';

class ThemeSettingsProvider extends ChangeNotifier {
  ThemeSettingsProvider() {
    _load();
  }

  static const _kDark = 'ft_theme_dark';
  static const _kAccent = 'ft_theme_accent';

  static const List<Color> presets = [
    Color(0xFF1E3A8A), // deep blue
    Color(0xFF2563EB), // bright blue
    Color(0xFF14B8A6), // teal
    Color(0xFF3D6B4F), // forest (app default)
    Color(0xFFF97316), // orange
    Color(0xFFEF4444), // red
    Color(0xFF8B5CF6), // purple
    Color(0xFFEC4899), // pink
  ];

  bool _ready = false;
  bool _isDark = false;
  Color _accent = AppTheme.defaultAccent;

  bool get ready => _ready;
  bool get isDark => _isDark;
  Color get accent => _accent;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool(_kDark) ?? false;
    final raw = prefs.getInt(_kAccent);
    if (raw != null) _accent = Color(raw);
    AppTheme.apply(isDark: _isDark, accent: _accent);
    _ready = true;
    notifyListeners();
  }

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    AppTheme.apply(isDark: _isDark, accent: _accent);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDark, _isDark);
  }

  Future<void> setAccent(Color color) async {
    if (_accent.toARGB32() == color.toARGB32()) return;
    _accent = color;
    AppTheme.apply(isDark: _isDark, accent: _accent);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAccent, color.toARGB32());
  }

  Future<void> reset() async {
    _isDark = false;
    _accent = AppTheme.defaultAccent;
    AppTheme.apply(isDark: _isDark, accent: _accent);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDark, false);
    await prefs.setInt(_kAccent, _accent.toARGB32());
  }
}
