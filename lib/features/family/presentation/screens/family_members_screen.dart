import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/ft_page.dart';
import '../../../../core/widgets/responsive.dart';
import '../../data/family_api_service.dart';
import '../../data/models/family_models.dart';
import '../providers/family_providers.dart';
import '../widgets/member_preview_sheet.dart';

const _relationships = [
  'Father',
  'Mother',
  'Son',
  'Daughter',
  'Brother',
  'Sister',
  'Husband',
  'Wife',
  'Spouse',
  'Uncle',
  'Aunt',
  'Relative',
];

class FamilyMembersScreen extends StatefulWidget {
  const FamilyMembersScreen({super.key});

  @override
  State<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends State<FamilyMembersScreen> {
  List<FamilyMember> _members = const [];
  List<Map<String, dynamic>> _joinRequests = const [];
  List<Map<String, dynamic>> _pendingInvites = const [];
  List<Map<String, dynamic>> _myInvites = const [];
  final _search = TextEditingController();
  String _query = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<FamilyMember> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _members;
    return _members.where((m) {
      final hay = [
        m.name,
        m.relationship,
        m.phone,
        m.email,
        m.location,
        m.status,
      ].whereType<String>().join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  Future<void> _load() async {
    final session = context.read<FamilySessionProvider>();
    if (session.familyId == null) await session.loadMine();
    if (!mounted) return;
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
      List pending = const [];
      if (mdata is Map) {
        if (mdata['members'] is List) list = mdata['members'] as List;
        if (mdata['pendingInvitations'] is List) {
          pending = mdata['pendingInvitations'] as List;
        }
      } else if (mdata is List) {
        list = mdata;
      }
      _members = list
          .whereType<Map>()
          .map((e) => FamilyMember.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _pendingInvites = pending
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
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

      try {
        final mine = await api.listMyInvitations();
        final idata = mine.data;
        List ilist = const [];
        if (idata is Map && idata['invitations'] is List) {
          ilist = idata['invitations'] as List;
        } else if (idata is List) {
          ilist = idata;
        }
        _myInvites = ilist
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } catch (_) {
        _myInvites = const [];
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openPreview(FamilyMember member) async {
    final familyId = context.read<FamilySessionProvider>().familyId;
    if (familyId == null) return;
    await showMemberPreviewSheet(
      context: context,
      member: member,
      familyId: familyId,
      onChanged: _load,
    );
  }

  Future<void> _addMember() async {
    final familyId = context.read<FamilySessionProvider>().familyId;
    if (familyId == null) return;
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final notes = TextEditingController();
    final location = TextEditingController();
    var relationship = 'Relative';
    var isAlive = true;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppTheme.canvas,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add member', style: AppTheme.display(size: 20)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Living'),
                      selected: isAlive,
                      onSelected: (_) => setLocal(() => isAlive = true),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Memorial'),
                      selected: !isAlive,
                      onSelected: (_) => setLocal(() => isAlive = false),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: relationship,
                  decoration:
                      const InputDecoration(labelText: 'Relationship'),
                  items: [
                    for (final r in _relationships)
                      DropdownMenuItem(value: r, child: Text(r)),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => relationship = v);
                  },
                ),
                if (isAlive) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    decoration: const InputDecoration(
                      labelText: 'Mobile (+91)',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: email,
                    decoration: const InputDecoration(
                      labelText: 'Email (optional)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: location,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      hintText: 'City, State',
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: notes,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(isAlive ? 'Send invite' : 'Save memorial'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;

    try {
      final api = context.read<FamilyApiService>();
      if (!isAlive) {
        await api.addFamilyMemberWithOtp(familyId, {
          'name': name.text.trim(),
          'relationship': relationship,
          'isAlive': false,
          'profileInfo': {
            'isAlive': false,
            if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
          },
        });
      } else {
        final p = phone.text.replaceAll(RegExp(r'\D'), '');
        if (!RegExp(r'^[6-9]\d{9}$').hasMatch(p)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enter a valid 10-digit mobile number'),
            ),
          );
          return;
        }
        await api.addFamilyMemberWithOtp(familyId, {
          'name': name.text.trim(),
          'phone': p,
          if (email.text.trim().isNotEmpty)
            'email': email.text.trim().toLowerCase(),
          'relationship': relationship,
          'profileInfo': {
            'phone': p,
            if (location.text.trim().isNotEmpty)
              'location': location.text.trim(),
            if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
            'isAlive': true,
          },
        });
      }
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount =
        _members.where((m) => (m.status ?? '').toUpperCase() != 'PENDING').length;

    return FtPage(
      title: 'Members',
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMember,
        backgroundColor: AppTheme.forest,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add'),
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
                  TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search members…',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: AppTheme.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatChip(
                        label: 'Active',
                        value: '$activeCount',
                        color: const Color(0xFF059669),
                      ),
                      _StatChip(
                        label: 'Invites',
                        value: '${_pendingInvites.length}',
                        color: const Color(0xFFEA580C),
                      ),
                      _StatChip(
                        label: 'Join requests',
                        value: '${_joinRequests.length}',
                        color: const Color(0xFF0284C7),
                      ),
                    ],
                  ),
                  if (_myInvites.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Invitations for you',
                      style: AppTheme.body(weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    ..._myInvites.map((inv) {
                      final id = (inv['id'] ?? '').toString();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.amber50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.amber200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${inv['invitedBy'] ?? 'Someone'} invited you to ${inv['familyName'] ?? 'a family'} as ${inv['relationship'] ?? 'member'}',
                            ),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    await context
                                        .read<FamilyApiService>()
                                        .acceptInvitation(id);
                                    _load();
                                  },
                                  child: const Text('Accept'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    await context
                                        .read<FamilyApiService>()
                                        .rejectInvitation(id);
                                    _load();
                                  },
                                  child: const Text('Reject'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  if (_joinRequests.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Join requests',
                      style: AppTheme.body(weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    ..._joinRequests.map((r) {
                      final id = (r['id'] ?? '').toString();
                      final familyId =
                          context.read<FamilySessionProvider>().familyId!;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.amber200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r['name']?.toString() ?? 'Request',
                              style: AppTheme.body(weight: FontWeight.w800),
                            ),
                            Text(
                              '${r['email'] ?? ''} ${r['phone'] ?? ''}'.trim(),
                              style: AppTheme.body(
                                size: 12,
                                color: AppTheme.muted,
                              ),
                            ),
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
                      );
                    }),
                  ],
                  if (_pendingInvites.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Pending invitations',
                      style: AppTheme.body(weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    ..._pendingInvites.map((inv) {
                      final id = (inv['id'] ?? '').toString();
                      return Card(
                        child: ListTile(
                          title: Text(inv['name']?.toString() ?? 'Invite'),
                          subtitle: Text(
                            [
                              inv['relationship'],
                              inv['phone'],
                              inv['email'],
                            ]
                                .where((e) =>
                                    e != null && e.toString().isNotEmpty)
                                .join(' · '),
                          ),
                          trailing: Wrap(
                            children: [
                              IconButton(
                                tooltip: 'Resend OTP',
                                onPressed: () async {
                                  await context
                                      .read<FamilyApiService>()
                                      .resendInviteOtp(id);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('OTP resent'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.sms_outlined),
                              ),
                              IconButton(
                                tooltip: 'Cancel',
                                onPressed: () async {
                                  await context
                                      .read<FamilyApiService>()
                                      .cancelInvitation(id);
                                  _load();
                                },
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'People',
                          style: AppTheme.body(weight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        '${_filtered.length}',
                        style: AppTheme.body(
                          size: 12,
                          weight: FontWeight.w700,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._filtered.map(
                    (m) => _MemberCard(
                      member: m,
                      onTap: () => _openPreview(m),
                    ),
                  ),
                  const SizedBox(height: 88),
                ],
              ),
            ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$label · $value',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: color,
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member, required this.onTap});

  final FamilyMember member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = mediaUrl(member.avatar);
    final phone = (member.phone ?? '').trim();
    final email = member.displayEmail;
    final rel = member.relationship ?? 'Family';
    final status = (member.status ?? 'ACTIVE').toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderSoft),
            ),
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.forest.withValues(alpha: 0.12),
                  backgroundImage: url != null ? NetworkImage(url) : null,
                  child: url == null
                      ? Text(
                          member.name.isNotEmpty
                              ? member.name[0].toUpperCase()
                              : '?',
                          style: AppTheme.body(
                            weight: FontWeight.w800,
                            color: AppTheme.forest,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              member.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.body(
                                weight: FontWeight.w800,
                                size: 15,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$rel · $status',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(
                          size: 12,
                          color: AppTheme.muted,
                          weight: FontWeight.w600,
                        ),
                      ),
                      if (phone.isNotEmpty || email.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (phone.isNotEmpty) phone,
                            if (email.isNotEmpty) email,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.body(
                            size: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
