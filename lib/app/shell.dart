import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/auth/presentation/widgets/set_initial_password_dialog.dart';
import '../features/family/presentation/providers/family_providers.dart';
import '../features/settings/presentation/providers/theme_settings_provider.dart';
import 'router.dart';
import 'theme.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FamilySessionProvider>().loadMine();
      final auth = context.read<AuthProvider>();
      if (auth.user?.mustChangePassword == true) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const SetInitialPasswordDialog(),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final family = context.watch<FamilySessionProvider>();
    context.watch<ThemeSettingsProvider>();
    final wide = MediaQuery.sizeOf(context).width >= 840;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
          return;
        }
        final loc = GoRouterState.of(context).matchedLocation;
        if (loc != '/dashboard') {
          context.go('/dashboard');
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppTheme.shellBg,
        drawer: wide
            ? null
            : _AppDrawer(
                familyName: family.current?.name ?? 'Family Tree',
                userName: auth.user?.name ?? '',
                showAdminFamilies: auth.hasPermission('family.read'),
                onLogout: () async {
                  await auth.logout();
                  if (context.mounted) context.go('/login');
                },
              ),
        body: Row(
          children: [
            if (wide)
              SizedBox(
                width: 240,
                child: Material(
                  elevation: 0,
                  color: AppTheme.drawerBg,
                  child: _AppDrawer(
                    familyName: family.current?.name ?? 'Family Tree',
                    userName: auth.user?.name ?? '',
                    showAdminFamilies: auth.hasPermission('family.read'),
                    permanent: true,
                    onLogout: () async {
                      await auth.logout();
                      if (context.mounted) context.go('/login');
                    },
                  ),
                ),
              ),
            if (wide) VerticalDivider(width: 1, color: AppTheme.borderSoft),
            Expanded(child: widget.child),
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
    this.permanent = false,
  });

  final String familyName;
  final String userName;
  final bool showAdminFamilies;
  final VoidCallback onLogout;
  final bool permanent;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              ListTile(
                title: Text(familyName, style: AppTheme.display(size: 20)),
                subtitle: Text(
                  userName,
                  style: AppTheme.body(size: 14, color: AppTheme.muted),
                ),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.forest.withValues(alpha: 0.16),
                  child: Icon(Icons.park, color: AppTheme.forest, size: 24),
                ),
              ),
              const Divider(),
              _item(context, Icons.dashboard, 'Dashboard', '/dashboard'),
              _item(context, Icons.groups, 'Members', '/family/members'),
              _item(context, Icons.account_tree, 'Tree', '/family/tree'),
              _item(context, Icons.photo_library, 'Media', '/family/media'),
              _item(context, Icons.person, 'Profile', '/family/profile'),
              _item(context, Icons.map_outlined, 'Map', '/family/map'),
              _item(context, Icons.event, 'Events', '/family/events'),
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
      width: MediaQuery.sizeOf(context).width * 0.72,
      backgroundColor: AppTheme.drawerBg,
      child: SafeArea(child: content),
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String label,
    String path,
  ) {
    final loc = GoRouterState.of(context).matchedLocation;
    final active =
        loc == path || (path != '/dashboard' && loc.startsWith(path));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selected: active,
        selectedTileColor: AppTheme.forest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Icon(
          icon,
          size: 22,
          color: active ? Colors.white : AppTheme.muted,
        ),
        title: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.body(
            size: 16,
            weight: FontWeight.w700,
            color: active ? Colors.white : AppTheme.inkSoft,
          ),
        ),
        onTap: () {
          if (!permanent) Navigator.pop(context);
          context.openShell(path);
        },
      ),
    );
  }
}
