import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/network/api_client.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/family/data/family_api_service.dart';
import '../features/family/presentation/providers/family_providers.dart';
import '../features/settings/presentation/providers/theme_settings_provider.dart';
import 'router.dart';
import 'theme.dart';

class FamilyTreeApp extends StatefulWidget {
  const FamilyTreeApp({super.key});

  @override
  State<FamilyTreeApp> createState() => _FamilyTreeAppState();
}

class _FamilyTreeAppState extends State<FamilyTreeApp> {
  late final ApiClient _api;
  late final AuthProvider _auth;
  late final FamilyApiService _familyApi;
  late final FamilySessionProvider _familySession;
  late final ThemeSettingsProvider _theme;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _api = ApiClient(
      onFamilyInactive: () {
        _auth.logout();
      },
    );
    _auth = AuthProvider(_api);
    _familyApi = FamilyApiService(_api);
    _familySession = FamilySessionProvider(_familyApi);
    _theme = ThemeSettingsProvider();
    _router = createRouter(_auth);
    _auth.restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: _api),
        Provider.value(value: _familyApi),
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider.value(value: _familySession),
        ChangeNotifierProvider.value(value: _theme),
      ],
      child: Consumer<ThemeSettingsProvider>(
        builder: (context, theme, _) {
          AppTheme.apply(isDark: theme.isDark, accent: theme.accent);
          return MaterialApp.router(
            title: 'Family Tree',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: theme.themeMode,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
