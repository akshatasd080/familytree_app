import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/auth/presentation/widgets/set_initial_password_dialog.dart';
import '../features/family/presentation/providers/family_providers.dart';
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

  int _indexForLocation(String loc) {
    if (loc.startsWith('/family/tree')) return 1;
    if (loc.startsWith('/family/members') ||
        loc.startsWith('/family/invitations')) {
      return 2;
    }
    if (loc.startsWith('/family/media') || loc.startsWith('/family/photos')) {
      return 3;
    }
    if (loc.startsWith('/family/profile') ||
        loc.startsWith('/family/admin') ||
        loc.startsWith('/family/map') ||
        loc.startsWith('/family/events') ||
        loc.startsWith('/family/privacy') ||
        loc.startsWith('/admin/')) {
      return 4;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final index = _indexForLocation(loc);
    final auth = context.watch<AuthProvider>();
    final family = context.watch<FamilySessionProvider>();
    final wide = MediaQuery.sizeOf(context).width >= 840;

    return Scaffold(
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
                color: Colors.white,
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
          if (wide) const VerticalDivider(width: 1),
          Expanded(child: widget.child),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              height: 64,
              selectedIndex: index.clamp(0, 4),
              onDestinationSelected: (i) {
                switch (i) {
                  case 0:
                    context.go('/dashboard');
                  case 1:
                    context.go('/family/tree');
                  case 2:
                    context.go('/family/members');
                  case 3:
                    context.go('/family/media');
                  case 4:
                    _openMore(context, auth);
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard, color: AppTheme.forest),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_tree_outlined),
                  selectedIcon:
                      Icon(Icons.account_tree, color: AppTheme.forest),
                  label: 'Tree',
                ),
                NavigationDestination(
                  icon: Icon(Icons.groups_outlined),
                  selectedIcon: Icon(Icons.groups, color: AppTheme.forest),
                  label: 'Members',
                ),
                NavigationDestination(
                  icon: Icon(Icons.photo_library_outlined),
                  selectedIcon:
                      Icon(Icons.photo_library, color: AppTheme.forest),
                  label: 'Media',
                ),
                NavigationDestination(
                  icon: Icon(Icons.more_horiz),
                  selectedIcon: Icon(Icons.more_horiz, color: AppTheme.forest),
                  label: 'More',
                ),
              ],
            ),
    );
  }

  void _openMore(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Profile'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/family/profile');
                },
              ),
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: const Text('Map'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/family/map');
                },
              ),
              ListTile(
                leading: const Icon(Icons.event),
                title: const Text('Events'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/family/events');
                },
              ),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Family Admin'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/family/admin');
                },
              ),
              if (auth.hasPermission('family.read'))
                ListTile(
                  leading: const Icon(Icons.diversity_3),
                  title: const Text('All Families'),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/admin/families');
                  },
                ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('Logout'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await auth.logout();
                  if (context.mounted) context.go('/login');
                },
              ),
            ],
          ),
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
    final content = ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ListTile(
          title: Text(familyName, style: AppTheme.display(size: 18)),
          subtitle: Text(
            userName,
            style: AppTheme.body(size: 12, color: AppTheme.muted),
          ),
          leading: const CircleAvatar(
            backgroundColor: AppTheme.emerald100,
            child: Icon(Icons.park, color: AppTheme.forest),
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
          _item(context, Icons.diversity_3, 'All Families', '/admin/families'),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.redAccent),
          title: Text('Logout', style: AppTheme.body(weight: FontWeight.w600)),
          onTap: () {
            if (!permanent) Navigator.pop(context);
            onLogout();
          },
        ),
      ],
    );

    if (permanent) {
      return SafeArea(child: content);
    }
    return Drawer(backgroundColor: Colors.white, child: SafeArea(child: content));
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        selected: active,
        selectedTileColor: AppTheme.forest,
        leading: Icon(
          icon,
          size: 18,
          color: active ? Colors.white : AppTheme.muted,
        ),
        title: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.body(
            size: 13,
            weight: FontWeight.w600,
            color: active ? Colors.white : const Color(0xFF475569),
          ),
        ),
        onTap: () {
          if (!permanent) Navigator.pop(context);
          context.go(path);
        },
      ),
    );
  }
}
