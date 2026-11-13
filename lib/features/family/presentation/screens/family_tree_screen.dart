import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/ft_page.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/family_api_service.dart';
import '../../data/models/family_models.dart';
import '../../domain/ego_tree.dart';
import '../providers/family_providers.dart';
import '../widgets/add_relative_radial.dart';
import '../widgets/add_relative_sheet.dart';
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
  FamilyMember? _radialPerson;
  String? _role;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String? get _myFocusId {
    final user = context.read<AuthProvider>().user;
    final members = _tree?.members ?? const <FamilyMember>[];
    return resolveDefaultFocusUserId(
      members
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
      user?.toJson(),
    );
  }

  bool get _isAdmin => (_role ?? '').toLowerCase() == 'admin';

  bool get _canAddOnTree {
    if (_isAdmin) return true;
    if ((_role ?? '').toLowerCase() == 'viewer') return false;
    // Non-admin: only My circle on own tree (web parity).
    return _scope == 'near';
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
      setState(() {
        _tree = tree;
        _role = tree.role;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
      focusUserId: _myFocusId,
    );
    if (ok) await _load();
  }

  Future<void> _openLink(FamilyMember person) async {
    final familyId = context.read<FamilySessionProvider>().familyId;
    if (familyId == null || !_canAddOnTree) return;
    setState(() => _selected = null);
    final ok = await showSetRelationSheet(
      context: context,
      familyId: familyId,
      members: _tree?.members ?? const [],
      member: person,
    );
    if (ok) await _load();
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
        for (final r in rels)
          '${r['source']}_${r['target']}_${r['type']}',
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

  @override
  Widget build(BuildContext context) {
    final session = context.watch<FamilySessionProvider>();
    final auth = context.watch<AuthProvider>();
    final hint = _isAdmin
        ? 'You registered this family. You can add anyone, in any circle.'
        : _canAddOnTree
            ? 'Tap green + on a person to add their relative.'
            : 'Switch to My circle to add people near you.';

    return Stack(
      children: [
        FtPage(
          title: 'Family Tree',
          actions: [
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
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 8),
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
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppTheme.tabTrack,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    _ScopeTab(
                                      label: 'Complete tree',
                                      selected: _scope == 'full',
                                      onTap: () {
                                        if (_scope == 'full') return;
                                        setState(() => _scope = 'full');
                                        _load();
                                      },
                                    ),
                                    _ScopeTab(
                                      label: 'My circle',
                                      selected: _scope == 'near',
                                      onTap: () {
                                        if (_scope == 'near') return;
                                        setState(() => _scope = 'near');
                                        _load();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                hint,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.body(
                                  size: 11,
                                  color: AppTheme.muted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Pinch to zoom · drag to pan · Fit to see full tree',
                                style: AppTheme.body(
                                  size: 10,
                                  color: AppTheme.muted.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              FamilyGraphView(
                                members: _tree?.members ?? const [],
                                relationships:
                                    _tree?.relationships ?? const [],
                                focusUserId: _myFocusId,
                                meUserId: auth.user?.id,
                                canAdd: _canAddOnTree,
                                showExpand: _scope == 'near',
                                onMemberTap: (m) =>
                                    setState(() => _selected = m),
                                onAdd: _canAddOnTree ? _openAdd : null,
                                onLink: _canAddOnTree ? _openLink : null,
                                onExpand:
                                    _scope == 'near' ? _expand : null,
                              ),
                              if (_selected != null)
                                Positioned(
                                  left: 12,
                                  right: 12,
                                  bottom: 12,
                                  child: Material(
                                    elevation: 8,
                                    borderRadius: BorderRadius.circular(16),
                                    color: AppTheme.card,
                                    child: ListTile(
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16),
                                      ),
                                      leading: CircleAvatar(
                                        backgroundColor: AppTheme.forest
                                            .withValues(alpha: 0.12),
                                        child: Text(
                                          _selected!.name.isNotEmpty
                                              ? _selected!.name[0]
                                                  .toUpperCase()
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
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_canAddOnTree)
                                            IconButton(
                                              tooltip: 'Add relative',
                                              onPressed: () =>
                                                  _openAdd(_selected!),
                                              icon: const Icon(
                                                Icons.add_circle,
                                                color: Color(0xFF059669),
                                              ),
                                            ),
                                          IconButton(
                                            icon: const Icon(Icons.close),
                                            onPressed: () => setState(
                                              () => _selected = null,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
}

class _ScopeTab extends StatelessWidget {
  const _ScopeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppTheme.forest : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: AppTheme.body(
              size: 12,
              weight: FontWeight.w700,
              color: selected ? Colors.white : AppTheme.muted,
            ),
          ),
        ),
      ),
    );
  }
}
