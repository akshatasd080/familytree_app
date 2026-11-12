import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/ft_page.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/family_api_service.dart';
import '../../data/models/family_models.dart';
import '../../domain/ego_tree.dart';
import '../providers/family_providers.dart';
import '../widgets/family_graph_view.dart';

class FamilyTreeScreen extends StatefulWidget {
  const FamilyTreeScreen({super.key});

  @override
  State<FamilyTreeScreen> createState() => _FamilyTreeScreenState();
}

class _FamilyTreeScreenState extends State<FamilyTreeScreen> {
  FamilyTreeData? _tree;
  bool _loading = true;
  String? _error;
  String _scope = 'full';
  FamilyMember? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final session = context.read<FamilySessionProvider>();
    final api = context.read<FamilyApiService>();
    var id = session.familyId;
    if (id == null) {
      await session.loadMine();
      if (!mounted) return;
      id = session.familyId;
    }
    if (id == null) {
      setState(() {
        _loading = false;
        _error = 'No family found for this account';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await api.getFamilyTree(id, params: {'scope': _scope});
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      setState(() => _tree = FamilyTreeData.fromJson(data));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<FamilySessionProvider>();
    return FtPage(
      title: 'Family Tree',
      actions: [
        PopupMenuButton<String>(
          initialValue: _scope,
          onSelected: (v) {
            setState(() => _scope = v);
            _load();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'full', child: Text('Full tree')),
            PopupMenuItem(value: 'near', child: Text('Near circle')),
          ],
          icon: const Icon(Icons.filter_alt_outlined),
        ),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddRelative,
        backgroundColor: AppTheme.forest,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add'),
      ),
      bottomBar: _selected == null
          ? null
          : Material(
              elevation: 6,
              color: Colors.white,
              child: SafeArea(
                top: false,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.forest.withValues(alpha: 0.12),
                    child: Text(
                      _selected!.name.isNotEmpty
                          ? _selected!.name[0].toUpperCase()
                          : '?',
                    ),
                  ),
                  title: Text(
                    _selected!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    _selected!.relationship ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _selected = null),
                  ),
                ),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppTheme.body(color: Colors.red),
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (session.families.length > 1)
                      SizedBox(
                        height: 48,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: session.families.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final f = session.families[i];
                            return ChoiceChip(
                              label: Text(f.name),
                              selected: session.current?.id == f.id,
                              onSelected: (_) {
                                session.selectFamily(f);
                                _load();
                              },
                            );
                          },
                        ),
                      ),
                    Expanded(
                      child: FamilyGraphView(
                        members: _tree?.members ?? const [],
                        relationships: _tree?.relationships ?? const [],
                        focusUserId: resolveDefaultFocusUserId(
                          (_tree?.members ?? const [])
                              .map(
                                (m) => <String, dynamic>{
                                  'id': m.id,
                                  'userId': m.userId,
                                  'user_id': m.userId,
                                  'name': m.name,
                                  'relationship': m.relationship,
                                  'profileInfo': m.profileInfo,
                                  'profile_info': m.profileInfo,
                                },
                              )
                              .toList(),
                          context.read<AuthProvider>().user?.toJson(),
                        ),
                        onMemberTap: (m) => setState(() => _selected = m),
                      ),
                    ),
                  ],
                ),
    );
  }

  Future<void> _showAddRelative() async {
    final familyId = context.read<FamilySessionProvider>().familyId;
    if (familyId == null) return;
    final name = TextEditingController();
    final relation = TextEditingController(text: 'Father');
    final email = TextEditingController();
    final phone = TextEditingController();
    final otp = TextEditingController();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add relative', style: AppTheme.display(size: 18)),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: relation,
                decoration: const InputDecoration(
                  labelText: 'Relationship (Father, Mother, …)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: otp,
                decoration:
                    const InputDecoration(labelText: 'OTP (if required)'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<FamilyApiService>().addFamilyMemberWithOtp(familyId, {
        'name': name.text.trim(),
        'relationship': relation.text.trim(),
        if (phone.text.trim().isNotEmpty) 'phone': phone.text.trim(),
        if (email.text.trim().isNotEmpty) 'email': email.text.trim(),
        if (otp.text.trim().isNotEmpty) 'otp': otp.text.trim(),
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }
}
