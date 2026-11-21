import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/widgets/ft_widgets.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/auth/presentation/widgets/set_initial_password_dialog.dart';
import '../features/family/presentation/providers/family_providers.dart';
import '../features/family/presentation/widgets/family_notice_popup.dart';
import '../features/settings/presentation/providers/theme_settings_provider.dart';
import 'theme.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  Timer? _unreadTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final session = context.read<FamilySessionProvider>();
      await session.loadMine();
      if (!mounted) return;
      context.read<FamilyNoticesUnreadProvider>().refresh();
      context.read<FamilyChatUnreadProvider>().refresh(families: session.families);
      final auth = context.read<AuthProvider>();
      if (auth.user?.mustChangePassword == true) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const SetInitialPasswordDialog(),
        );
      }
      _unreadTimer = Timer.periodic(
        const Duration(seconds: 20),
        (_) {
          if (!mounted) return;
          final families = context.read<FamilySessionProvider>().families;
          context.read<FamilyNoticesUnreadProvider>().refresh();
          context.read<FamilyChatUnreadProvider>().refresh(families: families);
        },
      );
    });
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final family = context.watch<FamilySessionProvider>();
    final noticesUnread = context.watch<FamilyNoticesUnreadProvider>();
    final chatUnread = context.watch<FamilyChatUnreadProvider>();
    final themeSettings = context.watch<ThemeSettingsProvider>();
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final mustChange = auth.user?.mustChangePassword == true;
    final loc = GoRouterState.of(context).matchedLocation;
    final themeKey =
        'shell-theme-${themeSettings.isDark}-${themeSettings.accent.toARGB32()}';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Prefer dismissing root-navigator sheets/dialogs (e.g. profile)
        // before shell tab navigation — avoids black stuck screens.
        final rootNav = Navigator.of(context, rootNavigator: true);
        if (rootNav.canPop()) {
          rootNav.pop();
          return;
        }
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
          return;
        }
        if (loc != '/family/media' && loc != '/family/photos') {
          context.go('/family/media');
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppTheme.shellBg,
        drawer: wide
            ? null
            : _AppDrawer(
                familyName: family.current?.name ?? 'Family Tree',
                userName: auth.user?.name ?? '',
                showAdminFamilies: auth.hasPermission('family.read'),
                messagesUnread: noticesUnread.unreadCount,
                chatUnread: chatUnread.unreadCount,
                onLogout: () async {
                  await auth.logout();
                  if (context.mounted) context.go('/login');
                },
              ),
        body: Row(
          children: [
            if (wide)
              SizedBox(
                width: 292,
                child: Material(
                  elevation: 0,
                  color: AppTheme.drawerBg,
                  child: _AppDrawer(
                    familyName: family.current?.name ?? 'Family Tree',
                    userName: auth.user?.name ?? '',
                    showAdminFamilies: auth.hasPermission('family.read'),
                    messagesUnread: noticesUnread.unreadCount,
                    chatUnread: chatUnread.unreadCount,
                    permanent: true,
                    onLogout: () async {
                      await auth.logout();
                      if (context.mounted) context.go('/login');
                    },
                  ),
                ),
              ),
            if (wide) VerticalDivider(width: 1, color: AppTheme.borderSoft),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  KeyedSubtree(
                    key: ValueKey(themeKey),
                    child: widget.child,
                  ),
                  if (!mustChange) const FamilyNoticePopup(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({
    required this.familyName,
    required this.userName,
    required this.showAdminFamilies,
    required this.onLogout,
    this.messagesUnread = 0,
    this.chatUnread = 0,
    this.permanent = false,
  });

  final String familyName;
  final String userName;
  final bool showAdminFamilies;
  final VoidCallback onLogout;
  final int messagesUnread;
  final int chatUnread;
  final bool permanent;

  void _go(BuildContext context, String path) {
    GoRouter.of(context).go(path);
    if (!permanent && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        _DrawerHeader(
          familyName: familyName,
          userName: userName,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFC8E6C9)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.eco_rounded, size: 14, color: AppTheme.forest),
                      const SizedBox(width: 5),
                      Text(
                        'Explore',
                        style: AppTheme.body(
                          size: 11,
                          weight: FontWeight.w800,
                          color: AppTheme.forest,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _item(
                context,
                Icons.auto_awesome_mosaic_rounded,
                'Feed',
                '/family/media',
              ),
              _item(context, Icons.home_rounded, 'Home', '/dashboard'),
              _item(context, Icons.park_rounded, 'Tree', '/family/tree'),
              _item(
                context,
                Icons.chat_bubble_rounded,
                'Chat',
                '/family/chat',
                badge: chatUnread,
              ),
              _item(
                context,
                Icons.chat_bubble_outline_rounded,
                'imp-Messages',
                '/family/messages',
                badge: messagesUnread,
              ),
              _item(context, Icons.person_rounded, 'Profile', '/family/profile'),
              _item(context, Icons.map_rounded, 'Map', '/family/map'),
              _item(context, Icons.event_rounded, 'Events', '/family/events'),
              _item(
                context,
                Icons.admin_panel_settings_rounded,
                'Family Admin',
                '/family/admin',
              ),
              _item(
                context,
                Icons.privacy_tip_rounded,
                'Privacy',
                '/family/privacy',
              ),
              if (showAdminFamilies)
                _item(
                  context,
                  Icons.diversity_3_rounded,
                  'All Families',
                  '/admin/families',
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Column(
            children: [
              _item(
                context,
                Icons.settings_rounded,
                'Settings',
                '/settings',
              ),
              Material(
                color: AppTheme.dangerFill,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    if (!permanent) Navigator.pop(context);
                    onLogout();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.logout_rounded,
                          color: Color(0xFFE11D48),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Logout',
                            style: AppTheme.body(
                              size: 15,
                              weight: FontWeight.w800,
                              color: const Color(0xFFE11D48),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFFE11D48),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 34,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _HillPainter()),
              ),
              Positioned(
                bottom: 6,
                child: Icon(
                  Icons.favorite_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (permanent) {
      return SafeArea(child: content);
    }
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.82,
      backgroundColor: AppTheme.drawerBg,
      child: SafeArea(child: content),
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String label,
    String path, {
    int badge = 0,
  }) {
    final loc = GoRouterState.of(context).matchedLocation;
    final active = loc == path ||
        (path == '/family/media' &&
            (loc == '/family/photos' || loc.startsWith('/family/media'))) ||
        (path != '/dashboard' &&
            path != '/family/media' &&
            loc.startsWith(path));
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: active
            ? AppTheme.forest.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _go(context, path),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: active
                        ? AppTheme.forest.withValues(alpha: 0.16)
                        : AppTheme.softFill,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: active ? AppTheme.forest : AppTheme.forestDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.body(
                      size: 15,
                      weight: FontWeight.w700,
                      color: active ? AppTheme.forest : AppTheme.inkSoft,
                    ),
                  ),
                ),
                if (badge > 0) ...[
                  FtCountBadge(count: badge),
                  const SizedBox(width: 6),
                ],
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: active ? AppTheme.forest : AppTheme.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.familyName,
    required this.userName,
  });

  final String familyName;
  final String userName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/images/drawer_header_bg.jpg'),
          fit: BoxFit.cover,
          opacity: 0.55,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE8F5E9).withValues(alpha: 0.95),
            const Color(0xFFC8E6C9).withValues(alpha: 0.9),
            const Color(0xFFA5D6A7).withValues(alpha: 0.85),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const FtBrandMark(size: 46),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      familyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.display(
                        size: 20,
                        color: AppTheme.forestDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.body(
                              size: 13,
                              weight: FontWeight.w700,
                              color: AppTheme.inkSoft,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: AppTheme.forest,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Our Family… Our Tree… ❤️',
            style: AppTheme.body(
              size: 13,
              color: AppTheme.forestDark,
              weight: FontWeight.w600,
            ).copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

class _HillPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.forest
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.05,
        size.width * 0.5,
        size.height * 0.45,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.85,
        size.width,
        size.height * 0.35,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
