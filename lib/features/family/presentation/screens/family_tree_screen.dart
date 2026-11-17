import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/ft_page.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/family_api_service.dart';
import '../../data/models/family_models.dart';
import '../../domain/ego_tree.dart';
import '../../domain/family_graph_layout.dart';
import '../providers/family_providers.dart';
import '../widgets/add_relative_radial.dart';
import '../widgets/add_relative_sheet.dart';
import '../widgets/family_chat_panel.dart';
import '../widgets/family_graph_view.dart';
import '../widgets/tree_member_profile_sheet.dart';

const _maxAncestorDepth = 12;

class FamilyTreeScreen extends StatefulWidget {
  const FamilyTreeScreen({super.key});

  @override
  State<FamilyTreeScreen> createState() => _FamilyTreeScreenState();
}

class _FamilyTreeScreenState extends State<FamilyTreeScreen> {
  final _graphKey = GlobalKey<FamilyGraphViewState>();
  final _search = TextEditingController();

  FamilyTreeData? _tree;
  bool _loading = true;
  bool _downloading = false;
  String? _error;
  String _scope = 'full';
  String _viewMode = 'diagram'; // diagram | generations
  String _generationFilter = 'all';
  int _ancestorDepth = 1;
  FamilyMember? _selected;
  FamilyMember? _radialPerson;
  String? _role;
  String? _focusOverrideId;
  String? _chatPeerUserId;
  int _chatDockNonce = 0;
  bool _searchOpen = false;

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

  List<MemberMap> get _memberMaps => (_tree?.members ?? const <FamilyMember>[])
      .map(_memberToMap)
      .toList();

  String? get _myFocusId {
    final user = context.read<AuthProvider>().user;
    return resolveDefaultFocusUserId(_memberMaps, user?.toJson());
  }

  String? get _focusId => _focusOverrideId ?? _myFocusId;

  bool get _isAdmin => (_role ?? '').toLowerCase() == 'admin';

  bool get _viewingSelf {
    final mine = _myFocusId;
    final focus = _focusId;
    if (mine == null || focus == null) return true;
    return mine == focus;
  }

  bool get _canAddOnTree {
    if (_isAdmin) return true;
    if ((_role ?? '').toLowerCase() == 'viewer') return false;
    return _scope == 'near' && _viewingSelf;
  }

  GenerationLayersResult get _generationData {
    final filled = detectFilledAncestorDepth(_memberMaps, _focusId);
    final depth = mathMax(_ancestorDepth, mathMax(filled, 1));
    return buildGenerationLayers(_memberMaps, _focusId, depth, 2);
  }

  List<GenerationLayer> get _visibleGenerationLayers {
    final layers = _generationData.layers;
    if (_generationFilter == 'all') return layers;
    return layers
        .where((layer) => layer.level.toString() == _generationFilter)
        .toList();
  }

  List<FamilyMember> get _searchPool {
    final maps = _memberMaps;
    final byKey = <String, FamilyMember>{};
    for (final m in _tree?.members ?? const <FamilyMember>[]) {
      byKey[m.id] = m;
      if ((m.userId ?? '').isNotEmpty) byKey[m.userId!] = m;
    }
    final out = <FamilyMember>[];
    final seen = <String>{};
    for (final map in maps) {
      final key = memberKey(map);
      final member = byKey[key] ??
          byKey[memberUserId(map)] ??
          FamilyMember.fromJson(map);
      if (seen.add(member.id)) out.add(member);
    }
    return out;
  }

  List<FamilyMember> get _searchMatches {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _searchPool.where((m) {
      final phone = (m.phone ?? '').replaceAll(RegExp(r'\D'), '');
      final hay = [
        m.name,
        m.relationship,
        phone,
        m.email,
        m.location,
      ].whereType<String>().join(' ').toLowerCase();
      return hay.contains(q);
    }).take(12).toList();
  }

  /// Join-approved / loosely linked people not yet placed on the graph.
  List<FamilyMember> get _unplacedMembers {
    final people = _tree?.members ?? const <FamilyMember>[];
    final relationships = _tree?.relationships ?? const <Map<String, dynamic>>[];
    if (people.isEmpty) return const [];

    final focus = (_focusId ?? '').toString();
    FamilyMember? root;
    for (final m in people) {
      if ((m.userId ?? '') == focus || m.id == focus) {
        root = m;
        break;
      }
    }
    if (root == null) {
      for (final m in people) {
        if (m.isSiteCreator) {
          root = m;
          break;
        }
      }
    }
    root ??= people.first;

    final meaningfulTypes = <String>{};
    final neighbors = <String, Set<String>>{};
    void touch(String from, String to) {
      neighbors.putIfAbsent(from, () => <String>{}).add(to);
    }

    for (final edge in relationships) {
      final type =
          (edge['type'] ?? edge['relationship_type'] ?? '').toString().toLowerCase();
      final source = (edge['source'] ?? '').toString();
      final target = (edge['target'] ?? '').toString();
      if (source.isEmpty || target.isEmpty) continue;
      if (type == 'other' || type == 'unknown') continue;
      if (type.isNotEmpty) {
        meaningfulTypes.add(source);
        meaningfulTypes.add(target);
      }
      touch(source, target);
      touch(target, source);
    }

    final seen = <String>{root.id};
    final queue = <String>[root.id];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      for (final next in neighbors[current] ?? const <String>{}) {
        if (seen.add(next)) queue.add(next);
      }
    }

    return people.where((member) {
      if (member.id == root!.id) return false;
      if (member.isSiteCreator) return false;
      if (!seen.contains(member.id)) return true;
      if (!meaningfulTypes.contains(member.id)) return true;
      return false;
    }).toList();
  }

  List<FamilyMember> get _placedMembers {
    final hidden = _unplacedMembers.map((m) => m.id).toSet();
    return (_tree?.members ?? const <FamilyMember>[])
        .where((m) => !hidden.contains(m.id))
        .toList();
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
      final tree = FamilyTreeData.fromJson(data);
      final maps = tree.members.map(_memberToMap).toList();
      if (!mounted) return;
      final focus = _focusOverrideId ??
          resolveDefaultFocusUserId(
            maps,
            context.read<AuthProvider>().user?.toJson(),
          );
      final filled = detectFilledAncestorDepth(maps, focus);
      setState(() {
        _tree = tree;
        _role = tree.role;
        _ancestorDepth = mathMax(_ancestorDepth, mathMax(filled, 1));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _jumpToMember(FamilyMember member) async {
    setState(() {
      _selected = member;
      _viewMode = 'diagram';
      _scope = 'full';
      _searchOpen = false;
      _search.clear();
    });
    await _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _graphKey.currentState?.focusMember(member.id);
    });
  }

  Future<void> _openMemberProfile(FamilyMember member) async {
    final familyId = context.read<FamilySessionProvider>().familyId;
    if (familyId == null) return;
    setState(() => _selected = member);

    String? treeRole;
    try {
      final layout = buildFamilyLayout(
        _memberMaps,
        _tree?.relationships ?? const [],
        _focusId,
      );
      for (final node in layout.nodes) {
        if ((node['id'] ?? '').toString() == member.id) {
          treeRole = node['treeRole']?.toString();
          break;
        }
      }
    } catch (_) {}

    await showTreeMemberProfileSheet(
      context: context,
      member: member,
      familyId: familyId,
      members: _tree?.members ?? const [],
      relationships: _tree?.relationships ?? const [],
      focusUserId: _focusId,
      meUserId: context.read<AuthProvider>().user?.id,
      isAdmin: _isAdmin,
      onChanged: _load,
      treeRole: treeRole,
      onShowTheirTree: member.hasLoginAccount
          ? () => _showTheirTree(member)
          : null,
      onChat: member.hasLoginAccount && member.isAlive
          ? () {
              setState(() {
                _chatPeerUserId = member.userId;
                _chatDockNonce++;
                _selected = null;
              });
            }
          : null,
      onMakeAdmin: _isAdmin ? _toggleAdmin : null,
      onOpenKin: (kin) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _openMemberProfile(kin);
        });
      },
    );
  }

  Future<void> _showTheirTree(FamilyMember member) async {
    final id = member.userId ?? member.id;
    setState(() {
      _focusOverrideId = id;
      _selected = null;
      _generationFilter = 'all';
      _viewMode = 'diagram';
    });
  }

  Future<void> _openAdd(FamilyMember person) async {
    if (!_canAddOnTree) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Switch to My circle on your own tree to add someone.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _selected = null;
      _radialPerson = person;
    });
  }

  Future<void> _onRadialSelect(AddRelativeAction action) async {
    final anchor = _radialPerson;
    final familyId = context.read<FamilySessionProvider>().familyId;
    if (anchor == null || familyId == null) return;
    setState(() => _radialPerson = null);
    final ok = await showAddRelativeSheet(
      context: context,
      familyId: familyId,
      members: _tree?.members ?? const [],
      relatedTo: anchor,
      relationship: action.relationship,
      gender: action.gender,
      focusUserId: _focusId,
    );
    if (ok) await _load();
  }

  Future<void> _openLink(FamilyMember person, {FamilyMember? target}) async {
    final familyId = context.read<FamilySessionProvider>().familyId;
    if (familyId == null || !_canAddOnTree) return;
    setState(() => _selected = null);
    final ok = await showSetRelationSheet(
      context: context,
      familyId: familyId,
      members: _placedMembers.isEmpty
          ? (_tree?.members ?? const [])
          : _placedMembers,
      member: person,
      initialTarget: target,
    );
    if (ok) await _load();
  }

  Future<void> _toggleAdmin(FamilyMember person) async {
    final familyId = context.read<FamilySessionProvider>().familyId;
    if (!_isAdmin ||
        familyId == null ||
        person.isOwner ||
        !person.hasLoginAccount) {
      return;
    }
    final nextAdmin = !person.isAdmin;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          nextAdmin
              ? 'Make ${person.name} an admin?'
              : 'Remove admin from ${person.name}?',
        ),
        content: Text(
          nextAdmin
              ? 'They can manage members and family settings.'
              : 'They will become a regular family member.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(nextAdmin ? 'Make admin' : 'Remove admin'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final res = await context.read<FamilyApiService>().setFamilyMemberAdmin(
            familyId,
            person.id,
            nextAdmin,
          );
      final updated = res.data is Map ? res.data['member'] : null;
      final nextIsAdmin =
          updated is Map ? updated['isAdmin'] == true : nextAdmin;
      setState(() {
        final current = _tree;
        if (current == null) return;
        _tree = FamilyTreeData(
          members: current.members
              .map(
                (m) =>
                    m.id == person.id ? m.copyWith(isAdmin: nextIsAdmin) : m,
              )
              .toList(),
          relationships: current.relationships,
          role: current.role,
        );
        if (_selected?.id == person.id) {
          _selected = _selected!.copyWith(isAdmin: nextIsAdmin);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _expand(FamilyMember person) async {
    final familyId = context.read<FamilySessionProvider>().familyId;
    if (familyId == null) return;
    try {
      final res = await context.read<FamilyApiService>().getFamilyTree(
        familyId,
        params: {
          'scope': 'around',
          'memberId': person.id,
          'depth': 1,
        },
      );
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      final extra = FamilyTreeData.fromJson(data);
      final current = _tree;
      if (current == null) {
        setState(() => _tree = extra);
        return;
      }
      final byId = {for (final m in current.members) m.id: m};
      for (final m in extra.members) {
        byId[m.id] = m;
      }
      final rels = [...current.relationships];
      final seen = {
        for (final r in rels) '${r['source']}_${r['target']}_${r['type']}',
      };
      for (final r in extra.relationships) {
        final key = '${r['source']}_${r['target']}_${r['type']}';
        if (seen.add(key)) rels.add(r);
      }
      setState(() {
        _tree = FamilyTreeData(
          members: byId.values.toList(),
          relationships: rels,
          role: current.role ?? extra.role,
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _download() async {
    if (_viewMode != 'diagram') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Switch to Diagram to download the tree')),
      );
      return;
    }
    final name =
        context.read<FamilySessionProvider>().current?.name ?? 'family-tree';
    setState(() => _downloading = true);
    try {
      await _graphKey.currentState?.exportPng(name);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _addPreviousGeneration() {
    if (_ancestorDepth >= _maxAncestorDepth) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum $_maxAncestorDepth ancestor generations'),
        ),
      );
      return;
    }
    setState(() => _ancestorDepth += 1);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<FamilySessionProvider>();
    final auth = context.watch<AuthProvider>();
    final hint = _isAdmin
        ? 'You registered this family. You can add anyone, in any circle.'
        : _canAddOnTree
            ? 'Tap green + on a person to add their relative.'
            : 'Switch to My circle to add people near you.';
    final members = _tree?.members ?? const <FamilyMember>[];

    return Stack(
      children: [
        FtPage(
          title: 'Family Tree',
          actions: [
            if (!_loading && _error == null) ...[
              IconButton(
                tooltip: 'Download',
                onPressed: _downloading || members.isEmpty ? null : _download,
                icon: _downloading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
              ),
            ],
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
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
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (session.families.length > 1)
                                SizedBox(
                                  height: 40,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: session.families.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 8),
                                    itemBuilder: (_, i) {
                                      final f = session.families[i];
                                      return ChoiceChip(
                                        label: Text(f.name),
                                        selected: session.current?.id == f.id,
                                        onSelected: (_) {
                                          session.selectFamily(f);
                                          _focusOverrideId = null;
                                          _load();
                                        },
                                      );
                                    },
                                  ),
                                ),
                              if (!_viewingSelf) ...[
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFBAE6FD),
                                    ),
                                  ),
                                  child: Text(
                                    'Viewing as ${_focusMemberName()} · ${members.length} members',
                                    style: AppTheme.body(
                                      size: 11,
                                      weight: FontWeight.w700,
                                      color: const Color(0xFF075985),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              _ToolbarCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        if (_isAdmin) ...[
                                          const Text(
                                            'VIEW AS',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF047857),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 170,
                                            child: Builder(
                                              builder: (context) {
                                                final values = <String>{
                                                  for (final m in members)
                                                    m.userId ?? m.id,
                                                };
                                                final current = values.contains(
                                                  _focusId,
                                                )
                                                    ? _focusId
                                                    : (values.isEmpty
                                                        ? null
                                                        : values.first);
                                                return DropdownButtonFormField<
                                                    String>(
                                                  value: current,
                                                  isExpanded: true,
                                                  decoration:
                                                      const InputDecoration(
                                                    isDense: true,
                                                    contentPadding:
                                                        EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8,
                                                    ),
                                                  ),
                                                  items: [
                                                    for (final m in members)
                                                      DropdownMenuItem(
                                                        value:
                                                            m.userId ?? m.id,
                                                        child: Text(
                                                          '${m.name}${_isMyMember(m) ? ' (You)' : ''}',
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                  ],
                                                  onChanged: (v) {
                                                    if (v == null) return;
                                                    setState(() {
                                                      _focusOverrideId = v;
                                                      _selected = null;
                                                      _generationFilter = 'all';
                                                    });
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                          if (!_viewingSelf)
                                            OutlinedButton.icon(
                                              onPressed: () => setState(() {
                                                _focusOverrideId = _myFocusId;
                                                _selected = null;
                                                _generationFilter = 'all';
                                              }),
                                              icon: const Icon(
                                                Icons.restart_alt,
                                                size: 16,
                                              ),
                                              label: const Text('My tree'),
                                            ),
                                        ],
                                        _ModeToggle(
                                          left: 'Diagram',
                                          right: 'List',
                                          leftSelected: _viewMode == 'diagram',
                                          onLeft: () => setState(
                                            () => _viewMode = 'diagram',
                                          ),
                                          onRight: () => setState(
                                            () => _viewMode = 'generations',
                                          ),
                                        ),
                                        _ModeToggle(
                                          left: 'Complete tree',
                                          right: 'My circle',
                                          leftSelected: _scope == 'full',
                                          filled: true,
                                          onLeft: () {
                                            if (_scope == 'full') return;
                                            setState(() => _scope = 'full');
                                            _load();
                                          },
                                          onRight: () {
                                            if (_scope == 'near') return;
                                            setState(() => _scope = 'near');
                                            _load();
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Stack(
                                      children: [
                                        TextField(
                                          controller: _search,
                                          onChanged: (_) => setState(() {
                                            _searchOpen = true;
                                          }),
                                          onTap: () =>
                                              setState(() => _searchOpen = true),
                                          decoration: InputDecoration(
                                            hintText: 'Search name or mobile…',
                                            isDense: true,
                                            prefixIcon: const Icon(
                                              Icons.search,
                                              size: 18,
                                            ),
                                            suffixIcon: _search.text.isEmpty
                                                ? null
                                                : IconButton(
                                                    icon: const Icon(
                                                      Icons.close,
                                                      size: 16,
                                                    ),
                                                    onPressed: () => setState(() {
                                                      _search.clear();
                                                      _searchOpen = false;
                                                    }),
                                                  ),
                                          ),
                                          onSubmitted: (_) {
                                            final first = _searchMatches;
                                            if (first.isNotEmpty) {
                                              _jumpToMember(first.first);
                                            }
                                          },
                                        ),
                                        if (_searchOpen &&
                                            _search.text.trim().isNotEmpty)
                                          Positioned(
                                            left: 0,
                                            right: 0,
                                            top: 44,
                                            child: Material(
                                              elevation: 6,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              color: Colors.white,
                                              child: ConstrainedBox(
                                                constraints: const BoxConstraints(
                                                  maxHeight: 220,
                                                ),
                                                child: _searchMatches.isEmpty
                                                    ? const Padding(
                                                        padding: EdgeInsets.all(
                                                          12,
                                                        ),
                                                        child: Text(
                                                          'No member found',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Color(
                                                              0xFF94A3B8,
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                    : ListView.builder(
                                                        shrinkWrap: true,
                                                        itemCount:
                                                            _searchMatches.length,
                                                        itemBuilder: (_, i) {
                                                          final m =
                                                              _searchMatches[i];
                                                          final phone =
                                                              (m.phone ?? '')
                                                                  .replaceAll(
                                                            RegExp(r'\D'),
                                                            '',
                                                          );
                                                          return ListTile(
                                                            dense: true,
                                                            title: Text(m.name),
                                                            subtitle: Text(
                                                              [
                                                                m.relationship,
                                                                if (phone
                                                                    .isNotEmpty)
                                                                  '+91 $phone',
                                                              ]
                                                                  .whereType<
                                                                      String>()
                                                                  .where(
                                                                    (e) => e
                                                                        .isNotEmpty,
                                                                  )
                                                                  .join(' · '),
                                                            ),
                                                            onTap: () =>
                                                                _jumpToMember(m),
                                                          );
                                                        },
                                                      ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (_viewMode == 'generations') ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: DropdownButtonFormField<String>(
                                              value: _generationFilter,
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 8,
                                                ),
                                              ),
                                              items: [
                                                const DropdownMenuItem(
                                                  value: 'all',
                                                  child: Text('All generations'),
                                                ),
                                                for (final layer
                                                    in _generationData.layers)
                                                  DropdownMenuItem(
                                                    value: layer.level.toString(),
                                                    child: Text(
                                                      layer.title.replaceFirst(
                                                        RegExp(r'^Generation\s+',
                                                            caseSensitive:
                                                                false),
                                                        'Gen ',
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                              ],
                                              onChanged: (v) {
                                                if (v == null) return;
                                                setState(
                                                  () => _generationFilter = v,
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            onPressed: _ancestorDepth >=
                                                    _maxAncestorDepth
                                                ? null
                                                : _addPreviousGeneration,
                                            icon: const Icon(Icons.add, size: 16),
                                            label: Text(
                                              'Add gen $_ancestorDepth/$_maxAncestorDepth',
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: 32,
                                        child: ListView(
                                          scrollDirection: Axis.horizontal,
                                          children: [
                                            _GenChip(
                                              label: 'All',
                                              selected:
                                                  _generationFilter == 'all',
                                              onTap: () => setState(
                                                () => _generationFilter = 'all',
                                              ),
                                            ),
                                            for (final layer
                                                in _generationData.layers)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 6,
                                                ),
                                                child: _GenChip(
                                                  label:
                                                      '${layer.title.replaceFirst(RegExp(r'^Generation\s+', caseSensitive: false), 'Gen ')} ${layer.members.length}',
                                                  selected: _generationFilter ==
                                                      layer.level.toString(),
                                                  onTap: () => setState(() {
                                                    final key =
                                                        layer.level.toString();
                                                    _generationFilter =
                                                        _generationFilter == key
                                                            ? 'all'
                                                            : key;
                                                  }),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Text(
                                      hint,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTheme.body(
                                        size: 11,
                                        color: AppTheme.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_canAddOnTree &&
                                  _unplacedMembers.isNotEmpty &&
                                  _viewMode == 'diagram') ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Place on tree',
                                  style: AppTheme.body(
                                    size: 12,
                                    weight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  height: 44,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _unplacedMembers.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 8),
                                    itemBuilder: (_, i) {
                                      final m = _unplacedMembers[i];
                                      return ActionChip(
                                        avatar: CircleAvatar(
                                          backgroundColor: AppTheme.forest
                                              .withValues(alpha: 0.12),
                                          child: Text(
                                            m.name.isNotEmpty
                                                ? m.name[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                        ),
                                        label: Text(m.name),
                                        onPressed: () => _openLink(m),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Expanded(
                          child: _viewMode == 'generations'
                              ? _GenerationsList(
                                  layers: _visibleGenerationLayers,
                                  selectedId: _selected?.id,
                                  meUserId: auth.user?.id,
                                  onSelect: (map) {
                                    final id = (map['id'] ?? '').toString();
                                    final userId =
                                        (map['userId'] ?? map['user_id'] ?? '')
                                            .toString();
                                    FamilyMember? member;
                                    for (final m in members) {
                                      if (m.id == id ||
                                          (userId.isNotEmpty &&
                                              m.userId == userId)) {
                                        member = m;
                                        break;
                                      }
                                    }
                                    member ??= FamilyMember.fromJson(map);
                                    _openMemberProfile(member);
                                  },
                                )
                              : Stack(
                                  children: [
                                    FamilyGraphView(
                                      key: _graphKey,
                                      members: _placedMembers,
                                      relationships:
                                          _tree?.relationships ?? const [],
                                      focusUserId: _focusId,
                                      meUserId: auth.user?.id,
                                      selectedId: _selected?.id,
                                      canAdd: _canAddOnTree,
                                      showExpand: _scope == 'near',
                                      onMemberTap: _openMemberProfile,
                                      onAdd: _canAddOnTree ? _openAdd : null,
                                      onLink: _canAddOnTree ? _openLink : null,
                                      onExpand:
                                          _scope == 'near' ? _expand : null,
                                      onMakeAdmin:
                                          _isAdmin ? _toggleAdmin : null,
                                    ),
                                    if (_selected != null)
                                      Positioned(
                                        left: 12,
                                        right: 12,
                                        bottom: 12,
                                        child: _SelectedMemberCard(
                                          member: _selected!,
                                          meUserId: auth.user?.id,
                                          isAdmin: _isAdmin,
                                          canAdd: _canAddOnTree,
                                          onClose: () =>
                                              setState(() => _selected = null),
                                          onChat: () {
                                            setState(() {
                                              _chatPeerUserId =
                                                  _selected!.userId;
                                              _chatDockNonce++;
                                              _selected = null;
                                            });
                                          },
                                          onAdd: () => _openAdd(_selected!),
                                          onAdmin: () =>
                                              _toggleAdmin(_selected!),
                                          onShowTree: () =>
                                              _showTheirTree(_selected!),
                                          onOpenProfile: () =>
                                              _openMemberProfile(_selected!),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      ],
                    ),
        ),
        if (!_loading && _error == null && session.familyId != null)
          FamilyChatDock(
            key: ValueKey('chat-dock-$_chatDockNonce-${session.familyId}'),
            familyId: session.familyId!,
            initialPeerUserId: _chatPeerUserId,
            onModeChanged: (mode) {
              if (mode == FamilyChatDockMode.closed) {
                setState(() => _chatPeerUserId = null);
              }
            },
          ),
        if (_radialPerson != null)
          Positioned.fill(
            child: AddRelativeRadial(
              person: _radialPerson!,
              onClose: () => setState(() => _radialPerson = null),
              onSelect: _onRadialSelect,
            ),
          ),
      ],
    );
  }

  bool _isMyMember(FamilyMember m) {
    final mine = _myFocusId;
    if (mine == null) return false;
    return m.userId == mine || m.id == mine;
  }

  String _focusMemberName() {
    final focus = _focusId;
    if (focus == null) return 'member';
    for (final m in _tree?.members ?? const <FamilyMember>[]) {
      if (m.userId == focus || m.id == focus) return m.name;
    }
    return 'member';
  }
}

MemberMap _memberToMap(FamilyMember m) => {
      'id': m.id,
      'userId': m.userId,
      'user_id': m.userId,
      'name': m.name,
      'relationship': m.relationship,
      'status': m.status,
      'email': m.email,
      'phone': m.phone,
      'avatar': m.avatar,
      'gender': m.gender,
      'location': m.location,
      'isAdmin': m.isAdmin,
      'isOwner': m.isOwner,
      'invitePending': m.invitePending,
      'profileInfo': m.profileInfo,
      'profile_info': m.profileInfo,
    };

int mathMax(int a, int b) => a > b ? a : b;

class _ToolbarCard extends StatelessWidget {
  const _ToolbarCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.left,
    required this.right,
    required this.leftSelected,
    required this.onLeft,
    required this.onRight,
    this.filled = false,
  });

  final String left;
  final String right;
  final bool leftSelected;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pill(left, leftSelected, onLeft),
          _pill(right, !leftSelected, onRight),
        ],
      ),
    );
  }

  Widget _pill(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? (filled ? AppTheme.forest : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected && !filled
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected
                ? (filled ? Colors.black : AppTheme.forest)
                : AppTheme.muted,
          ),
        ),
      ),
    );
  }
}

class _GenChip extends StatelessWidget {
  const _GenChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _GenerationsList extends StatelessWidget {
  const _GenerationsList({
    required this.layers,
    required this.onSelect,
    this.selectedId,
    this.meUserId,
  });

  final List<GenerationLayer> layers;
  final ValueChanged<MemberMap> onSelect;
  final String? selectedId;
  final String? meUserId;

  @override
  Widget build(BuildContext context) {
    if (layers.isEmpty) {
      return const Center(child: Text('No generation data yet'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
      itemCount: layers.length,
      itemBuilder: (_, i) {
        final layer = layers[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            layer.title.replaceFirst(
                              RegExp(r'^Generation\s+', caseSensitive: false),
                              'Gen ',
                            ),
                            style: AppTheme.body(weight: FontWeight.w800),
                          ),
                          if (layer.subtitle.isNotEmpty)
                            Text(
                              layer.subtitle,
                              style: AppTheme.body(
                                size: 11,
                                color: AppTheme.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: const Color(0xFFF1F5F9),
                      child: Text(
                        '${layer.members.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (layer.members.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'No members yet',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                )
              else
                ...layer.members.map((m) {
                  final id = (m['id'] ?? '').toString();
                  final userId = (m['userId'] ?? m['user_id'] ?? '').toString();
                  final selected = selectedId == id;
                  final isMe = meUserId != null &&
                      (userId == meUserId || id == meUserId);
                  final url = mediaUrl((m['avatar'] ?? '').toString());
                  return ListTile(
                    selected: selected,
                    selectedTileColor: const Color(0xFFECFDF5),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.forest.withValues(alpha: 0.12),
                      backgroundImage: url != null ? NetworkImage(url) : null,
                      child: url == null
                          ? Text(
                              ((m['name'] ?? '?').toString().isNotEmpty
                                      ? (m['name'] as String)[0]
                                      : '?')
                                  .toUpperCase(),
                            )
                          : null,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            (m['name'] ?? 'Member').toString(),
                            style: AppTheme.body(weight: FontWeight.w800),
                          ),
                        ),
                        if (isMe)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBBF24),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'YOU',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      [
                        (m['generationRole'] ?? m['relationship'] ?? '')
                            .toString(),
                        (m['location'] ?? '').toString(),
                      ].where((e) => e.trim().isNotEmpty).join(' · '),
                    ),
                    onTap: () => onSelect(m),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _SelectedMemberCard extends StatelessWidget {
  const _SelectedMemberCard({
    required this.member,
    required this.isAdmin,
    required this.canAdd,
    required this.onClose,
    required this.onChat,
    required this.onAdd,
    required this.onAdmin,
    required this.onShowTree,
    required this.onOpenProfile,
    this.meUserId,
  });

  final FamilyMember member;
  final String? meUserId;
  final bool isAdmin;
  final bool canAdd;
  final VoidCallback onClose;
  final VoidCallback onChat;
  final VoidCallback onAdd;
  final VoidCallback onAdmin;
  final VoidCallback onShowTree;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: AppTheme.card,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
        child: Row(
          children: [
            Expanded(
              child: ListTile(
                contentPadding: const EdgeInsets.only(left: 8),
                onTap: onOpenProfile,
                leading: CircleAvatar(
                  backgroundColor: AppTheme.forest.withValues(alpha: 0.12),
                  child: Text(
                    member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                  ),
                ),
                title: Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    if (member.relationship != null) member.relationship!,
                    if (member.isOwner)
                      'Owner'
                    else if (member.isAdmin)
                      'Admin',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if ((member.userId ?? '').isNotEmpty &&
                member.userId != meUserId &&
                member.isAlive)
              IconButton(
                tooltip: 'Chat',
                onPressed: onChat,
                icon: Icon(Icons.chat_bubble, color: AppTheme.accentPink),
              ),
            if (isAdmin && member.hasLoginAccount)
              IconButton(
                tooltip: 'Show their tree',
                onPressed: onShowTree,
                icon: const Icon(Icons.visibility_outlined),
              ),
            if (isAdmin &&
                !member.isOwner &&
                member.hasLoginAccount &&
                member.isAlive)
              IconButton(
                tooltip: member.isAdmin ? 'Remove admin' : 'Make admin',
                onPressed: onAdmin,
                icon: Icon(
                  member.isAdmin
                      ? Icons.shield_outlined
                      : Icons.admin_panel_settings_outlined,
                  color: const Color(0xFF0369A1),
                ),
              ),
            if (canAdd)
              IconButton(
                tooltip: 'Add relative',
                onPressed: onAdd,
                icon: const Icon(Icons.add_circle, color: Color(0xFF059669)),
              ),
            IconButton(icon: const Icon(Icons.close), onPressed: onClose),
          ],
        ),
      ),
    );
  }
}
