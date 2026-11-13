// Family graph layout (Dart port of tree_frontend familyGraphLayout.js).
// Returns node positions and polyline edge paths for Flutter CustomPainter.

import 'dart:ui' show Offset;

import 'ego_tree.dart' show MemberMap;

const _parentTypes = {'father', 'mother'};
const _childTypes = {'son', 'daughter'};
const _spouseTypes = {'husband', 'wife', 'spouse'};

const double nodeW = 256;
const double nodeH = 100;
const double spouseGap = 36;
const double unitGap = 48;
const double rowGap = 64;
/// Left label column — tighter than web desktop (200) for phone fit.
const double gutter = 118;
const double stride = nodeH + rowGap;

const _bandColors = [
  {'bg': '#f3e8ff', 'ink': '#6b21a8'},
  {'bg': '#fce7f3', 'ink': '#9d174d'},
  {'bg': '#fef9c3', 'ink': '#854d0e'},
  {'bg': '#dcfce7', 'ink': '#166534'},
  {'bg': '#dbeafe', 'ink': '#1d4ed8'},
];

const _levelDelta = <String, int>{
  'father': -1,
  'mother': -1,
  'son': 1,
  'daughter': 1,
  'grandfather': -2,
  'grandmother': -2,
  'grandson': 2,
  'granddaughter': 2,
  'brother': 0,
  'sister': 0,
  'husband': 0,
  'wife': 0,
  'spouse': 0,
  'cousin': 0,
  'uncle': -1,
  'aunt': -1,
  'nephew': 1,
  'niece': 1,
  'father_in_law': -1,
  'mother_in_law': -1,
  'son_in_law': 1,
  'daughter_in_law': 1,
  'brother_in_law': 0,
  'sister_in_law': 0,
};

String _ancestorTitle(int stepsUp) {
  if (stepsUp == 1) return 'Parents & their siblings';
  if (stepsUp == 2) return 'Grandparents';
  if (stepsUp == 3) return 'Great-grandparents';
  return '${stepsUp - 2}th great-grandparents';
}

String _descendantTitle(int stepsDown) {
  if (stepsDown == 1) return 'Children';
  if (stepsDown == 2) return 'Grandchildren';
  if (stepsDown == 3) return 'Great-grandchildren';
  return '${stepsDown - 2}th great-grandchildren';
}

String _byGender(String gender, String male, String female, String neutral) {
  if (gender == 'female') return female;
  if (gender == 'male') return male;
  return neutral;
}

void _addTo(Map<String, Set<String>> map, String key, String value) {
  map.putIfAbsent(key, () => <String>{}).add(value);
}

String _personName(MemberMap? member) => (member?['name'] ?? '').toString();

String _edgeType(Map<String, dynamic> edge) {
  return (edge['type'] ?? edge['relationship_type'] ?? '')
      .toString()
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r"['']"), '')
      .replaceAll(RegExp(r'[\s-]+'), '_');
}

class _DedupedEdge {
  _DedupedEdge({
    required this.source,
    required this.target,
    required this.type,
  });

  final String source;
  final String target;
  final String type;
}

List<_DedupedEdge> _dedupeEdges(List<Map<String, dynamic>> relationships) {
  int rank(String type) {
    if (_parentTypes.contains(type) || _childTypes.contains(type)) return 5;
    if (type == 'grandfather' ||
        type == 'grandmother' ||
        type == 'grandson' ||
        type == 'granddaughter') {
      return 4;
    }
    if (_spouseTypes.contains(type)) return 3;
    if (type == 'uncle' ||
        type == 'aunt' ||
        type == 'nephew' ||
        type == 'niece') {
      return 2;
    }
    if (type == 'brother' || type == 'sister') return 1;
    return 0;
  }

  final best = <String, _DedupedEdge>{};
  for (final edge in relationships) {
    final source = edge['source']?.toString() ?? '';
    final target = edge['target']?.toString() ?? '';
    final type = _edgeType(edge);
    if (source.isEmpty || target.isEmpty || source == target || type.isEmpty) {
      continue;
    }
    final key = '$source>$target';
    final prev = best[key];
    if (prev == null || rank(type) > rank(prev.type)) {
      best[key] = _DedupedEdge(source: source, target: target, type: type);
    }
  }

  final edges = best.values.toList();
  final siblingPair = <String>{};
  for (final edge in edges) {
    if (edge.type != 'brother' && edge.type != 'sister') continue;
    final a = edge.source;
    final b = edge.target;
    siblingPair.add(a.compareTo(b) < 0 ? '$a|$b' : '$b|$a');
  }

  return edges.where((edge) {
    if (!(_parentTypes.contains(edge.type) || _childTypes.contains(edge.type))) {
      return true;
    }
    final key = edge.source.compareTo(edge.target) < 0
        ? '${edge.source}|${edge.target}'
        : '${edge.target}|${edge.source}';
    return !siblingPair.contains(key);
  }).toList();
}

/// A drawable edge as a polyline of [Offset] points (replaces SVG path `d`).
class LayoutEdge {
  const LayoutEdge({
    required this.kind,
    required this.points,
  });

  /// 'spouse' | 'parent' | 'sibling'
  final String kind;
  final List<Offset> points;
}

class LayoutBand {
  const LayoutBand({
    required this.generation,
    required this.y,
    required this.height,
    required this.badge,
    required this.title,
    required this.bg,
    required this.ink,
  });

  final int generation;
  final double y;
  final double height;
  final String badge;
  final String title;
  final String bg;
  final String ink;
}

class FamilyLayoutResult {
  FamilyLayoutResult({
    required this.nodes,
    required this.edges,
    required this.bands,
    required this.width,
    required this.height,
    required this.kinOf,
    required this.centerOf,
  });

  /// Members enriched with x, y, w, h, generation, treeRole.
  final List<MemberMap> nodes;

  /// Polyline edge paths for CustomPainter.
  final List<LayoutEdge> edges;

  final List<LayoutBand> bands;
  final double width;
  final double height;

  /// Lookup kin for a person id.
  final Map<String, List<MemberMap>> Function(String id) kinOf;

  /// Center-top of a node card.
  final Offset Function(String personId) centerOf;
}

/// Build a family tree layout with absolute node positions and edge polylines.
FamilyLayoutResult buildFamilyLayout(
  List<MemberMap> members, [
  List<Map<String, dynamic>> relationships = const [],
  String? focusId,
  String? roleId,
]) {
  final byId = <String, MemberMap>{
    for (final m in members) m['id'].toString(): m,
  };
  final parents = <String, Set<String>>{};
  final children = <String, Set<String>>{};
  final spouses = <String, Set<String>>{};
  final siblingLinks = <String, Set<String>>{};
  final edges = _dedupeEdges(relationships);

  for (final edge in edges) {
    final source = edge.source;
    final target = edge.target;
    if (!byId.containsKey(source) ||
        !byId.containsKey(target) ||
        source == target) {
      continue;
    }
    if (_parentTypes.contains(edge.type)) {
      _addTo(parents, target, source);
      _addTo(children, source, target);
    } else if (_childTypes.contains(edge.type)) {
      _addTo(parents, source, target);
      _addTo(children, target, source);
    } else if (_spouseTypes.contains(edge.type)) {
      _addTo(spouses, source, target);
      _addTo(spouses, target, source);
    } else if (edge.type == 'brother' || edge.type == 'sister') {
      _addTo(siblingLinks, source, target);
      _addTo(siblingLinks, target, source);
    }
  }

  final spouseUnions = <Set<String>>[];
  final seen = <String>{};
  for (final member in members) {
    final start = member['id'].toString();
    if (seen.contains(start)) continue;
    final group = <String>{};
    final queue = <String>[start];
    seen.add(start);
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      group.add(current);
      for (final partner in spouses[current] ?? const <String>{}) {
        if (seen.contains(partner)) continue;
        seen.add(partner);
        queue.add(partner);
      }
    }
    spouseUnions.add(group);
  }

  var unions = spouseUnions.map((ids) => Set<String>.from(ids)).toList();
  int unionOf(String personId) =>
      unions.indexWhere((group) => group.contains(personId));

  var merged = true;
  while (merged) {
    merged = false;
    for (final parentIds in parents.values) {
      final ids = [...parentIds];
      var invalid = false;
      for (var i = 0; i < ids.length && !invalid; i++) {
        for (var j = i + 1; j < ids.length; j++) {
          final a = ids[i];
          final b = ids[j];
          if ((children[a] ?? const <String>{}).contains(b) ||
              (children[b] ?? const <String>{}).contains(a)) {
            invalid = true;
            break;
          }
        }
      }
      if (invalid) continue;
      final indexes = [
        ...{for (final id in ids) unionOf(id)}.where((i) => i >= 0),
      ];
      if (indexes.length < 2) continue;
      final keep = indexes.reduce((a, b) => a < b ? a : b);
      final toMerge = indexes.where((i) => i != keep).toList()
        ..sort((a, b) => b.compareTo(a));
      for (final index in toMerge) {
        unions[keep].addAll(unions[index]);
        unions.removeAt(index);
      }
      merged = true;
      break;
    }
  }

  String unionId(Set<String> group) => ([...group]..sort()).join('|');
  final unionByKey = <String, Set<String>>{
    for (final group in unions) unionId(group): group,
  };

  final childKeys = <String, Set<String>>{};
  final parentKey = <String, String>{};
  for (final group in unions) {
    final key = unionId(group);
    final kids = <String>{};
    for (final personId in group) {
      for (final childId in children[personId] ?? const <String>{}) {
        if (group.contains(childId)) continue;
        final index = unionOf(childId);
        if (index >= 0) kids.add(unionId(unions[index]));
      }
    }
    kids.remove(key);
    childKeys[key] = kids;
  }

  childKeys.forEach((key, kids) {
    for (final childKey in kids) {
      parentKey.putIfAbsent(childKey, () => key);
    }
  });

  final generation = <String, int>{};
  final visiting = <String>{};
  int generationOf(String key) {
    if (generation.containsKey(key)) return generation[key]!;
    if (visiting.contains(key)) return 0;
    visiting.add(key);
    final parent = parentKey[key];
    final value =
        parent != null && parent != key ? generationOf(parent) + 1 : 0;
    visiting.remove(key);
    generation[key] = value;
    return value;
  }

  for (final key in unionByKey.keys) {
    generationOf(key);
  }

  String findPerson(String? key) {
    final id = key?.toString() ?? '';
    if (id.isEmpty) return '';
    for (final item in members) {
      final userId = (item['userId'] ?? item['user_id'] ?? '').toString();
      if (item['id'].toString() == id || userId == id) {
        return item['id'].toString();
      }
    }
    return '';
  }

  final focusPersonId = findPerson(focusId);
  final rolePersonId = findPerson(roleId);
  final effectiveRoleId =
      rolePersonId.isNotEmpty ? rolePersonId : focusPersonId;

  bool unionHasFocus(String key, [Set<String>? seenKeys]) {
    final seenLocal = seenKeys ?? <String>{};
    if (focusPersonId.isEmpty || key.isEmpty || seenLocal.contains(key)) {
      return false;
    }
    seenLocal.add(key);
    if ((unionByKey[key] ?? const <String>{}).contains(focusPersonId)) {
      return true;
    }
    for (final childKey in childKeys[key] ?? const <String>{}) {
      if (parentKey[childKey] == key &&
          unionHasFocus(childKey, seenLocal)) {
        return true;
      }
    }
    return false;
  }

  List<String> childrenOf(String key) {
    final kids = [...(childKeys[key] ?? const <String>{})]
        .where((childKey) => parentKey[childKey] == key)
        .toList()
      ..sort((a, b) {
        final an = _personName(
          byId[[...(unionByKey[a] ?? const <String>{})].first],
        );
        final bn = _personName(
          byId[[...(unionByKey[b] ?? const <String>{})].first],
        );
        return an.compareTo(bn);
      });
    final line = kids.where(unionHasFocus).toList();
    final rest = kids.where((k) => !unionHasFocus(k)).toList();
    final mid = rest.length ~/ 2;
    return [...rest.sublist(0, mid), ...line, ...rest.sublist(mid)];
  }

  List<String> orderPeople(Set<String> group) {
    final list = [...group];
    list.sort((a, b) {
      final aHasParent = (parents[a] ?? const <String>{}).isNotEmpty ? 0 : 1;
      final bHasParent = (parents[b] ?? const <String>{}).isNotEmpty ? 0 : 1;
      if (aHasParent != bHasParent) return aHasParent.compareTo(bHasParent);
      return _personName(byId[a]).compareTo(_personName(byId[b]));
    });
    return list;
  }

  final widthOf = <String, double>{};
  double measure(String key) {
    if (widthOf.containsKey(key)) return widthOf[key]!;
    final people = orderPeople(unionByKey[key] ?? {});
    final own =
        people.length * nodeW + (people.length > 1 ? people.length - 1 : 0) * spouseGap;
    final kids = childrenOf(key);
    if (kids.isEmpty) {
      widthOf[key] = own;
      return own;
    }
    final kidsWidth = kids.fold<double>(0, (sum, childKey) => sum + measure(childKey)) +
        unitGap * (kids.length - 1);
    final width = own > kidsWidth ? own : kidsWidth;
    widthOf[key] = width;
    return width;
  }

  final level = <String, int>{};
  if (focusPersonId.isNotEmpty) {
    level[focusPersonId] = 0;
    final visited = <String>{focusPersonId};

    void walk(bool allowZero) {
      final queue = [...level.keys];
      final seenWave = {...queue};
      while (queue.isNotEmpty) {
        final current = queue.removeAt(0);
        for (final edge in edges) {
          final source = edge.source;
          final target = edge.target;
          final delta = _levelDelta[edge.type];
          if (delta == null) continue;
          if (!allowZero && delta == 0) continue;
          if (allowZero && delta != 0) continue;
          String? other;
          int? next;
          if (source == current) {
            other = target;
            next = level[current]! - delta;
          } else if (target == current) {
            other = source;
            next = level[current]! + delta;
          }
          if (other == null || !byId.containsKey(other)) continue;
          if (visited.contains(other)) continue;
          visited.add(other);
          level[other] = next!;
          if (!seenWave.contains(other)) {
            seenWave.add(other);
            queue.add(other);
          }
        }
      }
    }

    walk(false);
    walk(true);

    var spread = true;
    while (spread) {
      spread = false;
      spouses.forEach((personId, partners) {
        if (!level.containsKey(personId)) return;
        for (final partnerId in partners) {
          if (level.containsKey(partnerId)) continue;
          level[partnerId] = level[personId]!;
          spread = true;
        }
      });
      siblingLinks.forEach((personId, siblings) {
        if (!level.containsKey(personId)) return;
        for (final siblingId in siblings) {
          if (level.containsKey(siblingId)) continue;
          level[siblingId] = level[personId]!;
          spread = true;
        }
      });
    }
  }

  final knownLevels = level.values.toList();
  final minLevel =
      knownLevels.isEmpty ? 0 : knownLevels.reduce((a, b) => a < b ? a : b);

  int rowOf(String key) {
    if (parentKey.containsKey(key)) return generationOf(key);
    final people = [...(unionByKey[key] ?? const <String>{})];
    final levels =
        people.map((id) => level[id]).whereType<int>().toList();
    if (levels.isNotEmpty) {
      return levels.reduce((a, b) => a < b ? a : b) - minLevel;
    }
    return generationOf(key);
  }

  void nudgeOverlaps(Map<String, Offset> positions) {
    final list = positions.entries.toList();
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        final a = list[i].value;
        final b = list[j].value;
        final ox = (a.dx + nodeW < b.dx + nodeW ? a.dx + nodeW : b.dx + nodeW) -
            (a.dx > b.dx ? a.dx : b.dx);
        final oy = (a.dy + nodeH < b.dy + nodeH ? a.dy + nodeH : b.dy + nodeH) -
            (a.dy > b.dy ? a.dy : b.dy);
        if (ox > 4 && oy > 4) {
          final idB = list[j].key;
          final nudged = Offset(a.dx + nodeW + spouseGap, b.dy);
          positions[idB] = nudged;
          list[j] = MapEntry(idB, nudged);
        }
      }
    }
  }

  String statedGender(String personId) {
    final member = byId[personId];
    final stated = (member?['gender'] ?? '').toString().toLowerCase();
    if (stated.startsWith('f')) return 'female';
    if (stated.startsWith('m')) return 'male';
    final rel = (member?['relationship'] ?? '')
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s-]+'), '_');
    if (rel == 'spouse' || rel == 'partner') return 'unknown';
    if (RegExp(r'mother|wife|aunt|sister|daughter|grandmother|niece|grandma')
        .hasMatch(rel)) {
      return 'female';
    }
    if (RegExp(r'father|husband|uncle|brother|son|grandfather|nephew|grandpa')
        .hasMatch(rel)) {
      return 'male';
    }
    const femaleTypes = {
      'mother',
      'aunt',
      'sister',
      'daughter',
      'grandmother',
      'granddaughter',
      'niece',
    };
    const maleTypes = {
      'father',
      'uncle',
      'brother',
      'son',
      'grandfather',
      'grandson',
      'nephew',
    };
    for (final edge in edges) {
      if (edge.source != personId) continue;
      if (femaleTypes.contains(edge.type)) return 'female';
      if (maleTypes.contains(edge.type)) return 'male';
    }
    return 'unknown';
  }

  final genderOfPerson = <String, String>{};
  for (final member in members) {
    final id = member['id'].toString();
    genderOfPerson[id] = statedGender(id);
  }
  var guessed = true;
  while (guessed) {
    guessed = false;
    spouses.forEach((personId, partners) {
      if (genderOfPerson[personId] != 'unknown') return;
      for (final partnerId in partners) {
        final partnerGender = genderOfPerson[partnerId];
        if (partnerGender == 'male' || partnerGender == 'female') {
          genderOfPerson[personId] =
              partnerGender == 'male' ? 'female' : 'male';
          guessed = true;
          break;
        }
      }
    });
  }
  String genderOf(String personId) => genderOfPerson[personId] ?? 'unknown';

  Set<String> parentSet(String personId) =>
      parents[personId] ?? const <String>{};
  Set<String> childSet(String personId) =>
      children[personId] ?? const <String>{};
  Set<String> spouseSet(String personId) =>
      spouses[personId] ?? const <String>{};

  Set<String> gather(Iterable<String> ids, Set<String> Function(String) read) {
    final found = <String>{};
    for (final personId in ids) {
      found.addAll(read(personId));
    }
    return found;
  }

  Set<String> siblingsOf(String personId) {
    final found = <String>{};
    for (final parentId in parentSet(personId)) {
      for (final childId in childSet(parentId)) {
        if (childId != personId) found.add(childId);
      }
    }
    for (final siblingId in siblingLinks[personId] ?? const <String>{}) {
      if (siblingId != personId) found.add(siblingId);
    }
    return found;
  }

  String titled(String personId, String male, String female, String neutral) =>
      _byGender(genderOf(personId), male, female, neutral);

  final treeRole = <String, String>{};
  if (effectiveRoleId.isNotEmpty) {
    final myParents = parentSet(effectiveRoleId);
    final mySpouses = spouseSet(effectiveRoleId);
    final myChildren = childSet(effectiveRoleId);
    final mySiblings = siblingsOf(effectiveRoleId);
    final grandparents = gather(myParents, parentSet);
    final greatGrandparents = gather(grandparents, parentSet);
    final parentSiblings = <String>{};
    for (final parentId in myParents) {
      for (final siblingId in siblingsOf(parentId)) {
        if (!myParents.contains(siblingId)) parentSiblings.add(siblingId);
      }
    }
    final parentSiblingSpouses = gather(parentSiblings, spouseSet);
    final cousins =
        gather({...parentSiblings, ...parentSiblingSpouses}, childSet);
    final cousinSpouses = gather(cousins, spouseSet);
    final siblingSpouses = gather(mySiblings, spouseSet);
    final niblings =
        gather({...mySiblings, ...siblingSpouses}, childSet);
    final childSpouses = gather(myChildren, spouseSet);
    final spouseParents = gather(mySpouses, parentSet);
    final grandparentSiblings = <String>{};
    for (final grandId in grandparents) {
      for (final siblingId in siblingsOf(grandId)) {
        if (!grandparents.contains(siblingId) &&
            !myParents.contains(siblingId)) {
          grandparentSiblings.add(siblingId);
        }
      }
    }
    final grandchildren = gather(myChildren, childSet);

    String relationToMe(String personId) {
      if (personId == effectiveRoleId) return 'You';
      if (myParents.contains(personId)) {
        return titled(personId, 'Father', 'Mother', 'Parent');
      }
      if (mySpouses.contains(personId)) {
        return titled(personId, 'Husband', 'Wife', 'Spouse');
      }
      if (myChildren.contains(personId)) {
        return titled(personId, 'Son', 'Daughter', 'Child');
      }
      if (mySiblings.contains(personId)) {
        return titled(personId, 'Brother', 'Sister', 'Sibling');
      }
      if (grandparents.contains(personId)) {
        return titled(personId, 'Grandfather', 'Grandmother', 'Grandparent');
      }
      if (greatGrandparents.contains(personId)) {
        return titled(
          personId,
          'Great-grandfather',
          'Great-grandmother',
          'Great-grandparent',
        );
      }
      if (parentSiblings.contains(personId) ||
          parentSiblingSpouses.contains(personId)) {
        return titled(personId, 'Uncle', 'Aunt', 'Uncle / Aunt');
      }
      if (cousins.contains(personId)) return 'Cousin';
      if (cousinSpouses.contains(personId)) return 'Cousin-in-law';
      if (siblingSpouses.contains(personId)) {
        return titled(
          personId,
          'Brother-in-law',
          'Sister-in-law',
          'Sibling-in-law',
        );
      }
      if (niblings.contains(personId)) {
        return titled(personId, 'Nephew', 'Niece', 'Nephew / Niece');
      }
      if (childSpouses.contains(personId)) {
        return titled(
          personId,
          'Son-in-law',
          'Daughter-in-law',
          'Child-in-law',
        );
      }
      if (spouseParents.contains(personId)) {
        return titled(
          personId,
          'Father-in-law',
          'Mother-in-law',
          'Parent-in-law',
        );
      }
      if (grandparentSiblings.contains(personId)) {
        return titled(
          personId,
          'Great-uncle',
          'Great-aunt',
          'Great-uncle / aunt',
        );
      }
      if (grandchildren.contains(personId)) {
        return titled(personId, 'Grandson', 'Granddaughter', 'Grandchild');
      }
      return 'Relative';
    }

    for (final member in members) {
      final personId = member['id'].toString();
      treeRole[personId] = relationToMe(personId);
    }
  }

  for (final edge in edges) {
    String? elder;
    String? younger;
    if (edge.type == 'grandfather' || edge.type == 'grandmother') {
      elder = edge.source;
      younger = edge.target;
    } else if (edge.type == 'grandson' || edge.type == 'granddaughter') {
      elder = edge.target;
      younger = edge.source;
    }
    if (elder == null ||
        younger == null ||
        (parents[younger] ?? const <String>{}).isNotEmpty) {
      continue;
    }
    final elderIndex = unionOf(elder);
    final youngerIndex = unionOf(younger);
    if (elderIndex < 0 ||
        youngerIndex < 0 ||
        elderIndex == youngerIndex) {
      continue;
    }
    final elderKey = unionId(unions[elderIndex]);
    final youngerKey = unionId(unions[youngerIndex]);
    if (parentKey.containsKey(youngerKey)) continue;
    parentKey[youngerKey] = elderKey;
    childKeys.putIfAbsent(elderKey, () => <String>{}).add(youngerKey);
  }

  final pos = <String, Offset>{};
  void place(String key, double left) {
    final width = measure(key);
    final kids = childrenOf(key);
    var cursor = left;
    if (kids.isNotEmpty) {
      final kidsWidth = kids.fold<double>(
            0,
            (sum, childKey) => sum + widthOf[childKey]!,
          ) +
          unitGap * (kids.length - 1);
      cursor = left + (width - kidsWidth) / 2;
      for (final childKey in kids) {
        place(childKey, cursor);
        cursor += widthOf[childKey]! + unitGap;
      }
    }
    final people = orderPeople(unionByKey[key] ?? {});
    final own = people.length * nodeW +
        (people.length > 1 ? people.length - 1 : 0) * spouseGap;
    var x = left + (width - own) / 2;
    final y = 20 + rowOf(key) * stride;
    for (final personId in people) {
      pos[personId] = Offset(x, y);
      x += nodeW + spouseGap;
    }
  }

  final roots = unionByKey.keys
      .where((key) => !parentKey.containsKey(key))
      .toList()
    ..sort((a, b) {
      final aPeople = orderPeople(unionByKey[a] ?? {});
      final bPeople = orderPeople(unionByKey[b] ?? {});
      return _personName(byId[aPeople.first])
          .compareTo(_personName(byId[bPeople.first]));
    });

  var rootLeft = gutter;
  for (final key in roots) {
    place(key, rootLeft);
    rootLeft += measure(key) + unitGap;
  }
  nudgeOverlaps(pos);

  var maxX = 240.0;
  var maxY = 240.0;
  for (final placePos in pos.values) {
    if (placePos.dx + nodeW + 28 > maxX) maxX = placePos.dx + nodeW + 28;
    if (placePos.dy + nodeH + 28 > maxY) maxY = placePos.dy + nodeH + 28;
  }

  Offset centerOfFn(String personId) {
    final placePos = pos[personId] ?? Offset.zero;
    return Offset(placePos.dx + nodeW / 2, placePos.dy);
  }

  double unionCenterX(String key) {
    final people =
        orderPeople(unionByKey[key] ?? {}).where(pos.containsKey).toList();
    if (people.isEmpty) return 0;
    final first = pos[people.first]!;
    final last = pos[people.last]!;
    return (first.dx + last.dx + nodeW) / 2;
  }

  final layoutEdges = <LayoutEdge>[];
  unionByKey.forEach((key, group) {
    final people = orderPeople(group).where(pos.containsKey).toList();
    for (var index = 0; index < people.length - 1; index++) {
      final left = pos[people[index]]!;
      final right = pos[people[index + 1]]!;
      final y = left.dy + nodeH / 2;
      layoutEdges.add(LayoutEdge(
        kind: 'spouse',
        points: [
          Offset(left.dx + nodeW, y),
          Offset(right.dx, y),
        ],
      ));
    }
    final kids = childrenOf(key);
    if (kids.isEmpty || people.isEmpty) return;
    final parentBottom = pos[people.first]!.dy + nodeH;
    final busY = parentBottom + rowGap / 2;
    final parentX = unionCenterX(key);
    final childXs = kids.map(unionCenterX).toList();
    final busLeft =
        [parentX, ...childXs].reduce((a, b) => a < b ? a : b);
    final busRight =
        [parentX, ...childXs].reduce((a, b) => a > b ? a : b);
    layoutEdges.add(LayoutEdge(
      kind: 'parent',
      points: [Offset(parentX, parentBottom), Offset(parentX, busY)],
    ));
    if (busRight - busLeft > 1) {
      layoutEdges.add(LayoutEdge(
        kind: 'sibling',
        points: [Offset(busLeft, busY), Offset(busRight, busY)],
      ));
    }
    for (var index = 0; index < kids.length; index++) {
      final childPeople = orderPeople(unionByKey[kids[index]] ?? {});
      if (childPeople.isEmpty) continue;
      final childTop = pos[childPeople.first]!.dy;
      layoutEdges.add(LayoutEdge(
        kind: 'parent',
        points: [
          Offset(childXs[index], busY),
          Offset(childXs[index], childTop),
        ],
      ));
    }
  });

  final nodes = members.map((member) {
    final id = member['id'].toString();
    final placePos = pos[id] ?? const Offset(28, 28);
    final uIndex = unionOf(id);
    final genKey = uIndex >= 0
        ? unionId(unions[uIndex])
        : unionId({id});
    return <String, dynamic>{
      ...member,
      'id': id,
      'x': placePos.dx,
      'y': placePos.dy,
      'w': nodeW,
      'h': nodeH,
      'generation': rowOf(genKey),
      'treeRole': treeRole[id] ?? '',
    };
  }).toList();

  Map<String, List<MemberMap>> kinOfFn(String id) {
    final key = id;
    final parentIds = parents[key] ?? const <String>{};
    final childIds = children[key] ?? const <String>{};
    final spouseIds = spouses[key] ?? const <String>{};
    final siblingIds = <String>{};
    for (final parentId in parentIds) {
      for (final childId in children[parentId] ?? const <String>{}) {
        if (childId != key) siblingIds.add(childId);
      }
    }
    List<MemberMap> pick(Set<String> set) => set
        .map((personId) => byId[personId])
        .whereType<MemberMap>()
        .toList();
    return {
      'parents': pick(parentIds),
      'children': pick(childIds),
      'spouses': pick(spouseIds),
      'siblings': pick(siblingIds),
    };
  }

  final focusGen = focusPersonId.isNotEmpty
      ? rowOf(
          unionOf(focusPersonId) >= 0
              ? unionId(unions[unionOf(focusPersonId)])
              : unionId({focusPersonId}),
        )
      : null;

  final generations = {
    for (final node in nodes) node['generation'] as int,
  }.toList()
    ..sort();

  final bands = generations.map((gen) {
    final color = _bandColors[gen % _bandColors.length];
    final delta = focusGen == null ? null : gen - focusGen;
    var badge = 'Generation ${gen + 1}';
    var title = gen == 0 ? 'Oldest generation' : 'Family';
    if (delta == 0) {
      badge = 'Generation 1';
      title = 'You & siblings';
    } else if (delta != null && delta < 0) {
      badge = 'Generation ${delta.abs() + 1}';
      title = _ancestorTitle(delta.abs());
    } else if (delta != null && delta > 0) {
      badge = 'Generation 1+';
      title = _descendantTitle(delta);
    }
    return LayoutBand(
      generation: gen,
      y: gen * stride,
      height: stride,
      badge: badge,
      title: title,
      bg: color['bg']!,
      ink: color['ink']!,
    );
  }).toList();

  if (bands.isNotEmpty) {
    final last = bands.last;
    final bandMax = last.y + last.height + 12;
    if (bandMax > maxY) maxY = bandMax;
  }

  return FamilyLayoutResult(
    nodes: nodes,
    edges: layoutEdges,
    bands: bands,
    width: maxX,
    height: maxY,
    kinOf: kinOfFn,
    centerOf: centerOfFn,
  );
}
