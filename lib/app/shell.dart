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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FamilySessionProvider>().loadMine();
      context.read<FamilyNoticesUnreadProvider>().refresh();
      final auth = context.read<AuthProvider>();
      if (auth.user?.mustChangePassword == true) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const SetInitialPasswordDialog(),
        );
      }
      _unreadTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) {
          if (!mounted) return;
          context.read<FamilyNoticesUnreadProvider>().refresh();
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
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
          return;
        }
        if (loc != '/dashboard') {
          context.go('/dashboard');
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
                onLogout: () async {
                  await auth.logout();
                  if (context.mounted) context.go('/login');
                },
              ),
        body: Row(
          children: [
            if (wide)
              SizedBox(
                width: 252,
                child: Material(
                  elevation: 0,
                  color: AppTheme.drawerBg,
                  child: _AppDrawer(
                    familyName: family.current?.name ?? 'Family Tree',
                    userName: auth.user?.name ?? '',
                    showAdminFamilies: auth.hasPermission('family.read'),
                    messagesUnread: noticesUnread.unreadCount,
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
    this.permanent = false,
  });

  final String familyName;
  final String userName;
  final bool showAdminFamilies;
  final VoidCallback onLogout;
  final int messagesUnread;
  final bool permanent;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    const FtBrandMark(size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            familyName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.display(size: 18),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.body(
                              size: 13,
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'EXPLORE',
                  style: AppTheme.body(
                    size: 11,
                    weight: FontWeight.w700,
                    color: AppTheme.muted,
                  ),
                ),
              ),
              _item(context, Icons.dashboard_outlined, 'Home', '/dashboard'),
              _item(context, Icons.account_tree_outlined, 'Tree', '/family/tree'),
              _item(
                context,
                Icons.auto_awesome_mosaic_outlined,
                'Feed',
                '/family/media',
              ),
              _item(
                context,
                Icons.chat_bubble_outline_rounded,
                'Chat',
                '/family/chat',
              ),
              _item(
                context,
                Icons.campaign_outlined,
                'Notices',
                '/family/messages',
                badge: messagesUnread,
              ),
              _item(context, Icons.person_outline, 'Profile', '/family/profile'),
              _item(context, Icons.groups_outlined, 'Members', '/family/members'),
              _item(context, Icons.map_outlined, 'Map', '/family/map'),
              _item(context, Icons.event_outlined, 'Events', '/family/events'),
              _item(
                context,
                Icons.admin_panel_settings_outlined,
                'Family Admin',
                '/family/admin',
              ),
              _item(
                context,
                Icons.privacy_tip_outlined,
                'Privacy',
                '/family/privacy',
              ),
              if (showAdminFamilies)
                _item(
                  context,
                  Icons.diversity_3,
                  'All Families',
                  '/admin/families',
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        _item(context, Icons.settings_outlined, 'Settings', '/settings'),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.redAccent, size: 22),
          title: Text(
            'Logout',
            style: AppTheme.body(
              size: 16,
              weight: FontWeight.w700,
              color: Colors.redAccent,
            ),
          ),
          onTap: () {
            if (!permanent) Navigator.pop(context);
            onLogout();
          },
        ),
        const SizedBox(height: 8),
      ],
    );

    if (permanent) {
      return SafeArea(child: content);
    }
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.78,
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
    final active =
        loc == path || (path != '/dashboard' && loc.startsWith(path));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selected: active,
        selectedTileColor: AppTheme.forest.withValues(alpha: 0.14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Icon(
          icon,
          size: 22,
          color: active ? AppTheme.forest : AppTheme.muted,
        ),
        title: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.body(
            size: 15,
            weight: FontWeight.w700,
            color: active ? AppTheme.forest : AppTheme.inkSoft,
          ),
        ),
        trailing: badge > 0
            ? Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppTheme.emerald600,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () {
          final router = GoRouter.of(context);
          router.go(path);
          if (!permanent && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }
}
