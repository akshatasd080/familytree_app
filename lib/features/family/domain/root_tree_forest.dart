import '../../../core/utils/media_url.dart';
import '../data/models/family_models.dart';

const _parentTypes = {
  'father',
  'mother',
  'parent',
  'grandfather',
  'grandmother',
};
const _childTypes = {
  'son',
  'daughter',
  'child',
  'grandson',
  'granddaughter',
};
const _spouseTypes = {'husband', 'wife', 'spouse'};

class RootTreeNode {
  RootTreeNode({
    required this.id,
    required this.name,
    this.photo,
    this.spouse,
    this.spouseId,
    this.spousePhoto,
    this.children = const [],
  });

  final String id;
  final String name;
  final String? photo;
  final String? spouse;
  final String? spouseId;
  final String? spousePhoto;
  final List<RootTreeNode> children;

  /// Shape expected by web `parivaar-root.html` bootstrap.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'photo': photo,
        'spouse': spouse,
        'spouseId': spouseId,
        'spousePhoto': spousePhoto,
        'children': children.map((c) => c.toJson()).toList(),
      };
}

String? _personPhoto(FamilyMember member) {
  final info = member.profileInfo;
  return mediaUrl(
    member.avatar ??
        info['avatar']?.toString() ??
        info['profileImage']?.toString() ??
        info['profile_image']?.toString(),
  );
}

void _addTo(Map<String, Set<String>> map, String key, String value) {
  map.putIfAbsent(key, () => <String>{}).add(value);
}

/// Build nested root→descendant forest from graph edges.
List<RootTreeNode> buildRootForest(
  List<FamilyMember> members,
  List<Map<String, dynamic>> relationships,
) {
  final byId = <String, FamilyMember>{
    for (final m in members)
      if (m.id.isNotEmpty) m.id: m,
  };
  if (byId.isEmpty) return const [];

  final parents = <String, Set<String>>{};
  final children = <String, Set<String>>{};
  final spouses = <String, Set<String>>{};

  for (final edge in relationships) {
    final source = (edge['source'] ?? '').toString();
    final target = (edge['target'] ?? '').toString();
    final type = (edge['type'] ?? edge['relationship_type'] ?? '')
        .toString()
        .toLowerCase();
    if (!byId.containsKey(source) ||
        !byId.containsKey(target) ||
        source == target) {
      continue;
    }
    if (_parentTypes.contains(type)) {
      _addTo(parents, target, source);
      _addTo(children, source, target);
    } else if (_childTypes.contains(type)) {
      _addTo(parents, source, target);
      _addTo(children, target, source);
    } else if (_spouseTypes.contains(type)) {
      _addTo(spouses, source, target);
      _addTo(spouses, target, source);
    }
  }

  final paired = <String>{};

  String pickPrimary(String a, String b) {
    final ma = byId[a];
    final mb = byId[b];
    final ga = (ma?.gender ?? '').toLowerCase();
    final gb = (mb?.gender ?? '').toLowerCase();
    if (ga == 'male' && gb != 'male') return a;
    if (gb == 'male' && ga != 'male') return b;
    return a.compareTo(b) <= 0 ? a : b;
  }

  RootTreeNode? buildNode(String id, Set<String> visiting) {
    final key = id;
    if (!byId.containsKey(key) || visiting.contains(key)) return null;
    visiting.add(key);

    String? spouseId;
    final partners = [...(spouses[key] ?? const <String>{})]
        .where((p) => byId.containsKey(p) && !visiting.contains(p))
        .toList();
    if (partners.isNotEmpty) {
      spouseId = partners.first;
      visiting.add(spouseId);
      paired.add(key);
      paired.add(spouseId);
    }

    final childIds = <String>{...(children[key] ?? const <String>{})};
    if (spouseId != null) {
      childIds.addAll(children[spouseId] ?? const <String>{});
    }

    final kids = childIds
        .where((c) => byId.containsKey(c) && !visiting.contains(c))
        .map((c) => buildNode(c, visiting))
        .whereType<RootTreeNode>()
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final member = byId[key]!;
    final spouse = spouseId != null ? byId[spouseId] : null;
    return RootTreeNode(
      id: key,
      name: member.name.isEmpty ? 'Member' : member.name,
      photo: _personPhoto(member),
      spouse: spouse?.name,
      spouseId: spouseId,
      spousePhoto: spouse == null ? null : _personPhoto(spouse),
      children: kids,
    );
  }

  final rootIds =
      byId.keys.where((id) => (parents[id]?.isEmpty ?? true)).toList()
        ..sort((a, b) => (byId[a]?.name ?? '').compareTo(byId[b]?.name ?? ''));

  final roots = <RootTreeNode>[];
  final used = <String>{};

  void mark(RootTreeNode n) {
    used.add(n.id);
    if (n.spouseId != null) used.add(n.spouseId!);
    for (final c in n.children) {
      mark(c);
    }
  }

  for (final id in rootIds) {
    if (used.contains(id)) continue;
    final partners = [...(spouses[id] ?? const <String>{})];
    var primary = id;
    if (partners.isNotEmpty && rootIds.contains(partners.first)) {
      primary = pickPrimary(id, partners.first);
    }
    if (used.contains(primary)) continue;
    final node = buildNode(primary, {...used});
    if (node == null) continue;
    mark(node);
    roots.add(node);
  }

  for (final id in byId.keys) {
    if (used.contains(id)) continue;
    final node = buildNode(id, {...used});
    if (node == null) continue;
    mark(node);
    roots.add(node);
  }

  return roots;
}

int countForestPeople(List<RootTreeNode> roots) {
  var n = 0;
  void walk(RootTreeNode node) {
    n += node.spouse != null ? 2 : 1;
    for (final c in node.children) {
      walk(c);
    }
  }

  for (final r in roots) {
    walk(r);
  }
  return n;
}
