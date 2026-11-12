import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../data/models/family_models.dart';
import '../../domain/ego_tree.dart';
import '../../domain/family_graph_layout.dart';

/// Interactive tree canvas using web-ported layout (`buildFamilyLayout`).
class FamilyGraphView extends StatelessWidget {
  const FamilyGraphView({
    super.key,
    required this.members,
    required this.relationships,
    this.focusUserId,
    this.onMemberTap,
  });

  final List<FamilyMember> members;
  final List<Map<String, dynamic>> relationships;
  final String? focusUserId;
  final ValueChanged<FamilyMember>? onMemberTap;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const Center(child: Text('No members on the tree yet'));
    }

    final memberMaps = members.map(_memberToMap).toList();
    final rels = relationships.map(_normalizeRelationship).toList();
    final focus = focusUserId ?? resolveDefaultFocusUserId(memberMaps, null);
    final layout = buildFamilyLayout(memberMaps, rels, focus);

    final byId = {for (final m in members) m.id: m};

    return ClipRect(
      child: InteractiveViewer(
        constrained: false,
        boundaryMargin: const EdgeInsets.all(280),
        minScale: 0.2,
        maxScale: 2.2,
        child: SizedBox(
          width: layout.width,
          height: layout.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
            ...layout.bands.map((band) {
              return Positioned(
                left: 0,
                top: band.y,
                width: layout.width,
                height: band.height,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _parseHex(band.bg).withValues(alpha: 0.35),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          band.title,
                          style: TextStyle(
                            color: _parseHex(band.ink),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
            CustomPaint(
              size: Size(layout.width, layout.height),
              painter: _LayoutEdgePainter(layout.edges),
            ),
            ...layout.nodes.map((node) {
              final id = (node['id'] ?? '').toString();
              final member = byId[id] ?? FamilyMember.fromJson(node);
              final x = (node['x'] as num?)?.toDouble() ?? 0;
              final y = (node['y'] as num?)?.toDouble() ?? 0;
              final w = (node['w'] as num?)?.toDouble() ?? nodeW;
              final h = (node['h'] as num?)?.toDouble() ?? nodeH;
              final treeRole = node['treeRole']?.toString();
              return Positioned(
                left: x,
                top: y,
                width: w,
                height: h,
                child: GestureDetector(
                  onTap: () => onMemberTap?.call(member),
                  child: _MemberNode(
                    member: member,
                    treeRole: treeRole,
                  ),
                ),
              );
            }),
            ],
          ),
        ),
      ),
    );
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
      'profileInfo': m.profileInfo,
      'profile_info': m.profileInfo,
    };

Map<String, dynamic> _normalizeRelationship(Map<String, dynamic> rel) {
  final source = (rel['source'] ??
          rel['member_id'] ??
          rel['memberId'] ??
          rel['from'] ??
          '')
      .toString();
  final target = (rel['target'] ??
          rel['related_member_id'] ??
          rel['relatedMemberId'] ??
          rel['to'] ??
          '')
      .toString();
  final type = (rel['type'] ??
          rel['relationship_type'] ??
          rel['relationshipType'] ??
          rel['relationship'] ??
          '')
      .toString();
  return {
    ...rel,
    'source': source,
    'target': target,
    'type': type,
    'relationship_type': type,
  };
}

Color _parseHex(String hex) {
  var value = hex.replaceAll('#', '');
  if (value.length == 6) value = 'FF$value';
  return Color(int.parse(value, radix: 16));
}

class _MemberNode extends StatelessWidget {
  const _MemberNode({required this.member, this.treeRole});

  final FamilyMember member;
  final String? treeRole;

  @override
  Widget build(BuildContext context) {
    final isFocus = treeRole == 'focus' ||
        (member.relationship ?? '').toLowerCase().replaceAll(' ', '') ==
            'sitecreator';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFocus ? AppTheme.forest : AppTheme.border,
          width: isFocus ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.forest.withValues(alpha: 0.12),
            child: Text(
              isFocus
                  ? 'ME'
                  : (member.name.isNotEmpty ? member.name[0].toUpperCase() : '?'),
              style: TextStyle(
                fontSize: isFocus ? 10 : 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.forest,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  member.relationship ?? treeRole ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LayoutEdgePainter extends CustomPainter {
  _LayoutEdgePainter(this.edges);

  final List<LayoutEdge> edges;

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      if (edge.points.length < 2) continue;
      final paint = Paint()
        ..color = edge.kind == 'spouse'
            ? AppTheme.accentPink.withValues(alpha: 0.55)
            : AppTheme.forest.withValues(alpha: 0.4)
        ..strokeWidth = edge.kind == 'spouse' ? 1.8 : 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final path = Path()..moveTo(edge.points.first.dx, edge.points.first.dy);
      for (var i = 1; i < edge.points.length; i++) {
        path.lineTo(edge.points[i].dx, edge.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LayoutEdgePainter oldDelegate) =>
      oldDelegate.edges != edges;
}
