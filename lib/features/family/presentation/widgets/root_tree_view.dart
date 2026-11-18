import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../data/models/family_models.dart';
import '../../domain/root_tree_forest.dart';

/// Native root→descendant forest (web RootTreeView parity without iframe).
class RootTreeView extends StatelessWidget {
  const RootTreeView({
    super.key,
    required this.members,
    required this.relationships,
    this.onSelect,
    this.selectedId,
  });

  final List<FamilyMember> members;
  final List<Map<String, dynamic>> relationships;
  final ValueChanged<FamilyMember>? onSelect;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final forest = buildRootForest(members, relationships);
    final people = countForestPeople(forest);
    final byId = {for (final m in members) m.id: m};

    if (forest.isEmpty) {
      return Container(
        color: const Color(0xFF060B12),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.park_outlined, size: 36, color: Colors.amber.shade300),
            const SizedBox(height: 10),
            Text(
              'Root tree is not ready yet',
              style: AppTheme.body(
                weight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add first-generation members and parent/child relations — then the living tree will grow from oldest to newest.',
              textAlign: TextAlign.center,
              style: AppTheme.body(size: 12, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    return Container(
      color: const Color(0xFF060B12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  '$people people · living root tree · tap person for profile',
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 20),
              itemCount: forest.length,
              itemBuilder: (context, index) {
                return _RootBranch(
                  node: forest[index],
                  depth: 0,
                  byId: byId,
                  selectedId: selectedId,
                  onSelect: onSelect,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RootBranch extends StatelessWidget {
  const _RootBranch({
    required this.node,
    required this.depth,
    required this.byId,
    required this.onSelect,
    this.selectedId,
  });

  final RootTreeNode node;
  final int depth;
  final Map<String, FamilyMember> byId;
  final ValueChanged<FamilyMember>? onSelect;
  final String? selectedId;

  void _tap(String id) {
    final member = byId[id];
    if (member != null) onSelect?.call(member);
  }

  @override
  Widget build(BuildContext context) {
    final selected = selectedId == node.id || selectedId == node.spouseId;
    return Padding(
      padding: EdgeInsets.only(left: depth * 14.0, top: 6, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: selected
                ? const Color(0xFF1E293B)
                : const Color(0xFF111827).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _tap(node.id),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFF334155),
                  ),
                ),
                child: Row(
                  children: [
                    _Avatar(url: node.photo, name: node.name),
                    if (node.spouse != null) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.favorite,
                        size: 12,
                        color: Color(0xFFFB7185),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          if (node.spouseId != null) _tap(node.spouseId!);
                        },
                        child: _Avatar(
                          url: node.spousePhoto,
                          name: node.spouse!,
                        ),
                      ),
                    ],
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            node.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          if (node.spouse != null)
                            Text(
                              '& ${node.spouse}',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (node.children.isNotEmpty)
                            Text(
                              '${node.children.length} child${node.children.length == 1 ? '' : 'ren'}',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          for (final child in node.children)
            _RootBranch(
              node: child,
              depth: depth + 1,
              byId: byId,
              selectedId: selectedId,
              onSelect: onSelect,
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.url});

  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFF334155),
      backgroundImage: url != null ? NetworkImage(url!) : null,
      child: url == null
          ? Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            )
          : null,
    );
  }
}
