import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/family/presentation/screens/family_admin_screen.dart';
import '../features/family/presentation/screens/family_events_screen.dart';
import '../features/family/presentation/screens/family_join_screen.dart';
import '../features/family/presentation/screens/family_map_screen.dart';
import '../features/family/presentation/screens/family_media_screen.dart';
import '../features/family/presentation/screens/family_members_screen.dart';
import '../features/family/presentation/screens/family_privacy_screen.dart';
import '../features/family/presentation/screens/family_profile_screen.dart';
import '../features/family/presentation/screens/family_register_screen.dart';
import '../features/family/presentation/screens/family_tree_screen.dart';
import '../features/family/presentation/screens/family_verify_otp_screen.dart';
import '../features/home/presentation/screens/dashboard_screen.dart';
import '../features/home/presentation/screens/public_home_screen.dart';
import '../features/admin/presentation/screens/admin_families_screen.dart';
import '../features/settings/presentation/screens/theme_settings_screen.dart';
import 'shell.dart';

GoRouter createRouter(AuthProvider auth) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final publicPaths = {
        '/',
        '/login',
        '/family/register',
        '/family/verify-otp',
        '/family/join',
      };
      final isPublic = publicPaths.contains(loc);
      if (!auth.initialized) return null;
      if (!auth.isAuthenticated && !isPublic) return '/login';
      if (auth.isAuthenticated &&
          (loc == '/login' || loc == '/' || loc == '/family/register')) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const PublicHomeScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/family/register',
        builder: (_, __) => const FamilyRegisterScreen(),
      ),
      GoRoute(
        path: '/family/verify-otp',
        builder: (_, state) {
          final extra = state.extra;
          return FamilyVerifyOtpScreen(
            extras: extra is Map<String, dynamic> ? extra : const {},
          );
        },
      ),
      GoRoute(
        path: '/family/join',
        builder: (_, __) => const FamilyJoinScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/family/members',
            builder: (_, __) => const FamilyMembersScreen(),
          ),
          GoRoute(
            path: '/family/invitations',
            builder: (_, __) => const FamilyMembersScreen(),
          ),
          GoRoute(
            path: '/family/tree',
            builder: (_, __) => const FamilyTreeScreen(),
          ),
          GoRoute(
            path: '/family/media',
            builder: (_, __) => const FamilyMediaScreen(),
          ),
          GoRoute(
            path: '/family/photos',
            builder: (_, __) => const FamilyMediaScreen(),
          ),
          GoRoute(
            path: '/family/profile',
            builder: (_, __) => const FamilyProfileScreen(),
          ),
          GoRoute(
            path: '/family/map',
            builder: (_, __) => const FamilyMapScreen(),
          ),
          GoRoute(
            path: '/family/events',
            builder: (_, __) => const FamilyEventsScreen(),
          ),
          GoRoute(
            path: '/family/admin',
            builder: (_, __) => const FamilyAdminScreen(),
          ),
          GoRoute(
            path: '/family/privacy',
            builder: (_, __) => const FamilyPrivacyScreen(),
          ),
          GoRoute(
            path: '/admin/families',
            builder: (_, __) => const AdminFamiliesScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const ThemeSettingsScreen(),
          ),
        ],
      ),
    ],
  );
}

extension AuthRouterX on BuildContext {
  AuthProvider get auth => read<AuthProvider>();
}

/// In-app navigation that keeps a back stack (phone back → previous screen).
extension ShellNavX on BuildContext {
  void openShell(String path) {
    final loc = GoRouterState.of(this).matchedLocation;
    if (loc == path) return;
    // Dashboard is the root — clear stack so back from home can exit.
    if (path == '/dashboard') {
      go('/dashboard');
      return;
    }
    push(path);
  }
}
