// Ego-centric family tree helpers (Dart port of tree_frontend egoTree.js).
// Member / relationship data is Map-based and camelCase + snake_case tolerant.

typedef MemberMap = Map<String, dynamic>;

String _norm(dynamic rel) {
  return (rel ?? '')
      .toString()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '');
}

MemberMap _profileOf(MemberMap m) {
  final info = m['profileInfo'] ?? m['profile_info'];
  if (info is Map) return Map<String, dynamic>.from(info);
  return <String, dynamic>{};
}

String? _anchorId(MemberMap m) {
  final p = _profileOf(m);
  final v = p['relatedTo'] ?? p['related_to'];
  return v?.toString();
}

String memberKey(MemberMap m) {
  return (m['userId'] ?? m['user_id'] ?? m['id']).toString();
}

String memberUserId(MemberMap m) => memberKey(m);

Map<String, MemberMap> _indexMembers(List<MemberMap> members) {
  final byKey = <String, MemberMap>{};
  for (final m in members) {
    final uid = m['userId'] ?? m['user_id'];
    if (uid != null) byKey[uid.toString()] = m;
    if (m['id'] != null) byKey[m['id'].toString()] = m;
  }
  return byKey;
}

/// Classify a relationship label into parent / child / sibling / spouse / root / other.
String linkTypeFromRelationship(dynamic relationship) {
  final r = _norm(relationship);
  if ([
    'mother',
    'father',
    'grandmother',
    'grandfather',
    'grandma',
    'grandpa',
  ].contains(r)) {
    return 'parent';
  }
  if (['son', 'daughter', 'nephew', 'niece'].contains(r)) return 'child';
  if (['brother', 'sister', 'cousin'].contains(r)) return 'sibling';
  if ([
        'spouse',
        'partner',
        'wife',
        'husband',
        'sister-in-law',
        'sisterinlaw',
        'brother-in-law',
        'brotherinlaw',
      ].contains(r) ||
      r.contains('wife') ||
      r.contains('husband') ||
      r.contains('inlaw') ||
      r.contains('in-law')) {
    return 'spouse';
  }
  if (r == 'sitecreator') return 'root';
  return 'other';
}

/// Normalize invite label when adding a relative of a sibling.
String relationshipForAnchor(
  dynamic relationship,
  MemberMap? anchorMember,
  MemberMap? focusMember,
) {
  final rel = (relationship ?? '').toString().trim();
  final r = _norm(rel);
  if (anchorMember == null) return rel.isEmpty ? 'Other' : rel;
  final anchorKey = memberKey(anchorMember);
  final focusKey = focusMember != null ? memberKey(focusMember) : null;
  if (focusKey != null && anchorKey == focusKey) return rel;

  final anchorRole = _norm(
    anchorMember['originalRelationship'] ??
        anchorMember['egoRole'] ??
        anchorMember['relationship'] ??
        '',
  );
  final isSiblingAnchor = ['brother', 'sister'].contains(anchorRole);
  if (!isSiblingAnchor) return rel;

  if (['spouse', 'partner', 'wife', 'husband'].contains(r) ||
      r.contains('wife') ||
      r.contains('husband')) {
    return anchorRole == 'sister' ? 'Brother-in-law' : 'Sister-in-law';
  }
  if (['son', 'daughter'].contains(r)) {
    return r == 'daughter' ? 'Niece' : 'Nephew';
  }
  return rel;
}

void _addEdge(Map<String, Set<String>> map, String? from, String? to) {
  if (from == null || to == null || from.isEmpty || to.isEmpty || from == to) {
    return;
  }
  final a = from;
  final b = to;
  map.putIfAbsent(a, () => <String>{}).add(b);
}

Set<String> _setOf(Map<String, Set<String>> map, String id) {
  return map[id] ?? <String>{};
}

String genderHint(dynamic rel) {
  final r = _norm(rel);
  if ([
    'mother',
    'sister',
    'daughter',
    'wife',
    'aunt',
    'grandmother',
    'spouse',
    'partner',
  ].contains(r)) {
    return 'female';
  }
  return 'male';
}

/// Kinship adjacency built from memberships.
class KinshipGraph {
  KinshipGraph({
    required this.byUserId,
    required this.byKey,
    required this.parentsOf,
    required this.childrenOf,
    required this.spousesOf,
    required this.siblingsOf,
    this.creatorId,
  });

  final Map<String, MemberMap> byUserId;
  final Map<String, MemberMap> byKey;
  final Map<String, Set<String>> parentsOf;
  final Map<String, Set<String>> childrenOf;
  final Map<String, Set<String>> spousesOf;
  final Map<String, Set<String>> siblingsOf;
  final String? creatorId;
}

/// Build parent/child/spouse/sibling edges from memberships.
KinshipGraph buildKinshipGraph([List<MemberMap> members = const []]) {
  final byKey = _indexMembers(members);
  final parentsOf = <String, Set<String>>{};
  final childrenOf = <String, Set<String>>{};
  final spousesOf = <String, Set<String>>{};
  final siblingsOf = <String, Set<String>>{};

  MemberMap? creator;
  for (final m in members) {
    if (_norm(m['relationship']) == 'sitecreator') {
      creator = m;
      break;
    }
  }
  final creatorId = creator != null ? memberKey(creator) : null;

  for (final m in members) {
    final uid = memberKey(m);
    final rel = _norm(m['relationship']);
    final profile = _profileOf(m);
    final link = (profile['linkType'] ??
            profile['link_type'] ??
            linkTypeFromRelationship(m['relationship']))
        .toString();
    final relatedRaw = _anchorId(m);
    final relatedMember = relatedRaw != null ? byKey[relatedRaw] : null;
    final related =
        relatedMember != null ? memberKey(relatedMember) : null;

    if (related != null) {
      if (link == 'child' ||
          ['son', 'daughter', 'nephew', 'niece'].contains(rel)) {
        _addEdge(childrenOf, related, uid);
        _addEdge(parentsOf, uid, related);
      } else if (link == 'parent' ||
          [
            'mother',
            'father',
            'grandmother',
            'grandfather',
            'aunt',
            'uncle',
          ].contains(rel)) {
        if (['aunt', 'uncle'].contains(rel) && link != 'parent') {
          _addEdge(siblingsOf, uid, related);
          _addEdge(siblingsOf, related, uid);
        } else {
          _addEdge(childrenOf, uid, related);
          _addEdge(parentsOf, related, uid);
        }
      } else if (link == 'spouse' ||
          [
            'spouse',
            'partner',
            'wife',
            'husband',
            'sister-in-law',
            'sisterinlaw',
            'brother-in-law',
            'brotherinlaw',
          ].contains(rel)) {
        _addEdge(spousesOf, uid, related);
        _addEdge(spousesOf, related, uid);
      } else if (link == 'sibling' ||
          ['brother', 'sister', 'cousin'].contains(rel)) {
        _addEdge(siblingsOf, uid, related);
        _addEdge(siblingsOf, related, uid);
      }
    }

    if (creatorId != null && uid != creatorId && related == null) {
      if (['mother', 'father'].contains(rel)) {
        _addEdge(childrenOf, uid, creatorId);
        _addEdge(parentsOf, creatorId, uid);
      } else if ([
        'grandmother',
        'grandfather',
        'grandma',
        'grandpa',
      ].contains(rel)) {
        _addEdge(childrenOf, uid, creatorId);
      } else if (['brother', 'sister'].contains(rel)) {
        _addEdge(siblingsOf, uid, creatorId);
        _addEdge(siblingsOf, creatorId, uid);
      } else if (['son', 'daughter'].contains(rel)) {
        _addEdge(childrenOf, creatorId, uid);
        _addEdge(parentsOf, uid, creatorId);
      } else if (['spouse', 'partner', 'wife', 'husband'].contains(rel)) {
        _addEdge(spousesOf, uid, creatorId);
        _addEdge(spousesOf, creatorId, uid);
      } else if (['uncle', 'aunt'].contains(rel)) {
        MemberMap? mother;
        MemberMap? father;
        for (final x in members) {
          final xr = _norm(x['relationship']);
          if (xr == 'mother') mother = x;
          if (['father', 'dad'].contains(xr)) father = x;
        }
        final parent = father ?? mother;
        if (parent != null) {
          final pid = memberKey(parent);
          _addEdge(siblingsOf, uid, pid);
          _addEdge(siblingsOf, pid, uid);
        }
      }
    }
  }

  if (creatorId != null && parentsOf.containsKey(creatorId)) {
    final creatorParents = [...parentsOf[creatorId]!];
    final sibs = siblingsOf[creatorId] ?? <String>{};
    for (final sibId in sibs) {
      for (final pid in creatorParents) {
        _addEdge(parentsOf, sibId, pid);
        _addEdge(childrenOf, pid, sibId);
      }
    }
  }

  for (final m in members) {
    final uid = memberKey(m);
    final rel = _norm(m['relationship']);
    final isSpouseLike = [
          'spouse',
          'partner',
          'wife',
          'husband',
          'sister-in-law',
          'sisterinlaw',
          'brother-in-law',
          'brotherinlaw',
        ].contains(rel) ||
        rel.contains('wife') ||
        rel.contains('husband');
    if (!isSpouseLike) continue;

    final relatedRaw = _anchorId(m);
    final relatedMember = relatedRaw != null ? byKey[relatedRaw] : null;
    if (relatedMember == null) continue;
    final rid = memberKey(relatedMember);
    final rrel = _norm(relatedMember['relationship']);
    final relatedIsSibling = ['brother', 'sister'].contains(rrel) ||
        (creatorId != null &&
            (siblingsOf[creatorId] ?? <String>{}).contains(rid));

    if (!relatedIsSibling) continue;

    _addEdge(spousesOf, uid, rid);
    _addEdge(spousesOf, rid, uid);
    if (creatorId != null && creatorId != rid) {
      spousesOf[uid]?.remove(creatorId);
      spousesOf[creatorId]?.remove(uid);
    }
  }

  for (final m in members) {
    final uid = memberKey(m);
    final rel = _norm(m['relationship']);
    final isInLawWife = ['sister-in-law', 'sisterinlaw'].contains(rel);
    final isInLawHusband = ['brother-in-law', 'brotherinlaw'].contains(rel);
    if (!isInLawWife && !isInLawHusband) continue;
    if ((spousesOf[uid] ?? <String>{}).isNotEmpty) continue;

    final relatedRaw = _anchorId(m);
    final relatedMember = relatedRaw != null ? byKey[relatedRaw] : null;
    if (relatedMember != null) {
      final rid = memberKey(relatedMember);
      final rrel = _norm(relatedMember['relationship']);
      if (['brother', 'sister'].contains(rrel)) {
        _addEdge(spousesOf, uid, rid);
        _addEdge(spousesOf, rid, uid);
        continue;
      }
    }

    if (isInLawWife && creatorId != null) {
      final brothers = members
          .where((x) =>
              _norm(x['relationship']) == 'brother' && memberKey(x) != uid)
          .toList();
      if (brothers.length == 1) {
        final bid = memberKey(brothers[0]);
        _addEdge(spousesOf, uid, bid);
        _addEdge(spousesOf, bid, uid);
      }
    }
    if (isInLawHusband && creatorId != null) {
      final sisters = members
          .where((x) =>
              _norm(x['relationship']) == 'sister' && memberKey(x) != uid)
          .toList();
      if (sisters.length == 1) {
        final sid = memberKey(sisters[0]);
        _addEdge(spousesOf, uid, sid);
        _addEdge(spousesOf, sid, uid);
      }
    }
  }

  for (final m in members) {
    final uid = memberKey(m);
    final rel = _norm(m['relationship']);
    if (!['nephew', 'niece'].contains(rel)) continue;
    if ((parentsOf[uid] ?? <String>{}).isNotEmpty) continue;

    final relatedRaw = _anchorId(m);
    final relatedMember = relatedRaw != null ? byKey[relatedRaw] : null;
    if (relatedMember != null) {
      final rid = memberKey(relatedMember);
      final rrel = _norm(relatedMember['relationship']);
      if (['brother', 'sister', 'uncle', 'aunt'].contains(rrel)) {
        _addEdge(childrenOf, rid, uid);
        _addEdge(parentsOf, uid, rid);
      }
    }
  }

  MemberMap? mother;
  MemberMap? father;
  MemberMap? gm;
  MemberMap? gf;
  for (final m in members) {
    final r = _norm(m['relationship']);
    if (r == 'mother') mother = m;
    if (['father', 'dad'].contains(r)) father = m;
    if (['grandmother', 'grandma'].contains(r)) gm = m;
    if (['grandfather', 'grandpa'].contains(r)) gf = m;
  }
  for (final parent in [mother, father].whereType<MemberMap>()) {
    final pid = memberKey(parent);
    if (gm != null) {
      final gid = memberKey(gm);
      _addEdge(childrenOf, gid, pid);
      _addEdge(parentsOf, pid, gid);
    }
    if (gf != null) {
      final gid = memberKey(gf);
      _addEdge(childrenOf, gid, pid);
      _addEdge(parentsOf, pid, gid);
    }
  }

  return KinshipGraph(
    byUserId: byKey,
    byKey: byKey,
    parentsOf: parentsOf,
    childrenOf: childrenOf,
    spousesOf: spousesOf,
    siblingsOf: siblingsOf,
    creatorId: creatorId,
  );
}

MemberMap _copyMember(MemberMap m, [Map<String, dynamic>? overrides]) {
  return {...m, ...?overrides};
}

/// Assign egoRole for each member relative to [focusUserId].
EgoViewResult buildEgoView(
  List<MemberMap> members, [
  String? focusUserId,
]) {
  if (members.isEmpty) {
    return EgoViewResult(
      focus: null,
      viewMembers: const [],
      focusUserId: null,
    );
  }

  final graph = buildKinshipGraph(members);
  MemberMap? focus;
  if (focusUserId != null) {
    focus = graph.byUserId[focusUserId];
  }
  focus ??= members.cast<MemberMap?>().firstWhere(
        (m) => _norm(m!['relationship']) == 'sitecreator',
        orElse: () => null,
      );
  focus ??= members.first;

  final focusId = memberKey(focus);
  final parentIds = [..._setOf(graph.parentsOf, focusId)];
  final childIds = [..._setOf(graph.childrenOf, focusId)];
  final spouseIds = [..._setOf(graph.spousesOf, focusId)];
  final siblingIds = [..._setOf(graph.siblingsOf, focusId)];

  final grandparentIds = <String>{};
  for (final pid in parentIds) {
    grandparentIds.addAll(_setOf(graph.parentsOf, pid));
  }

  final auntUncleIds = <String>{};
  for (final pid in parentIds) {
    for (final id in _setOf(graph.siblingsOf, pid)) {
      if (id != focusId && !parentIds.contains(id)) auntUncleIds.add(id);
    }
  }
  for (final m in members) {
    final r = _norm(m['relationship']);
    if (['aunt', 'uncle'].contains(r)) auntUncleIds.add(memberKey(m));
  }

  final cousinIds = <String>{};
  for (final aid in auntUncleIds) {
    for (final cid in _setOf(graph.childrenOf, aid)) {
      if (cid != focusId &&
          !siblingIds.contains(cid) &&
          !childIds.contains(cid)) {
        cousinIds.add(cid);
      }
    }
    for (final spouseId in _setOf(graph.spousesOf, aid)) {
      for (final cid in _setOf(graph.childrenOf, spouseId)) {
        if (cid != focusId &&
            !siblingIds.contains(cid) &&
            !childIds.contains(cid)) {
          cousinIds.add(cid);
        }
      }
    }
  }
  for (final m in members) {
    if (_norm(m['relationship']) == 'cousin') cousinIds.add(memberKey(m));
  }

  final cousinChildIds = <String>{};
  for (final cid in cousinIds) {
    for (final kid in _setOf(graph.childrenOf, cid)) {
      if (kid != focusId &&
          !cousinIds.contains(kid) &&
          !childIds.contains(kid) &&
          !siblingIds.contains(kid)) {
        cousinChildIds.add(kid);
      }
    }
  }

  final cousinGrandchildIds = <String>{};
  for (final cid in cousinChildIds) {
    for (final kid in _setOf(graph.childrenOf, cid)) {
      if (kid != focusId &&
          !cousinIds.contains(kid) &&
          !cousinChildIds.contains(kid) &&
          !childIds.contains(kid)) {
        cousinGrandchildIds.add(kid);
      }
    }
  }

  final roleById = <String, String>{};
  roleById[focusId] = 'SiteCreator';

  String pickParentRole(MemberMap m, String fallbackFemale, String fallbackMale) {
    final r = _norm(m['relationship']);
    if (['mother', 'father', 'grandmother', 'grandfather'].contains(r)) {
      if (r.contains('mother') || r.contains('grandma')) return fallbackFemale;
      if (r.contains('father') || r.contains('grandpa')) return fallbackMale;
    }
    return genderHint(m['relationship']) == 'female'
        ? fallbackFemale
        : fallbackMale;
  }

  for (final id in parentIds) {
    final m = graph.byUserId[id];
    if (m == null) continue;
    roleById[id] = pickParentRole(m, 'Mother', 'Father');
  }

  for (final id in grandparentIds) {
    final m = graph.byUserId[id];
    if (m == null) continue;
    roleById[id] = pickParentRole(m, 'Grandmother', 'Grandfather');
  }

  for (final id in siblingIds) {
    final m = graph.byUserId[id];
    if (m == null) continue;
    final r = _norm(m['relationship']);
    if (r == 'sister' || genderHint(m['relationship']) == 'female') {
      roleById[id] = 'Sister';
    } else {
      roleById[id] = 'Brother';
    }
  }

  final siblingSpouseIds = <String>{};
  final siblingChildIds = <String>{};
  for (final sid in siblingIds) {
    for (final spid in _setOf(graph.spousesOf, sid)) {
      if (spid != focusId && !siblingIds.contains(spid)) {
        siblingSpouseIds.add(spid);
      }
    }
    for (final cid in _setOf(graph.childrenOf, sid)) {
      if (cid != focusId &&
          !childIds.contains(cid) &&
          !siblingIds.contains(cid) &&
          !cousinIds.contains(cid)) {
        siblingChildIds.add(cid);
      }
    }
  }
  for (final spid in [...siblingSpouseIds]) {
    for (final cid in _setOf(graph.childrenOf, spid)) {
      if (cid != focusId &&
          !childIds.contains(cid) &&
          !siblingIds.contains(cid) &&
          !cousinIds.contains(cid)) {
        siblingChildIds.add(cid);
      }
    }
  }

  for (final m in members) {
    final id = memberKey(m);
    final r = _norm(m['relationship']);
    if ([
      'sister-in-law',
      'sisterinlaw',
      'brother-in-law',
      'brotherinlaw',
    ].contains(r)) {
      siblingSpouseIds.add(id);
    }
    if (['nephew', 'niece'].contains(r)) siblingChildIds.add(id);

    final relatedRaw = _anchorId(m);
    if (relatedRaw != null &&
        (siblingIds.contains(relatedRaw) ||
            siblingIds.any((sid) {
              final sib = graph.byUserId[sid];
              return sib != null &&
                  (sib['id']?.toString() == relatedRaw ||
                      memberKey(sib) == relatedRaw);
            })) &&
        (['spouse', 'partner', 'wife', 'husband'].contains(r) ||
            r.contains('wife') ||
            r.contains('husband'))) {
      siblingSpouseIds.add(id);
    }
  }

  for (final id in siblingSpouseIds) {
    final m = graph.byUserId[id] ??
        members.cast<MemberMap?>().firstWhere(
              (x) => x != null && memberKey(x) == id,
              orElse: () => null,
            );
    if (m == null) continue;
    final r = _norm(m['relationship']);
    if (r == 'sister-in-law' ||
        r == 'sisterinlaw' ||
        r.contains('wife') ||
        genderHint(m['relationship']) == 'female') {
      roleById[id] = 'Sister-in-law';
    } else {
      roleById[id] = 'Brother-in-law';
    }
  }

  for (final id in spouseIds) {
    if (siblingSpouseIds.contains(id)) continue;
    roleById[id] = 'Spouse';
  }

  for (final id in siblingChildIds) {
    final m = graph.byUserId[id];
    if (m == null) continue;
    final female = genderHint(m['relationship']) == 'female' ||
        ['daughter', 'niece'].contains(_norm(m['relationship']));
    roleById[id] = female ? 'Niece' : 'Nephew';
  }

  for (final id in childIds) {
    if (cousinIds.contains(id) || siblingChildIds.contains(id)) continue;
    final m = graph.byUserId[id];
    if (m == null) continue;
    final r = _norm(m['relationship']);
    if (r == 'daughter' || genderHint(m['relationship']) == 'female') {
      roleById[id] = 'Daughter';
    } else {
      roleById[id] = 'Son';
    }
  }

  for (final id in auntUncleIds) {
    if (roleById.containsKey(id) &&
        ['Mother', 'Father'].contains(roleById[id])) {
      continue;
    }
    final m = graph.byUserId[id];
    if (m == null) continue;
    final r = _norm(m['relationship']);
    if (r == 'aunt' || genderHint(m['relationship']) == 'female') {
      roleById[id] = 'Aunt';
    } else {
      roleById[id] = 'Uncle';
    }
  }

  for (final id in cousinIds) {
    roleById[id] = 'Cousin';
  }

  for (final id in cousinChildIds) {
    if (roleById.containsKey(id)) continue;
    final m = graph.byUserId[id];
    if (m == null) continue;
    final female = genderHint(m['relationship']) == 'female' ||
        _norm(m['relationship']) == 'daughter';
    roleById[id] = female ? "Cousin's Daughter" : "Cousin's Son";
  }

  for (final id in cousinGrandchildIds) {
    if (roleById.containsKey(id)) continue;
    roleById[id] = 'Relative';
  }

  if (focusId == graph.creatorId ||
      _norm(focus['relationship']) == 'sitecreator') {
    for (final m in members) {
      final id = memberKey(m);
      roleById.putIfAbsent(id, () => (m['relationship'] ?? '').toString());
    }
  } else {
    final focusIsSiblingOfCreator = graph.creatorId != null &&
        _setOf(graph.siblingsOf, graph.creatorId!).contains(focusId);

    for (final m in members) {
      final id = memberKey(m);
      if (roleById.containsKey(id)) continue;
      final r = _norm(m['relationship']);

      if (focusIsSiblingOfCreator && r == 'sitecreator') {
        roleById[id] =
            genderHint(m['relationship']) == 'female' ? 'Sister' : 'Brother';
        continue;
      }

      if (focusIsSiblingOfCreator &&
          ['son', 'daughter'].contains(r) &&
          !childIds.contains(id)) {
        roleById[id] = r == 'daughter' ? 'Niece' : 'Nephew';
        continue;
      }

      roleById[id] = (m['relationship'] ?? '').toString();
    }
  }

  final viewMembers = members.map((m) {
    final id = memberKey(m);
    final egoRole = roleById[id] ?? (m['relationship'] ?? '').toString();
    return _copyMember(m, {
      'egoRole': egoRole,
      'relationship': egoRole,
      'originalRelationship': m['relationship'],
      'isFocus': id == focusId,
    });
  }).toList();

  final keep = <String>{
    focusId,
    ...parentIds,
    ...grandparentIds,
    ...siblingIds,
    ...spouseIds,
    ...childIds,
    ...auntUncleIds,
    ...cousinIds,
    ...cousinChildIds,
    ...cousinGrandchildIds,
    ...siblingSpouseIds,
    ...siblingChildIds,
  };

  for (final m in viewMembers) {
    final id = memberKey(m);
    if (roleById.containsKey(id)) keep.add(id);
  }

  var filtered =
      viewMembers.where((m) => keep.contains(memberKey(m))).toList();

  filtered = filtered.map((m) {
    final id = memberKey(m);
    final role = _norm(m['relationship']);
    if (['son', 'daughter'].contains(role) &&
        !childIds.contains(id) &&
        id != focusId) {
      if (siblingIds.contains(focusId) ||
          (graph.creatorId != null &&
              _setOf(graph.siblingsOf, graph.creatorId!).contains(focusId))) {
        final label = role == 'daughter' ? 'Niece' : 'Nephew';
        return _copyMember(m, {
          'relationship': label,
          'egoRole': label,
        });
      }
    }
    return m;
  }).toList();

  if (focusId != graph.creatorId) {
    filtered = filtered.map((m) {
      final id = memberKey(m);
      if (childIds.contains(id)) {
        final female =
            genderHint(m['originalRelationship'] ?? m['relationship']) ==
                    'female' ||
                _norm(m['originalRelationship']) == 'daughter';
        final label = female ? 'Daughter' : 'Son';
        return _copyMember(m, {
          'relationship': label,
          'egoRole': label,
        });
      }
      return m;
    }).toList();
  }

  return EgoViewResult(
    focus: focus,
    focusUserId: focusId,
    viewMembers: filtered,
    allMembers: viewMembers,
    graph: graph,
    branches: {
      'auntUncleIds': [...auntUncleIds],
      'cousinIds': [...cousinIds],
      'cousinChildIds': [...cousinChildIds],
      'cousinGrandchildIds': [...cousinGrandchildIds],
    },
    stats: {
      'parents': parentIds.length,
      'children': childIds.length,
      'siblings': siblingIds.length,
      'cousins': cousinIds.length,
    },
  );
}

class EgoViewResult {
  EgoViewResult({
    required this.focus,
    required this.viewMembers,
    this.focusUserId,
    this.allMembers = const [],
    this.graph,
    this.branches = const {},
    this.stats = const {},
  });

  final MemberMap? focus;
  final String? focusUserId;
  final List<MemberMap> viewMembers;
  final List<MemberMap> allMembers;
  final KinshipGraph? graph;
  final Map<String, List<String>> branches;
  final Map<String, int> stats;
}

String? resolveDefaultFocusUserId(
  List<MemberMap> members,
  Map<String, dynamic>? authUser,
) {
  if (authUser == null) return null;
  for (final m in members) {
    if (m['userId']?.toString() == authUser['id']?.toString()) {
      return m['userId']?.toString();
    }
  }
  final authEmail = authUser['email']?.toString().toLowerCase();
  if (authEmail != null) {
    for (final m in members) {
      final email = m['email']?.toString().toLowerCase();
      if (email != null && email == authEmail) {
        return m['userId']?.toString();
      }
    }
  }
  for (final m in members) {
    if (_norm(m['relationship']) == 'sitecreator') {
      return memberKey(m);
    }
  }
  return members.isNotEmpty ? memberKey(members.first) : null;
}

/// Upward ancestry chain from focus.
List<MemberMap> getAncestryChain(
  List<MemberMap> members, [
  String? focusUserId,
  int maxDepth = 4,
]) {
  final graph = buildKinshipGraph(members);
  var id = focusUserId ??
      graph.creatorId ??
      (members.isNotEmpty ? memberKey(members.first) : null);
  if (id == null) return [];

  final chain = <MemberMap>[];
  final visited = <String>{};

  MemberMap? pickParent(String currentId, int depth) {
    final parents = [..._setOf(graph.parentsOf, currentId)];
    for (final pid in parents) {
      final p = graph.byUserId[pid];
      if (p == null) continue;
      if (genderHint(p['relationship']) == 'male' ||
          ['father', 'dad', 'grandfather', 'grandpa']
              .contains(_norm(p['relationship']))) {
        return p;
      }
    }
    if (parents.isNotEmpty) return graph.byUserId[parents.first];
    if (depth == 0) {
      for (final m in members) {
        if (['father', 'dad'].contains(_norm(m['relationship']))) return m;
      }
      for (final m in members) {
        if (['mother', 'mom'].contains(_norm(m['relationship']))) return m;
      }
      return null;
    }
    if (depth == 1) {
      for (final m in members) {
        if (['grandfather', 'grandpa'].contains(_norm(m['relationship']))) {
          return m;
        }
      }
      for (final m in members) {
        if (['grandmother', 'grandma'].contains(_norm(m['relationship']))) {
          return m;
        }
      }
      return null;
    }
    return null;
  }

  for (var depth = 0; depth < maxDepth; depth++) {
    if (id == null || visited.contains(id)) break;
    visited.add(id);
    final member = graph.byUserId[id];
    if (member == null) break;

    final info = _profileOf(member);
    var roleLabel = 'You (ME)';
    if (depth == 1) {
      roleLabel =
          genderHint(member['relationship']) == 'female' ? 'Mother' : 'Father';
    } else if (depth == 2) {
      roleLabel = genderHint(member['relationship']) == 'female'
          ? 'Grandmother'
          : 'Grandfather';
    } else if (depth >= 3) {
      roleLabel = genderHint(member['relationship']) == 'female'
          ? 'Great-grandmother'
          : 'Great-grandfather';
    }

    chain.add({
      'depth': depth,
      'roleLabel': roleLabel,
      'userId': memberKey(member),
      'name': member['name'],
      'avatar': info['avatar'] ?? info['profileImage'],
      'member': member,
    });

    final next = pickParent(id, depth);
    id = next != null ? memberKey(next) : null;
  }

  return chain;
}

MemberMap enrichMemberProfile(MemberMap? member) {
  if (member == null) return <String, dynamic>{};
  final info = _profileOf(member);
  final isAlive = member['isAlive'] != false &&
      info['isAlive'] != false &&
      info['is_alive'] != false;
  return {
    ...member,
    'avatar': info['avatar'] ?? info['profileImage'] ?? member['avatar'],
    'location': info['location'] ?? member['location'] ?? '',
    'phone': info['phone'] ?? info['contactNumber'] ?? member['phone'] ?? '',
    'educations': info['educations'] is List
        ? info['educations']
        : (member['educations'] ?? []),
    'jobs': info['jobs'] is List ? info['jobs'] : (member['jobs'] ?? []),
    'education': info['education'] ?? member['education'] ?? '',
    'occupation': info['occupation'] ?? member['occupation'] ?? '',
    'workplace': info['workplace'] ?? member['workplace'] ?? '',
    'bloodGroup':
        info['bloodGroup'] ?? info['blood_group'] ?? member['bloodGroup'] ?? '',
    'about': info['about'] ?? member['about'] ?? '',
    'isAlive': isAlive,
  };
}

String roleLabelForAncestorLevel(int level, MemberMap? member) {
  final rel =
      _norm(member?['relationship'] ?? member?['originalRelationship'] ?? '');
  if (level == 1) {
    if (['uncle', 'aunt'].contains(rel)) {
      return rel == 'aunt' ? 'Aunt' : 'Uncle';
    }
    if (['mother', 'mom'].contains(rel)) return 'Mother';
    if (['father', 'dad'].contains(rel)) return 'Father';
    return genderHint(member?['relationship']) == 'female' ? 'Mother' : 'Father';
  }
  final female = genderHint(member?['relationship']) == 'female';
  if (level == 2) return female ? 'Grandmother' : 'Grandfather';
  if (level == 3) {
    return female ? 'Great-grandmother' : 'Great-grandfather';
  }
  if (level >= 4) {
    final prefix = List.filled(level - 2, 'Great').join('-');
    return female ? '$prefix-grandmother' : '$prefix-grandfather';
  }
  return (member?['relationship'] ?? 'Member').toString();
}

/// Couple placeholder labels for ancestor level (1 = parents, 2 = grandparents, …).
Map<String, String> ancestorCoupleLabels(dynamic level) {
  final n = int.tryParse(level.toString()) ?? 1;
  if (n <= 1) {
    return {
      'male': 'Father',
      'female': 'Mother',
      'title': 'Parents',
      'short': 'Parents',
    };
  }
  if (n == 2) {
    return {
      'male': 'Grandfather',
      'female': 'Grandmother',
      'title': 'Grandparents',
      'short': 'Grandparents',
    };
  }
  if (n == 3) {
    return {
      'male': 'Great Grandfather',
      'female': 'Great Grandmother',
      'title': 'Great-grandparents',
      'short': 'Great-grandparents',
    };
  }
  final greats = List.filled(n - 2, 'Great').join(' ');
  return {
    'male': '$greats Grandfather',
    'female': '$greats Grandmother',
    'title': '$greats Grandparents',
    'short': 'Gen $n ancestors',
  };
}

Map<String, String> generationBadgeMeta(int level) {
  final display = level + 1;
  final ord = display == 1
      ? '1st'
      : display == 2
          ? '2nd'
          : display == 3
              ? '3rd'
              : '${display}th';
  if (level == 0) {
    return {'title': '$ord Generation', 'subtitle': '(You / Cousins)'};
  }
  if (level == 1) {
    return {'title': '$ord Generation', 'subtitle': '(Parents / Uncles)'};
  }
  if (level == 2) {
    return {'title': '$ord Generation', 'subtitle': '(Grandparents)'};
  }
  if (level == 3) {
    return {'title': '$ord Generation', 'subtitle': '(Great Grandparents)'};
  }
  final labels = ancestorCoupleLabels(level);
  return {'title': '$ord Generation', 'subtitle': '(${labels['short']})'};
}

String _ancestorGenerationTitle(int level) {
  if (level == 1) return 'Generation 1 · Parents & Uncles';
  if (level == 2) return 'Generation 2 · Grandparents';
  if (level == 3) return 'Generation 3 · Great-grandparents';
  if (level >= 4) {
    final labels = ancestorCoupleLabels(level);
    return 'Generation $level · ${labels['title']}';
  }
  return 'Generation $level';
}

String _ancestorGenerationSubtitle(int level) {
  if (level == 1) return 'Mother · Father · Uncle · Aunt';
  if (level == 2) return 'Grandmother · Grandfather';
  if (level == 3) return 'Great-grandmother · Great-grandfather';
  if (level >= 4) {
    final labels = ancestorCoupleLabels(level);
    return '${labels['female']} · ${labels['male']}';
  }
  return 'Ancestors';
}

List<MemberMap> _sortFemaleFirst(List<MemberMap> list) {
  final copy = [...list];
  copy.sort((a, b) {
    final af = genderHint(a['relationship']) == 'female' ? 0 : 1;
    final bf = genderHint(b['relationship']) == 'female' ? 0 : 1;
    return af.compareTo(bf);
  });
  return copy;
}

List<MemberMap> _uniqueMembers(List<MemberMap> list) {
  final seen = <String>{};
  return list.where((m) {
    final id = memberUserId(m);
    if (seen.contains(id)) return false;
    seen.add(id);
    return true;
  }).toList();
}

/// Group members into generation layers relative to focus person.
GenerationLayersResult buildGenerationLayers(
  List<MemberMap> members, [
  String? focusUserId,
  int maxUp = 4,
  int maxDown = 2,
]) {
  if (members.isEmpty) {
    return GenerationLayersResult(
      focusId: null,
      layers: const [],
      byUserId: {},
    );
  }

  final graph = buildKinshipGraph(members);
  final focusId = focusUserId ??
      graph.creatorId ??
      memberUserId(members.first);

  final ancestorLevel = <String, int>{};
  var frontier = [focusId];
  for (var level = 1; level <= maxUp; level++) {
    final next = <String>[];
    for (final id in frontier) {
      for (final pid in _setOf(graph.parentsOf, id)) {
        if (!ancestorLevel.containsKey(pid)) {
          ancestorLevel[pid] = level;
          next.add(pid);
        }
      }
    }
    frontier = next;
    if (frontier.isEmpty) break;
  }

  final descendantLevel = <String, int>{};
  frontier = [focusId];
  for (var level = 1; level <= maxDown; level++) {
    final next = <String>[];
    for (final id in frontier) {
      for (final cid in _setOf(graph.childrenOf, id)) {
        if (!descendantLevel.containsKey(cid)) {
          descendantLevel[cid] = level;
          next.add(cid);
        }
      }
    }
    frontier = next;
    if (frontier.isEmpty) break;
  }

  final parentIds = [..._setOf(graph.parentsOf, focusId)];

  final auntUncleIds = <String>{};
  for (final pid in parentIds) {
    for (final id in _setOf(graph.siblingsOf, pid)) {
      if (id != focusId && !parentIds.contains(id)) auntUncleIds.add(id);
    }
  }
  for (final m in members) {
    final r = _norm(m['relationship']);
    if (['aunt', 'uncle'].contains(r)) auntUncleIds.add(memberKey(m));
  }
  for (final aid in [...auntUncleIds]) {
    for (final sid in _setOf(graph.spousesOf, aid)) {
      if (!parentIds.contains(sid) && sid != focusId) auntUncleIds.add(sid);
    }
  }

  final cousinIds = <String>{};
  for (final aid in auntUncleIds) {
    for (final cid in _setOf(graph.childrenOf, aid)) {
      if (cid != focusId && !parentIds.contains(cid)) cousinIds.add(cid);
    }
  }
  for (final m in members) {
    if (_norm(m['relationship']) == 'cousin') cousinIds.add(memberKey(m));
  }

  final selfIds = <String>{focusId};
  selfIds.addAll(_setOf(graph.siblingsOf, focusId));
  selfIds.addAll(_setOf(graph.spousesOf, focusId));
  for (final sid in _setOf(graph.siblingsOf, focusId)) {
    for (final spid in _setOf(graph.spousesOf, sid)) {
      if (spid != focusId) selfIds.add(spid);
    }
  }
  for (final m in members) {
    final r = _norm(m['relationship']);
    if ([
      'sister-in-law',
      'sisterinlaw',
      'brother-in-law',
      'brotherinlaw',
    ].contains(r)) {
      selfIds.add(memberKey(m));
    }
  }
  selfIds.addAll(cousinIds);

  List<MemberMap> flatByRel(List<String> labels) => members
      .where((m) => labels.contains(_norm(m['relationship'])))
      .toList();

  List<MemberMap> pickAtLevel(int level) {
    final fromGraph = <MemberMap>[];
    ancestorLevel.forEach((uid, lvl) {
      if (lvl == level) {
        final m = graph.byUserId[uid];
        if (m != null) {
          fromGraph.add({
            ...enrichMemberProfile(m),
            'generationLevel': level,
            'generationRole': roleLabelForAncestorLevel(level, m),
          });
        }
      }
    });

    if (level == 1) {
      for (final uid in auntUncleIds) {
        final m = graph.byUserId[uid] ??
            members.cast<MemberMap?>().firstWhere(
                  (x) => x != null && memberUserId(x) == uid,
                  orElse: () => null,
                );
        if (m == null) continue;
        if (fromGraph.any((x) => memberUserId(x) == uid)) continue;
        final relForRole = ['aunt', 'uncle'].contains(_norm(m['relationship']))
            ? m['relationship']
            : (genderHint(m['relationship']) == 'female' ? 'aunt' : 'uncle');
        fromGraph.add({
          ...enrichMemberProfile(m),
          'generationLevel': 1,
          'generationRole': roleLabelForAncestorLevel(1, {
            ...m,
            'relationship': relForRole,
          }),
        });
      }
      for (final m in flatByRel(['uncle', 'aunt'])) {
        final uid = memberUserId(m);
        if (fromGraph.any((x) => memberUserId(x) == uid)) continue;
        fromGraph.add({
          ...enrichMemberProfile(m),
          'generationLevel': 1,
          'generationRole': roleLabelForAncestorLevel(1, m),
        });
      }
    }

    if (fromGraph.isNotEmpty) return _uniqueMembers(fromGraph);

    if (level == 1) {
      return _uniqueMembers(
        flatByRel(['mother', 'mom', 'father', 'dad', 'uncle', 'aunt'])
            .map((m) => {
                  ...enrichMemberProfile(m),
                  'generationLevel': 1,
                  'generationRole': roleLabelForAncestorLevel(1, m),
                })
            .toList(),
      );
    }
    if (level == 2) {
      return _uniqueMembers(
        flatByRel(['grandmother', 'grandma', 'grandfather', 'grandpa'])
            .map((m) => {
                  ...enrichMemberProfile(m),
                  'generationLevel': 2,
                  'generationRole': roleLabelForAncestorLevel(2, m),
                })
            .toList(),
      );
    }
    if (level >= 3) {
      final labels = ancestorCoupleLabels(level);
      final maleKeys = [
        _norm(labels['male']),
        _norm(labels['male']!.replaceAll(RegExp(r'\s+'), '-')),
      ];
      final femaleKeys = [
        _norm(labels['female']),
        _norm(labels['female']!.replaceAll(RegExp(r'\s+'), '-')),
      ];
      if (level == 3) {
        maleKeys.addAll(['greatgrandfather', 'great-grandfather']);
        femaleKeys.addAll(['greatgrandmother', 'great-grandmother']);
      }
      return _uniqueMembers(
        members
            .where((m) {
              final r = _norm(m['relationship']);
              return maleKeys.contains(r) || femaleKeys.contains(r);
            })
            .map((m) => {
                  ...enrichMemberProfile(m),
                  'generationLevel': level,
                  'generationRole': roleLabelForAncestorLevel(level, m),
                })
            .toList(),
      );
    }
    return [];
  }

  final layers = <GenerationLayer>[];

  for (var level = maxUp; level >= 1; level--) {
    final atLevel = _sortFemaleFirst(pickAtLevel(level));
    layers.add(GenerationLayer(
      level: level,
      direction: 'ancestor',
      title: _ancestorGenerationTitle(level),
      subtitle: _ancestorGenerationSubtitle(level),
      members: atLevel,
    ));
  }

  final selfMembers = _uniqueMembers(
    selfIds
        .map((uid) =>
            graph.byUserId[uid] ??
            members.cast<MemberMap?>().firstWhere(
                  (x) => x != null && memberUserId(x) == uid,
                  orElse: () => null,
                ))
        .whereType<MemberMap>()
        .map((m) {
      final uid = memberUserId(m);
      final isCousin = cousinIds.contains(uid);
      final r = _norm(m['relationship']);
      String generationRole;
      if (uid == focusId) {
        generationRole = 'You (ME)';
      } else if (isCousin) {
        generationRole = 'Cousin';
      } else if (['brother', 'sister'].contains(r)) {
        generationRole = r == 'sister' ? 'Sister' : 'Brother';
      } else if (['spouse', 'wife', 'husband', 'partner'].contains(r)) {
        generationRole = 'Spouse';
      } else if (['sister-in-law', 'sisterinlaw'].contains(r)) {
        generationRole = 'Sister-in-law';
      } else if (['brother-in-law', 'brotherinlaw'].contains(r)) {
        generationRole = 'Brother-in-law';
      } else {
        generationRole = (m['relationship'] ?? '').toString();
      }
      return {
        ...enrichMemberProfile(m),
        'generationLevel': 0,
        'generationRole': generationRole,
        'isFocus': uid == focusId,
      };
    }).toList(),
  );

  layers.add(GenerationLayer(
    level: 0,
    direction: 'self',
    title: 'You · Current generation',
    subtitle: 'You · Spouse · Siblings · Cousins',
    members: selfMembers,
  ));

  final childMembers = _uniqueMembers(
    descendantLevel.entries
        .where((e) => e.value == 1)
        .map((e) => graph.byUserId[e.key])
        .whereType<MemberMap>()
        .where((m) => !cousinIds.contains(memberUserId(m)))
        .map((m) => {
              ...enrichMemberProfile(m),
              'generationLevel': -1,
              'generationRole':
                  _norm(m['relationship']) == 'daughter' ||
                          genderHint(m['relationship']) == 'female'
                      ? 'Daughter'
                      : 'Son',
            })
        .toList(),
  );

  if (childMembers.isEmpty) {
    for (final m in flatByRel(['son', 'daughter'])) {
      if (cousinIds.contains(memberUserId(m))) continue;
      childMembers.add({
        ...enrichMemberProfile(m),
        'generationLevel': -1,
        'generationRole':
            _norm(m['relationship']) == 'daughter' ||
                    genderHint(m['relationship']) == 'female'
                ? 'Daughter'
                : 'Son',
      });
    }
  }

  layers.add(GenerationLayer(
    level: -1,
    direction: 'descendant',
    title: 'Children · Next generation',
    subtitle: 'Son · Daughter',
    members: _uniqueMembers(childMembers),
  ));

  final byUserId = <String, MemberMap>{};
  for (final layer in layers) {
    for (final m in layer.members) {
      final key = memberUserId(m);
      final existing = byUserId[key];
      if (existing != null &&
          existing['layerLevel'] == 0 &&
          layer.level == -1) {
        continue;
      }
      if (existing != null &&
          existing['layerLevel'] == 1 &&
          layer.level == 0 &&
          _norm(existing['generationRole']) == 'cousin') {
        continue;
      }
      byUserId[key] = {...m, 'layerLevel': layer.level};
    }
  }

  return GenerationLayersResult(
    focusId: focusId,
    layers: layers,
    byUserId: byUserId,
  );
}

class GenerationLayer {
  GenerationLayer({
    required this.level,
    required this.direction,
    required this.title,
    required this.subtitle,
    required this.members,
  });

  final int level;
  final String direction;
  final String title;
  final String subtitle;
  final List<MemberMap> members;
}

class GenerationLayersResult {
  GenerationLayersResult({
    required this.focusId,
    required this.layers,
    required this.byUserId,
  });

  final String? focusId;
  final List<GenerationLayer> layers;
  final Map<String, MemberMap> byUserId;
}

/// Highest ancestor generation that already has at least one member (0 if none).
int detectFilledAncestorDepth(
  List<MemberMap> members, [
  String? focusUserId,
]) {
  if (members.isEmpty) return 0;
  final graph = buildKinshipGraph(members);
  final focusId = focusUserId ??
      graph.creatorId ??
      memberUserId(members.first);

  var frontier = [focusId];
  var depth = 0;
  for (var level = 1; level <= 12; level++) {
    final next = <String>{};
    for (final id in frontier) {
      next.addAll(_setOf(graph.parentsOf, id));
    }
    if (next.isEmpty) break;
    depth = level;
    frontier = [...next];
  }

  bool has(List<String> labels) =>
      members.any((m) => labels.contains(_norm(m['relationship'])));

  if (has(['mother', 'mom', 'father', 'dad', 'uncle', 'aunt'])) {
    depth = depth > 1 ? depth : 1;
  }
  if (has(['grandmother', 'grandma', 'grandfather', 'grandpa'])) {
    depth = depth > 2 ? depth : 2;
  }
  if (has([
    'greatgrandmother',
    'great-grandmother',
    'greatgrandfather',
    'great-grandfather',
  ])) {
    depth = depth > 3 ? depth : 3;
  }
  return depth;
}

List<MemberMap> filterMembersByGeneration(
  List<MemberMap> members,
  Map<String, MemberMap> byUserId, [
  dynamic generationFilter = 'all',
]) {
  if (generationFilter == 'all' ||
      generationFilter == null ||
      generationFilter == '') {
    return members;
  }
  final level = int.tryParse(generationFilter.toString());
  if (level == null) return members;
  return members.where((m) {
    final key = memberUserId(m);
    final info = byUserId[key];
    if (info != null &&
        (info['layerLevel'] == level || info['generationLevel'] == level)) {
      return true;
    }
    if (level == 0) {
      final role = _norm(
        m['egoRole'] ??
            m['generationRole'] ??
            m['relationship'] ??
            m['originalRelationship'] ??
            '',
      );
      if (role == 'cousin') return true;
    }
    if (level == 1) {
      final role = _norm(
        m['egoRole'] ??
            m['generationRole'] ??
            m['relationship'] ??
            m['originalRelationship'] ??
            '',
      );
      if (['uncle', 'aunt', 'mother', 'father', 'mom', 'dad'].contains(role)) {
        return true;
      }
    }
    return false;
  }).toList();
}
