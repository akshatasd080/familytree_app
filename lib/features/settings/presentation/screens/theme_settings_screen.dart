import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/ft_page.dart';
import '../providers/theme_settings_provider.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeSettingsProvider>();
    final accent = theme.accent;

    return FtPage(
      title: 'Theme Settings',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _SettingsCard(
            accent: accent,
            title: 'Appearance',
            child: _AppearanceToggle(
              isDark: theme.isDark,
              accent: accent,
              onChanged: theme.setDark,
            ),
          ),
          const SizedBox(height: 14),
          _SettingsCard(
            accent: accent,
            title: 'Primary Color',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final c in ThemeSettingsProvider.presets)
                      _ColorDot(
                        color: c,
                        selected: c.toARGB32() == accent.toARGB32(),
                        onTap: () => theme.setAccent(c),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _pickCustomColor(context, theme),
                  icon: Icon(Icons.palette_outlined, color: accent),
                  label: Text(
                    'Pick Custom Color',
                    style: AppTheme.body(
                      weight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent.withValues(alpha: 0.55)),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SettingsCard(
            accent: accent,
            title: 'Reset',
            child: OutlinedButton.icon(
              onPressed: theme.reset,
              icon: Icon(Icons.refresh_rounded, color: accent),
              label: Text(
                'Reset to Defaults',
                style: AppTheme.body(
                  weight: FontWeight.w700,
                  color: accent,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent.withValues(alpha: 0.55)),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomColor(
    BuildContext context,
    ThemeSettingsProvider theme,
  ) async {
    var draft = theme.accent;
    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final hsv = HSVColor.fromColor(draft);
            return AlertDialog(
              backgroundColor: AppTheme.card,
              title: Text('Custom color', style: AppTheme.display(size: 20)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 56,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: draft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderSoft),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Hue', style: AppTheme.body(size: 12, color: AppTheme.muted)),
                  Slider(
                    value: hsv.hue,
                    max: 360,
                    activeColor: draft,
                    onChanged: (v) {
                      setLocal(() {
                        draft = hsv.withHue(v).toColor();
                      });
                    },
                  ),
                  Text('Saturation',
                      style: AppTheme.body(size: 12, color: AppTheme.muted)),
                  Slider(
                    value: hsv.saturation,
                    activeColor: draft,
                    onChanged: (v) {
                      setLocal(() {
                        draft = hsv.withSaturation(v).toColor();
                      });
                    },
                  ),
                  Text('Brightness',
                      style: AppTheme.body(size: 12, color: AppTheme.muted)),
                  Slider(
                    value: hsv.value,
                    activeColor: draft,
                    onChanged: (v) {
                      setLocal(() {
                        draft = hsv.withValue(v).toColor();
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, draft),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
    if (picked != null) await theme.setAccent(picked);
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.accent,
    required this.title,
    required this.child,
  });

  final Color accent;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTheme.body(size: 15, weight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _AppearanceToggle extends StatelessWidget {
  const _AppearanceToggle({
    required this.isDark,
    required this.accent,
    required this.onChanged,
  });

  final bool isDark;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.tabTrack,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Seg(
              selected: !isDark,
              accent: accent,
              icon: Icons.wb_sunny_outlined,
              label: 'Light Mode',
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _Seg(
              selected: isDark,
              accent: accent,
              icon: Icons.dark_mode_outlined,
              label: 'Dark Mode',
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({
    required this.selected,
    required this.accent,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final Color accent;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accent : Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : AppTheme.ink,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body(
                    size: 13,
                    weight: FontWeight.w700,
                    color: selected ? Colors.white : AppTheme.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected ? AppTheme.ink : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}
