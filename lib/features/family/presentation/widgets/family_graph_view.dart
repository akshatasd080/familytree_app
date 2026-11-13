import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../data/models/family_models.dart';
import '../../domain/ego_tree.dart';
import '../../domain/family_graph_layout.dart';

/// Interactive tree canvas using web-ported layout (`buildFamilyLayout`).
class FamilyGraphView extends StatefulWidget {
  const FamilyGraphView({
    super.key,
    required this.members,
    required this.relationships,
    this.focusUserId,
    this.meUserId,
    this.canAdd = false,
    this.showExpand = false,
    this.onMemberTap,
    this.onAdd,
    this.onLink,
    this.onExpand,
    this.transformationController,
  });

  final List<FamilyMember> members;
  final List<Map<String, dynamic>> relationships;
  final String? focusUserId;
  final String? meUserId;
  final bool canAdd;
  final bool showExpand;
  final ValueChanged<FamilyMember>? onMemberTap;
  final ValueChanged<FamilyMember>? onAdd;
  final ValueChanged<FamilyMember>? onLink;
  final ValueChanged<FamilyMember>? onExpand;
  final TransformationController? transformationController;

  @override
  State<FamilyGraphView> createState() => _FamilyGraphViewState();
}

class _FamilyGraphViewState extends State<FamilyGraphView> {
  late final TransformationController _tx;
  bool _ownsTx = false;
  Size _viewport = Size.zero;
  Size _content = Size.zero;
  String? _fitSignature;
  bool _fitScheduled = false;

  @override
  void initState() {
    super.initState();
    if (widget.transformationController != null) {
      _tx = widget.transformationController!;
    } else {
      _tx = TransformationController();
      _ownsTx = true;
    }
  }

  @override
  void didUpdateWidget(covariant FamilyGraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.members != widget.members ||
        oldWidget.relationships != widget.relationships ||
        oldWidget.focusUserId != widget.focusUserId) {
      _fitSignature = null;
      _scheduleFit();
    }
  }

  @override
  void dispose() {
    if (_ownsTx) _tx.dispose();
    super.dispose();
  }

  double get _zoom {
    final s = _tx.value.getMaxScaleOnAxis();
    return s == 0 ? 1.0 : s;
  }

  void _scheduleFit() {
    if (_fitScheduled) return;
    _fitScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _fitScheduled = false;
      if (!mounted) return;
      _fitToViewport(force: true);
    });
  }

  /// Web `fitTree`: scale + center so the whole diagram fits the phone.
  void _fitToViewport({bool force = false}) {
    if (_viewport == Size.zero || _content == Size.zero) return;
    final signature =
        '${widget.members.length}_${_content.width.round()}_${_viewport.width.round()}';
    if (!force && _fitSignature == signature) return;
    _fitSignature = signature;

    const pad = 20.0;
    final sx = (_viewport.width - pad * 2) / math.max(_content.width, 1);
    final sy = (_viewport.height - pad * 2) / math.max(_content.height, 1);
    final scale = math.min(sx, sy).clamp(0.28, 1.15);

    final dx = (_viewport.width - _content.width * scale) / 2;
    final dy = math.max(pad, (_viewport.height - _content.height * scale) / 5);

    _tx.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
    if (mounted) setState(() {});
  }

  void _setZoom(double next) {
    if (_viewport == Size.zero) return;
    final clamped = next.clamp(0.28, 2.2).toDouble();
    final current = _zoom;
    if (current <= 0) return;
    final focal = Offset(_viewport.width / 2, _viewport.height / 2);
    final scene = _tx.toScene(focal);
    final m = Matrix4.identity()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(clamped, clamped, 1, 1)
      ..translateByDouble(-scene.dx, -scene.dy, 0, 1);
    _tx.value = m;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.members.isEmpty) {
      return const Center(child: Text('No members on the tree yet'));
    }

    final memberMaps = widget.members.map(_memberToMap).toList();
    final rels = widget.relationships.map(_normalizeRelationship).toList();
    final focus =
        widget.focusUserId ?? resolveDefaultFocusUserId(memberMaps, null);
    final layout = buildFamilyLayout(memberMaps, rels, focus);
    final byId = {for (final m in widget.members) m.id: m};
    _content = Size(layout.width, layout.height);

    return LayoutBuilder(
      builder: (context, constraints) {
        final next = Size(constraints.maxWidth, constraints.maxHeight);
        if (next != _viewport && next.width > 0 && next.height > 0) {
          _viewport = next;
          _scheduleFit();
        }

        return Stack(
          children: [
            ClipRect(
              child: InteractiveViewer(
                transformationController: _tx,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(400),
                minScale: 0.25,
                maxScale: 2.2,
                onInteractionEnd: (_) => setState(() {}),
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
                                color: _parseHex(band.bg)
                                    .withValues(alpha: 0.35),
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 12),
                                  child: SizedBox(
                                    width: 120,
                                    child: Text(
                                      band.title,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _parseHex(band.ink),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                        height: 1.2,
                                      ),
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
                        final member =
                            byId[id] ?? FamilyMember.fromJson(node);
                        final x = (node['x'] as num?)?.toDouble() ?? 0;
                        final y = (node['y'] as num?)?.toDouble() ?? 0;
                        final w =
                            (node['w'] as num?)?.toDouble() ?? nodeW;
                        final h =
                            (node['h'] as num?)?.toDouble() ?? nodeH;
                        final treeRole = node['treeRole']?.toString();
                        final isMe = _isMe(member, focus);
                        return Positioned(
                          left: x,
                          top: y,
                          width: w,
                          height: h,
                          child: _MemberNode(
                            member: member,
                            treeRole: treeRole,
                            isMe: isMe,
                            canAdd: widget.canAdd,
                            showExpand: widget.showExpand,
                            onTap: () =>
                                widget.onMemberTap?.call(member),
                            onAdd: widget.onAdd == null
                                ? null
                                : () => widget.onAdd!(member),
                            onLink: widget.onLink == null
                                ? null
                                : () => widget.onLink!(member),
                            onExpand: widget.onExpand == null
                                ? null
                                : () => widget.onExpand!(member),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
            // Zoom dock — bottom so it never covers the first generation card
            Positioned(
              right: 10,
              bottom: 10,
              child: Material(
                color: Colors.white.withValues(alpha: 0.96),
                elevation: 3,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Zoom out',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _setZoom(_zoom - 0.1),
                        icon: const Icon(Icons.remove, size: 18),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${(_zoom * 100).round()}%',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Zoom in',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _setZoom(_zoom + 0.1),
                        icon: const Icon(Icons.add, size: 18),
                      ),
                      Container(
                        width: 1,
                        height: 26,
                        color: AppTheme.borderSoft,
                      ),
                      TextButton(
                        onPressed: () => _fitToViewport(force: true),
                        child: Text(
                          'Fit',
                          style: AppTheme.body(
                            size: 11,
                            weight: FontWeight.w700,
                            color: AppTheme.forest,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _isMe(FamilyMember member, String? focus) {
    final me = widget.meUserId;
    if (me != null && (member.userId == me || member.id == me)) {
      return true;
    }
    if (focus != null &&
        (member.userId == focus || member.id == focus)) {
      return true;
    }
    final rel =
        (member.relationship ?? '').toLowerCase().replaceAll(' ', '');
    return rel == 'sitecreator';
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
  const _MemberNode({
    required this.member,
    required this.isMe,
    required this.canAdd,
    required this.showExpand,
    this.treeRole,
    this.onTap,
    this.onAdd,
    this.onLink,
    this.onExpand,
  });

  final FamilyMember member;
  final String? treeRole;
  final bool isMe;
  final bool canAdd;
  final bool showExpand;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;
  final VoidCallback? onLink;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final photo = mediaUrl(member.avatar);
    final pending = (member.status ?? '').toLowerCase().contains('pending');
    final roleLabel = isMe ? 'You' : (member.relationship ?? treeRole ?? '');

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isMe
                ? const Color(0xFFFBBF24)
                : pending
                    ? const Color(0xFFFECACA)
                    : AppTheme.border,
            width: isMe ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              AppTheme.forest.withValues(alpha: 0.12),
                          backgroundImage:
                              photo != null ? NetworkImage(photo) : null,
                          child: photo == null
                              ? Text(
                                  member.name.isNotEmpty
                                      ? member.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.forest,
                                  ),
                                )
                              : null,
                        ),
                        if (isMe)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFBBF24),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                size: 8,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 8),
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: pending
                                        ? const Color(0xFF9F1239)
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                              if (isMe)
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFBBF24),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'YOU',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              if (pending)
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF1F2),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: const Color(0xFFFECDD3),
                                    ),
                                  ),
                                  child: const Text(
                                    'PENDING',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFE11D48),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            roleLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E40AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _NodeAction(
                  icon: Icons.person_outline,
                  color: const Color(0xFF475569),
                  bg: Colors.white,
                  border: AppTheme.borderSoft,
                  onTap: onTap,
                ),
                if (canAdd && onLink != null) ...[
                  const SizedBox(width: 4),
                  _NodeAction(
                    icon: Icons.link,
                    color: Colors.white,
                    bg: const Color(0xFFF97316),
                    onTap: onLink,
                  ),
                ],
                if (canAdd && onAdd != null) ...[
                  const SizedBox(width: 4),
                  _NodeAction(
                    icon: Icons.add,
                    color: Colors.white,
                    bg: const Color(0xFF059669),
                    onTap: onAdd,
                  ),
                ],
                if (showExpand && onExpand != null) ...[
                  const SizedBox(width: 4),
                  _NodeAction(
                    icon: Icons.unfold_more,
                    color: AppTheme.forest,
                    bg: const Color(0xFFECFDF5),
                    border: const Color(0xFFA7F3D0),
                    onTap: onExpand,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NodeAction extends StatelessWidget {
  const _NodeAction({
    required this.icon,
    required this.color,
    required this.bg,
    this.border,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color bg;
  final Color? border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 26,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: border == null ? null : Border.all(color: border!),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
        ),
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
            : const Color(0xFF2563EB).withValues(alpha: 0.55)
        ..strokeWidth = edge.kind == 'spouse' ? 1.8 : 1.6
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
