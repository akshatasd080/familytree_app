import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Page chrome for routes inside [AppShell] — no nested Scaffold,
/// so bottom-nav / FAB / body never fight each other.
class FtPage extends StatelessWidget {
  const FtPage({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottomBar,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final canOpenDrawer = !wide && Scaffold.maybeOf(context)?.hasDrawer == true;

    return Material(
      color: AppTheme.shellBg,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: EdgeInsets.fromLTRB(canOpenDrawer ? 2 : 12, 0, 6, 0),
                child: Row(
                  children: [
                    if (canOpenDrawer)
                      IconButton(
                        tooltip: 'Menu',
                        onPressed: () => Scaffold.of(context).openDrawer(),
                        icon: Icon(Icons.menu_rounded, color: AppTheme.ink),
                      ),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.display(size: 20),
                      ),
                    ),
                    ...?actions,
                  ],
                ),
              ),
            ),
          ),
          Divider(height: 1, color: AppTheme.borderSoft),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: body),
                if (floatingActionButton != null)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: floatingActionButton!,
                  ),
              ],
            ),
          ),
          if (bottomBar != null) bottomBar!,
        ],
      ),
    );
  }
}
