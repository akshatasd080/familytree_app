import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../features/settings/presentation/providers/theme_settings_provider.dart';
import 'ft_widgets.dart';

/// Shared professional chrome used by Home / Tree / Chat and family screens.
/// Soft cream-green canvas, logo header, optional scenic backdrop.
class FtBrandedPage extends StatelessWidget {
  const FtBrandedPage({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
    this.floatingActionButton,
    this.scenicBackground = true,
    this.backgroundColor,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool scenicBackground;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeSettingsProvider>();
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final canOpenDrawer = !wide && Scaffold.maybeOf(context)?.hasDrawer == true;
    final bg = backgroundColor ?? AppTheme.shellBg;

    return Material(
      color: bg,
      child: Stack(
        children: [
          if (scenicBackground)
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: AppTheme.isDark ? 0.08 : 0.16,
                  child: Image.asset(
                    'assets/images/tree_canvas_bg.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding:
                      EdgeInsets.fromLTRB(canOpenDrawer ? 2 : 14, 6, 6, 8),
                  child: Row(
                    children: [
                      if (canOpenDrawer)
                        IconButton(
                          tooltip: 'Menu',
                          onPressed: () => Scaffold.of(context).openDrawer(),
                          icon: Icon(Icons.menu_rounded, color: AppTheme.ink),
                        ),
                      const FtBrandMark(size: 36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.display(
                                size: 20,
                                color: AppTheme.forestDark,
                              ),
                            ),
                            if ((subtitle ?? '').trim().isNotEmpty)
                              Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.body(
                                  size: 11,
                                  color: AppTheme.muted,
                                  weight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      ...?actions,
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    body,
                    if (floatingActionButton != null)
                      Positioned(
                        right: 16,
                        bottom: 16 + MediaQuery.paddingOf(context).bottom,
                        child: floatingActionButton!,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Soft content card used across branded screens.
class FtSoftCard extends StatelessWidget {
  const FtSoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeSettingsProvider>();
    final card = Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.card.withValues(alpha: AppTheme.isDark ? 1 : 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderSoft),
        boxShadow: [
          BoxShadow(
            color: AppTheme.forest.withValues(alpha: AppTheme.isDark ? 0.12 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: card,
      ),
    );
  }
}
