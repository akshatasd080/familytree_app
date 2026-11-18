import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Visual themes for /family/tree (canvas, bands, cards, connectors).
class TreeThemeBand {
  const TreeThemeBand({required this.bg, required this.ink});

  final Color bg;
  final Color ink;
}

class TreeThemeLines {
  const TreeThemeLines({
    required this.spouse,
    required this.sibling,
    required this.parent,
  });

  final Color spouse;
  final Color sibling;
  final Color parent;
}

class TreeTheme {
  const TreeTheme({
    required this.id,
    required this.label,
    required this.hint,
    required this.mode,
    required this.canvasBg,
    required this.cardBg,
    required this.cardBorder,
    required this.cardText,
    required this.cardMuted,
    required this.badgeBg,
    required this.lines,
    required this.bands,
  });

  final String id;
  final String label;
  final String hint;
  final String mode;
  final Color canvasBg;
  final Color cardBg;
  final Color cardBorder;
  final Color cardText;
  final Color cardMuted;
  final Color badgeBg;
  final TreeThemeLines lines;
  final List<TreeThemeBand> bands;
}

const defaultTreeThemeId = 'classic';
const treeThemeStorageKey = 'family_tree_theme';

final treeThemes = <String, TreeTheme>{
  'classic': TreeTheme(
    id: 'classic',
    label: 'Classic',
    hint: 'Soft pastel generations',
    mode: 'light',
    canvasBg: const Color(0xFFF8FAFC),
    cardBg: Colors.white,
    cardBorder: const Color(0xFFE2E8F0),
    cardText: const Color(0xFF0F172A),
    cardMuted: const Color(0xFF64748B),
    badgeBg: const Color(0xF2FFFFFF),
    lines: const TreeThemeLines(
      spouse: Color(0xFFE11D48),
      sibling: Color(0xFF7C3AED),
      parent: Color(0xFF2563EB),
    ),
    bands: const [
      TreeThemeBand(bg: Color(0xFFF3E8FF), ink: Color(0xFF6B21A8)),
      TreeThemeBand(bg: Color(0xFFFCE7F3), ink: Color(0xFF9D174D)),
      TreeThemeBand(bg: Color(0xFFFEF9C3), ink: Color(0xFF854D0E)),
      TreeThemeBand(bg: Color(0xFFDCFCE7), ink: Color(0xFF166534)),
      TreeThemeBand(bg: Color(0xFFDBEAFE), ink: Color(0xFF1D4ED8)),
    ],
  ),
  'ocean': TreeTheme(
    id: 'ocean',
    label: 'Ocean',
    hint: 'Cool blues & teal',
    mode: 'light',
    canvasBg: const Color(0xFFF0F9FF),
    cardBg: Colors.white,
    cardBorder: const Color(0xFFBAE6FD),
    cardText: const Color(0xFF0C4A6E),
    cardMuted: const Color(0xFF0369A1),
    badgeBg: const Color(0xF5FFFFFF),
    lines: const TreeThemeLines(
      spouse: Color(0xFFDB2777),
      sibling: Color(0xFF7C3AED),
      parent: Color(0xFF0284C7),
    ),
    bands: const [
      TreeThemeBand(bg: Color(0xFFE0F2FE), ink: Color(0xFF075985)),
      TreeThemeBand(bg: Color(0xFFCCFBF1), ink: Color(0xFF0F766E)),
      TreeThemeBand(bg: Color(0xFFDBEAFE), ink: Color(0xFF1D4ED8)),
      TreeThemeBand(bg: Color(0xFFE0E7FF), ink: Color(0xFF3730A3)),
      TreeThemeBand(bg: Color(0xFFCFFAFE), ink: Color(0xFF155E75)),
    ],
  ),
  'forest': TreeTheme(
    id: 'forest',
    label: 'Forest',
    hint: 'Greens & earth',
    mode: 'light',
    canvasBg: const Color(0xFFF7FEE7),
    cardBg: Colors.white,
    cardBorder: const Color(0xFFD9F99D),
    cardText: const Color(0xFF14532D),
    cardMuted: const Color(0xFF3F6212),
    badgeBg: const Color(0xF5FFFFFF),
    lines: const TreeThemeLines(
      spouse: Color(0xFFC2410C),
      sibling: Color(0xFF7C3AED),
      parent: Color(0xFF15803D),
    ),
    bands: const [
      TreeThemeBand(bg: Color(0xFFDCFCE7), ink: Color(0xFF166534)),
      TreeThemeBand(bg: Color(0xFFECFCCB), ink: Color(0xFF3F6212)),
      TreeThemeBand(bg: Color(0xFFFEF3C7), ink: Color(0xFF92400E)),
      TreeThemeBand(bg: Color(0xFFD1FAE5), ink: Color(0xFF065F46)),
      TreeThemeBand(bg: Color(0xFFE0E7FF), ink: Color(0xFF3730A3)),
    ],
  ),
  'sunset': TreeTheme(
    id: 'sunset',
    label: 'Sunset',
    hint: 'Warm rose & amber',
    mode: 'light',
    canvasBg: const Color(0xFFFFF7ED),
    cardBg: Colors.white,
    cardBorder: const Color(0xFFFED7AA),
    cardText: const Color(0xFF7C2D12),
    cardMuted: const Color(0xFF9A3412),
    badgeBg: const Color(0xF5FFFFFF),
    lines: const TreeThemeLines(
      spouse: Color(0xFFBE123C),
      sibling: Color(0xFFA21CAF),
      parent: Color(0xFFEA580C),
    ),
    bands: const [
      TreeThemeBand(bg: Color(0xFFFFEDD5), ink: Color(0xFF9A3412)),
      TreeThemeBand(bg: Color(0xFFFCE7F3), ink: Color(0xFF9D174D)),
      TreeThemeBand(bg: Color(0xFFFEF3C7), ink: Color(0xFF854D0E)),
      TreeThemeBand(bg: Color(0xFFFFE4E6), ink: Color(0xFF9F1239)),
      TreeThemeBand(bg: Color(0xFFFDF2F8), ink: Color(0xFF86198F)),
    ],
  ),
  'midnight': TreeTheme(
    id: 'midnight',
    label: 'Midnight',
    hint: 'Dark canvas',
    mode: 'dark',
    canvasBg: const Color(0xFF0F172A),
    cardBg: const Color(0xFF1E293B),
    cardBorder: const Color(0xFF334155),
    cardText: const Color(0xFFF8FAFC),
    cardMuted: const Color(0xFF94A3B8),
    badgeBg: const Color(0xF21E293B),
    lines: const TreeThemeLines(
      spouse: Color(0xFFFB7185),
      sibling: Color(0xFFC4B5FD),
      parent: Color(0xFF38BDF8),
    ),
    bands: const [
      TreeThemeBand(bg: Color(0xFF312E81), ink: Color(0xFFC7D2FE)),
      TreeThemeBand(bg: Color(0xFF4C1D95), ink: Color(0xFFE9D5FF)),
      TreeThemeBand(bg: Color(0xFF134E4A), ink: Color(0xFF99F6E4)),
      TreeThemeBand(bg: Color(0xFF1E3A5F), ink: Color(0xFFBAE6FD)),
      TreeThemeBand(bg: Color(0xFF3B0764), ink: Color(0xFFF5D0FE)),
    ],
  ),
};

TreeTheme getTreeTheme(String? id) =>
    treeThemes[id] ?? treeThemes[defaultTreeThemeId]!;

Future<String> loadStoredTreeThemeId() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(treeThemeStorageKey);
    if (id != null && treeThemes.containsKey(id)) return id;
  } catch (_) {}
  return defaultTreeThemeId;
}

Future<void> storeTreeThemeId(String id) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(treeThemeStorageKey, id);
  } catch (_) {}
}
