import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/ft_page.dart';
import '../../../../core/widgets/responsive.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../family/data/family_api_service.dart';

class AdminFamiliesScreen extends StatefulWidget {
  const AdminFamiliesScreen({super.key});

  @override
  State<AdminFamiliesScreen> createState() => _AdminFamiliesScreenState();
}

class _AdminFamiliesScreenState extends State<AdminFamiliesScreen> {
  List<Map<String, dynamic>> _families = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (!auth.hasPermission('family.read') &&
        !(auth.user?.isSuperAdmin ?? false)) {
      setState(() {
        _loading = false;
        _error = 'You need family.read permission';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await context.read<FamilyApiService>().listAllFamilies();
      final data = res.data;
      List list = const [];
      if (data is Map && data['families'] is List) {
        list = data['families'] as List;
      } else if (data is List) {
        list = data;
      }
      _families = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FtPage(
      title: 'All Families',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: context.pagePadding,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ..._families.map((f) {
                    final id = (f['id'] ?? '').toString();
                    final active = f['is_active'] != false && f['isActive'] != false;
                    return SwitchListTile(
                      title: Text(f['name']?.toString() ?? 'Family'),
                      subtitle: Text(id),
                      value: active,
                      onChanged: (v) async {
                        try {
                          await context
                              .read<FamilyApiService>()
                              .setFamilyStatus(id, v);
                          _load();
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      },
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
