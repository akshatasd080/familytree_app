import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/ft_page.dart';
import '../../../../core/widgets/responsive.dart';
import '../../data/family_api_service.dart';
import '../../data/models/family_models.dart';
import '../providers/family_providers.dart';

class FamilyMembersScreen extends StatefulWidget {
  const FamilyMembersScreen({super.key});

  @override
  State<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends State<FamilyMembersScreen> {
  List<FamilyMember> _members = const [];
  List<Map<String, dynamic>> _joinRequests = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final session = context.read<FamilySessionProvider>();
    if (session.familyId == null) await session.loadMine();
    final familyId = session.familyId;
    if (familyId == null) {
      setState(() {
        _loading = false;
        _error = 'No family';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<FamilyApiService>();
      final membersRes = await api.listFamilyMembers(familyId);
      final mdata = membersRes.data;
      List list = const [];
      if (mdata is Map && mdata['members'] is List) {
        list = mdata['members'] as List;
      } else if (mdata is List) {
        list = mdata;
      }
      _members = list
          .whereType<Map>()
          .map((e) => FamilyMember.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      try {
        final joins = await api.listFamilyJoinRequests(familyId);
        final jdata = joins.data;
        List jlist = const [];
        if (jdata is Map && jdata['requests'] is List) {
          jlist = jdata['requests'] as List;
        } else if (jdata is List) {
          jlist = jdata;
        }
        _joinRequests = jlist
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } catch (_) {
        _joinRequests = const [];
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FtPage(
      title: 'Members',
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: _invite,
        backgroundColor: AppTheme.forest,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: context.pagePadding,
                children: [
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  if (_joinRequests.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'Join requests',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    ..._joinRequests.map((r) {
                      final id = (r['id'] ?? '').toString();
                      final familyId =
                          context.read<FamilySessionProvider>().familyId!;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r['name']?.toString() ?? 'Request',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${r['email'] ?? ''} ${r['phone'] ?? ''}'
                                    .trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () async {
                                      await context
                                          .read<FamilyApiService>()
                                          .approveFamilyJoinRequest(
                                              familyId, id);
                                      _load();
                                    },
                                    icon: const Icon(
                                      Icons.check,
                                      color: Colors.green,
                                      size: 18,
                                    ),
                                    label: const Text('Approve'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () async {
                                      await context
                                          .read<FamilyApiService>()
                                          .rejectFamilyJoinRequest(
                                              familyId, id);
                                      _load();
                                    },
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                    label: const Text('Reject'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'People',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  ..._members.map((m) {
                    final url = mediaUrl(m.avatar);
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.forest.withValues(alpha: 0.12),
                          backgroundImage:
                              url != null ? NetworkImage(url) : null,
                          child: url == null
                              ? Text(
                                  m.name.isNotEmpty
                                      ? m.name[0].toUpperCase()
                                      : '?',
                                )
                              : null,
                        ),
                        title: Text(
                          m.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          [
                            m.relationship,
                            m.status,
                            m.phone,
                            m.email,
                          ]
                              .where((e) =>
                                  e != null && e.toString().isNotEmpty)
                              .join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 88),
                ],
              ),
            ),
    );
  }

  Future<void> _invite() async {
    final familyId = context.read<FamilySessionProvider>().familyId;
    if (familyId == null) return;
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final relationship = TextEditingController(text: 'Relative');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
            TextField(controller: relationship, decoration: const InputDecoration(labelText: 'Relationship')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Invite')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<FamilyApiService>().inviteFamilyMember(familyId, {
        'name': name.text.trim(),
        'email': email.text.trim(),
        'phone': phone.text.trim(),
        'relationship': relationship.text.trim(),
      });
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
