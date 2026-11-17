import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/ft_page.dart';
import '../../../../core/widgets/responsive.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/family_api_service.dart';
import '../../data/models/family_models.dart';
import '../../domain/family_graph_layout.dart';
import '../providers/family_providers.dart';
import '../widgets/member_preview_sheet.dart';
import '../widgets/state_city_select.dart';

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
  List<Map<String, dynamic>> _linkRequests = const [];
  List<Map<String, dynamic>> _linkResults = const [];
  Map<String, String> _displayRoles = const {};
  final _search = TextEditingController();
  final _linkQuery = TextEditingController();
  String _query = '';
  bool _loading = true;
  bool _linkBusy = false;
  String? _error;

  bool get _isAdmin =>
      _computeIsAdmin(context.read<FamilySessionProvider>());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    _linkQuery.dispose();
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
      final parsedMembers = list
          .whereType<Map>()
          .map((e) => FamilyMember.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final parsedPending = pending
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      var joinRequests = const <Map<String, dynamic>>[];
      try {
        final joins = await api.listFamilyJoinRequests(familyId);
        final jdata = joins.data;
        List jlist = const [];
        if (jdata is Map && jdata['requests'] is List) {
          jlist = jdata['requests'] as List;
        } else if (jdata is List) {
          jlist = jdata;
        }
        joinRequests = jlist
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } catch (_) {}

      var myInvites = const <Map<String, dynamic>>[];
      try {
        final mine = await api.listMyInvitations();
        final idata = mine.data;
        List ilist = const [];
        if (idata is Map && idata['invitations'] is List) {
          ilist = idata['invitations'] as List;
        } else if (idata is List) {
          ilist = idata;
        }
        myInvites = ilist
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } catch (_) {}

      var linkRequests = const <Map<String, dynamic>>[];
      final isAdmin = _computeIsAdmin(session);
      if (isAdmin) {
        try {
          final links = await api.listFamilyLinkRequests(familyId);
          final ldata = links.data;
          List llist = const [];
          if (ldata is Map && ldata['requests'] is List) {
            llist = ldata['requests'] as List;
          } else if (ldata is List) {
            llist = ldata;
          }
          linkRequests = llist
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        } catch (_) {}
      }

      // Web parity: ego-relative labels (You / Mother / …)
      var roles = <String, String>{};
      try {
        final treeRes = await api.getFamilyTree(
          familyId,
          params: const {'scope': 'full'},
        );
        final tdata = treeRes.data is Map
            ? Map<String, dynamic>.from(treeRes.data as Map)
            : <String, dynamic>{};
        final tMembers = (tdata['members'] is List)
            ? (tdata['members'] as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : parsedMembers
                .map(
                  (m) => {
                    'id': m.id,
                    'userId': m.userId,
                    'name': m.name,
                    'gender': m.gender,
                    'relationship': m.relationship,
                  },
                )
                .toList();
        final tRels = (tdata['relationships'] is List)
            ? (tdata['relationships'] as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : <Map<String, dynamic>>[];
        final focusId = context.read<AuthProvider>().user?.id;
        final layout = buildFamilyLayout(tMembers, tRels, focusId);
        for (final node in layout.nodes) {
          final id = node['id']?.toString();
          final role = node['treeRole']?.toString();
          if (id != null && role != null && role.trim().isNotEmpty) {
            roles[id] = role.trim();
          }
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _members = parsedMembers;
        _pendingInvites = parsedPending;
        _joinRequests = joinRequests;
        _myInvites = myInvites;
        _linkRequests = linkRequests;
        _displayRoles = roles;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _relationLabel(FamilyMember m) {
    final role = _displayRoles[m.id];
    if (role != null && role.isNotEmpty) return role;
    final myId = context.read<AuthProvider>().user?.id;
    if (myId != null &&
        myId.isNotEmpty &&
        (m.userId ?? '') == myId) {
      return 'You';
    }
    if (m.isSiteCreator) return 'Family owner';
    final rel = (m.relationship ?? '').trim();
    if (rel.isEmpty) return 'Family';
    if (rel.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '') == 'sitecreator') {
      return 'Family owner';
    }
    return rel;
  }

  bool _computeIsAdmin(FamilySessionProvider session) {
    final current = session.current;
    if (current == null) return false;
    if (current.isAdmin || current.isCreator) return true;
    final role = (current.role ?? '').toLowerCase();
    final rel =
        (current.relationship ?? '').toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    return role == 'admin' ||
        role == 'creator' ||
        role == 'owner' ||
        rel == 'sitecreator';
  }

  Future<void> _openPreview(FamilyMember member) async {
    final familyId = context.read<FamilySessionProvider>().familyId;
    if (familyId == null) return;
    await showMemberPreviewSheet(
      context: context,
      member: member,
      familyId: familyId,
      onChanged: _load,
      isAdmin: _isAdmin,
    );
  }

  Future<void> _searchLinkFamilies() async {
    final familyId = context.read<FamilySessionProvider>().familyId;
    final raw = _linkQuery.text.trim();
    if (familyId == null || raw.length < 2) return;
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    }
    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    final looksLikePhone = RegExp(r'^[6-9]\d{9}$').hasMatch(digits);
    final q = looksLikePhone ? digits : raw;
    setState(() => _linkBusy = true);
    try {
      final res = await context
          .read<FamilyApiService>()
          .searchLinkFamilies(familyId, q);
      final data = res.data;
      List list = const [];
      if (data is Map && data['families'] is List) {
        list = data['families'] as List;
      }
      setState(() {
        _linkResults = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
      if (_linkResults.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              looksLikePhone
                  ? 'No family found for that mobile number'
                  : 'No families matched your search',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _linkBusy = false);
    }
  }

  Future<void> _requestLink(String otherFamilyId, String absorb) async {
    final familyId = context.read<FamilySessionProvider>().familyId;
    if (familyId == null) return;
    setState(() => _linkBusy = true);
    try {
      final res = await context.read<FamilyApiService>().createFamilyLinkRequest(
            familyId,
            {'otherFamilyId': otherFamilyId, 'absorb': absorb},
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (res.data is Map ? res.data['message'] : null)?.toString() ??
                'Link request sent',
          ),
        ),
      );
      setState(() {
        _linkResults = const [];
        _linkQuery.clear();
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _linkBusy = false);
    }
  }

  Future<void> _acceptLink(String requestId) async {
    final session = context.read<FamilySessionProvider>();
    final api = context.read<FamilyApiService>();
    final familyId = session.familyId;
    if (familyId == null) return;
    setState(() => _linkBusy = true);
    try {
      final res = await api.acceptFamilyLinkRequest(familyId, requestId);
      if (!mounted) return;
      final nextId = res.data is Map ? res.data['familyId']?.toString() : null;
      await session.loadMine();
      if (!mounted) return;
      if (nextId != null) {
        final match = session.families.where((f) => f.id == nextId);
        if (match.isNotEmpty) session.selectFamily(match.first);
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (res.data is Map ? res.data['message'] : null)?.toString() ??
                'Families linked',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _linkBusy = false);
    }
  }

  Future<void> _declineLink(String requestId) async {
    final familyId = context.read<FamilySessionProvider>().familyId;
    if (familyId == null) return;
    try {
      await context
          .read<FamilyApiService>()
          .declineFamilyLinkRequest(familyId, requestId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _cancelLink(String requestId) async {
    final familyId = context.read<FamilySessionProvider>().familyId;
    if (familyId == null) return;
    try {
      await context
          .read<FamilyApiService>()
          .cancelFamilyLinkRequest(familyId, requestId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  int? _ageFromDob(String dob) {
    final dt = DateTime.tryParse(dob);
    if (dt == null) return null;
    final now = DateTime.now();
    var age = now.year - dt.year;
    if (now.month < dt.month ||
        (now.month == dt.month && now.day < dt.day)) {
      age -= 1;
    }
    return age;
  }

  Future<void> _addMember() async {
    final familyId = context.read<FamilySessionProvider>().familyId;
    if (familyId == null) return;
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final notes = TextEditingController();
    var location = '';
    var relationship = 'Relative';
    var isAlive = true;
    var dob = '';
    var withMobile = true;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppTheme.canvas,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final age = _ageFromDob(dob);
          final isMinor = age != null && age < 18;
          return Padding(
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
                        label: const Text(
                          'Living',
                          style: TextStyle(color: Colors.black),
                        ),
                        labelStyle: const TextStyle(color: Colors.black),
                        selected: isAlive,
                        onSelected: (_) => setLocal(() {
                          isAlive = true;
                        }),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text(
                          'Memorial',
                          style: TextStyle(color: Colors.black),
                        ),
                        labelStyle: const TextStyle(color: Colors.black),
                        selected: !isAlive,
                        onSelected: (_) => setLocal(() {
                          isAlive = false;
                          withMobile = true;
                        }),
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
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date of birth',
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                      helperText:
                          'Required for under-18 members without mobile login.',
                    ),
                    child: InkWell(
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime(now.year - 12),
                          firstDate: DateTime(1900),
                          lastDate: now,
                        );
                        if (picked != null) {
                          setLocal(() {
                            dob =
                                '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                            final nextAge = _ageFromDob(dob);
                            if (nextAge != null && nextAge >= 18) {
                              withMobile = true;
                            }
                          });
                        }
                      },
                      child: Text(
                        dob.isEmpty ? 'Select date (optional)' : dob,
                        style: AppTheme.body(
                          color: dob.isEmpty ? AppTheme.muted : AppTheme.ink,
                        ),
                      ),
                    ),
                  ),
                  if (isAlive) ...[
                    if (isMinor) ...[
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Give mobile login'),
                        subtitle: const Text(
                          'Off = under-18 member with no account',
                        ),
                        value: withMobile,
                        onChanged: (v) => setLocal(() => withMobile = v),
                      ),
                    ],
                    if (!isMinor || withMobile) ...[
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
                    ],
                    const SizedBox(height: 8),
                    StateCitySelect(
                      value: location,
                      onChanged: (v) => setLocal(() => location = v),
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
                      child: Text(
                        !isAlive
                            ? 'Save memorial'
                            : (isMinor && !withMobile)
                                ? 'Save without login'
                                : 'Send invite',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
          if (dob.isNotEmpty) 'dateOfBirth': dob,
          'profileInfo': {
            'isAlive': false,
            if (dob.isNotEmpty) 'dateOfBirth': dob,
            if (location.trim().isNotEmpty) 'location': location.trim(),
            if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
          },
        });
      } else {
        final age = _ageFromDob(dob);
        final isMinor = age != null && age < 18;
        final withoutMobile = isMinor && !withMobile;
        if (withoutMobile) {
          if (dob.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Date of birth is required for under-18 without mobile.',
                ),
              ),
            );
            return;
          }
          await api.addFamilyMemberWithOtp(familyId, {
            'name': name.text.trim(),
            'relationship': relationship,
            'isAlive': true,
            'withoutMobile': true,
            'dateOfBirth': dob,
            'profileInfo': {
              'dateOfBirth': dob,
              'withoutMobile': true,
              'requireLogin': false,
              if (location.trim().isNotEmpty) 'location': location.trim(),
              if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
              'isAlive': true,
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
            if (dob.isNotEmpty) 'dateOfBirth': dob,
            'profileInfo': {
              'phone': p,
              if (dob.isNotEmpty) 'dateOfBirth': dob,
              if (location.trim().isNotEmpty) 'location': location.trim(),
              if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
              'isAlive': true,
            },
          });
        }
      }
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<FamilySessionProvider>();
    final activeCount = _members.length;
    final familyName = session.current?.name ?? 'Your family';

    return FtPage(
      title: 'Members',
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ],
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: _addMember,
              backgroundColor: AppTheme.forest,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.person_add),
              label: const Text('Add'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: context.pagePadding,
          children: [
            // Web-style header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.emerald50,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.emerald100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.groups, size: 14, color: AppTheme.emerald600),
                  const SizedBox(width: 6),
                  Text(
                    familyName,
                    style: AppTheme.body(
                      size: 11,
                      weight: FontWeight.w700,
                      color: const Color(0xFF065F46),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Family Members',
              style: AppTheme.display(size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage people, invites, and join requests for your tree.',
              style: AppTheme.body(size: 13, color: AppTheme.muted),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            if (_isAdmin) ...[
              const SizedBox(height: 16),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Link families',
                      style: AppTheme.body(weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Search a family name, a relative\'s email, or their 10-digit mobile number.',
                      style: AppTheme.body(size: 11, color: AppTheme.muted),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _linkQuery,
                            decoration: const InputDecoration(
                              hintText: 'Family name, email, or mobile',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _linkBusy ? null : _searchLinkFamilies,
                          child: _linkBusy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Text('Search'),
                        ),
                      ],
                    ),
                    ..._linkResults.map((family) {
                      final id = (family['id'] ?? '').toString();
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              family['name']?.toString() ?? 'Family',
                              style: AppTheme.body(weight: FontWeight.w800),
                            ),
                            Text(
                              '${family['memberCount'] ?? ''} people',
                              style: AppTheme.body(
                                size: 11,
                                color: AppTheme.muted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: _linkBusy
                                      ? null
                                      : () => _requestLink(id, 'mine'),
                                  child: const Text('Join their tree'),
                                ),
                                FilledButton(
                                  onPressed: _linkBusy
                                      ? null
                                      : () => _requestLink(id, 'theirs'),
                                  child: const Text('Bring them into mine'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    ..._linkRequests.map((request) {
                      final id = (request['id'] ?? '').toString();
                      return Container(
                        margin: const EdgeInsets.only(top: 8),
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
                              request['summary']?.toString() ??
                                  'Family link request',
                              style: AppTheme.body(weight: FontWeight.w700),
                            ),
                            Text(
                              'Asked by ${request['requesterName'] ?? 'someone'}',
                              style: AppTheme.body(
                                size: 11,
                                color: AppTheme.muted,
                              ),
                            ),
                            Row(
                              children: [
                                if (request['canAccept'] == true) ...[
                                  TextButton(
                                    onPressed: _linkBusy
                                        ? null
                                        : () => _acceptLink(id),
                                    child: const Text('Accept'),
                                  ),
                                  TextButton(
                                    onPressed: () => _declineLink(id),
                                    child: const Text('Decline'),
                                  ),
                                ],
                                if (request['canCancel'] == true)
                                  TextButton(
                                    onPressed: () => _cancelLink(id),
                                    child: const Text('Cancel'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Active',
                    value: '$activeCount',
                    icon: Icons.groups,
                    iconColor: AppTheme.emerald600,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: 'Invites',
                    value: '${_pendingInvites.length}',
                    icon: Icons.mail_outline,
                    iconColor: const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: 'Join requests',
                    value: '${_joinRequests.length}',
                    icon: Icons.person_add_alt_1_outlined,
                    iconColor: const Color(0xFF0284C7),
                  ),
                ),
              ],
            ),
            if (_myInvites.isNotEmpty) ...[
              const SizedBox(height: 14),
              _SectionCard(
                color: AppTheme.amber50,
                borderColor: AppTheme.amber200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invitations for you',
                      style: AppTheme.body(weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    ..._myInvites.map((inv) {
                      final id = (inv['id'] ?? '').toString();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
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
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active members',
                                style: AppTheme.body(weight: FontWeight.w800),
                              ),
                              Text(
                                '${_filtered.length} people · search & preview',
                                style: AppTheme.body(
                                  size: 11,
                                  color: AppTheme.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Search members…',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: AppTheme.shellBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.borderSoft),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.borderSoft),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: Text(
                            _members.isEmpty
                                ? 'No members yet. Tap Add to invite someone.'
                                : 'No members match your search.',
                            textAlign: TextAlign.center,
                            style: AppTheme.body(color: AppTheme.muted),
                          ),
                        ),
                      )
                    else
                      ..._filtered.map(
                        (m) => _MemberCard(
                          member: m,
                          relation: _relationLabel(m),
                          onTap: () => _openPreview(m),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Join requests',
                      style: AppTheme.body(weight: FontWeight.w800),
                    ),
                    Text(
                      'People asking to join',
                      style: AppTheme.body(size: 11, color: AppTheme.muted),
                    ),
                    const SizedBox(height: 8),
                    if (_joinRequests.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No pending join requests.',
                          style: AppTheme.body(color: AppTheme.muted, size: 13),
                        ),
                      )
                    else
                      ..._joinRequests.map((r) {
                        final id = (r['id'] ?? '').toString();
                        final familyId =
                            context.read<FamilySessionProvider>().familyId!;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                          decoration: BoxDecoration(
                            color: AppTheme.shellBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderSoft),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r['name']?.toString() ?? 'Request',
                                style: AppTheme.body(weight: FontWeight.w800),
                              ),
                              Text(
                                '${r['email'] ?? ''} ${r['phone'] ?? ''}'
                                    .trim(),
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
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pending invitations',
                      style: AppTheme.body(weight: FontWeight.w800),
                    ),
                    Text(
                      'Waiting for OTP / accept',
                      style: AppTheme.body(size: 11, color: AppTheme.muted),
                    ),
                    const SizedBox(height: 8),
                    if (_pendingInvites.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No pending invitations.',
                          style: AppTheme.body(color: AppTheme.muted, size: 13),
                        ),
                      )
                    else
                      ..._pendingInvites.map((inv) {
                        final id = (inv['id'] ?? '').toString();
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
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
                ),
              ),
            ],
            const SizedBox(height: 88),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color ?? AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? AppTheme.borderSoft),
      ),
      child: child,
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTheme.body(
              size: 10,
              weight: FontWeight.w700,
              color: AppTheme.muted,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                value,
                style: AppTheme.display(size: 22),
              ),
              const SizedBox(width: 6),
              Icon(icon, size: 16, color: iconColor),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.relation,
    required this.onTap,
  });

  final FamilyMember member;
  final String relation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = mediaUrl(member.avatar);
    final phone = (member.phone ?? '').trim();
    final email = member.displayEmail;
    final location = (member.location ?? '').trim();
    final status = (member.status ?? 'ACTIVE').toUpperCase();
    final emailStatus = (member.emailStatus ?? '').trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.shellBg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderSoft),
            ),
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: member.isAlive
                      ? AppTheme.emerald100
                      : const Color(0xFFFEE2E2),
                  backgroundImage: url != null ? NetworkImage(url) : null,
                  child: url == null
                      ? Text(
                          member.name.isNotEmpty
                              ? member.name[0].toUpperCase()
                              : '?',
                          style: AppTheme.body(
                            weight: FontWeight.w800,
                            color: member.isAlive
                                ? const Color(0xFF065F46)
                                : const Color(0xFFB91C1C),
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
                            Icons.info_outline,
                            size: 18,
                            color: Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        relation,
                        style: AppTheme.body(
                          size: 12,
                          weight: FontWeight.w700,
                          color: AppTheme.forest,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (location.isNotEmpty) location else '—',
                          if (phone.isNotEmpty) phone,
                          if (email.isNotEmpty) email,
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(
                          size: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          _MiniBadge(
                            label: status,
                            color: member.isMembershipActive
                                ? const Color(0xFF059669)
                                : const Color(0xFFB45309),
                          ),
                          if (emailStatus.isNotEmpty)
                            _MiniBadge(
                              label: emailStatus,
                              color: emailStatus.toLowerCase().contains('verif')
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFD97706),
                            ),
                          if (member.isOwner)
                            const _MiniBadge(
                              label: 'Owner',
                              color: Color(0xFF7C3AED),
                            )
                          else if (member.isAdmin)
                            const _MiniBadge(
                              label: 'Admin',
                              color: Color(0xFF0369A1),
                            ),
                          if (!member.isAlive)
                            const _MiniBadge(
                              label: 'Memorial',
                              color: Color(0xFFBE123C),
                            ),
                        ],
                      ),
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

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
