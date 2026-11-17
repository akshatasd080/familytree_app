import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
    this.selectedId,
    this.canAdd = false,
    this.showExpand = false,
    this.onMemberTap,
    this.onAdd,
    this.onLink,
    this.onExpand,
    this.onMakeAdmin,
    this.transformationController,
  });

  final List<FamilyMember> members;
  final List<Map<String, dynamic>> relationships;
  final String? focusUserId;
  final String? meUserId;
  final String? selectedId;
  final bool canAdd;
  final bool showExpand;
  final ValueChanged<FamilyMember>? onMemberTap;
  final ValueChanged<FamilyMember>? onAdd;
  final ValueChanged<FamilyMember>? onLink;
  final ValueChanged<FamilyMember>? onExpand;
  final ValueChanged<FamilyMember>? onMakeAdmin;
  final TransformationController? transformationController;

  @override
  State<FamilyGraphView> createState() => FamilyGraphViewState();
}

class FamilyGraphViewState extends State<FamilyGraphView> {
  FamilyLayoutResult? _lastLayout;
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

  /// Center a member in the viewport (web `focusNode`).
  bool focusMember(String memberId) {
    final layout = _lastLayout;
    if (layout == null || _viewport == Size.zero) return false;
    Map<String, dynamic>? node;
    for (final n in layout.nodes) {
      if ((n['id'] ?? '').toString() == memberId) {
        node = n;
        break;
      }
    }
    if (node == null) return false;
    final x = (node['x'] as num?)?.toDouble() ?? 0;
    final y = (node['y'] as num?)?.toDouble() ?? 0;
    final w = (node['w'] as num?)?.toDouble() ?? nodeW;
    final h = (node['h'] as num?)?.toDouble() ?? nodeH;
    final scale = _zoom.clamp(0.7, 1.6);
    final focalX = x + w / 2;
    final focalY = y + h / 2;
    final dx = _viewport.width / 2 - focalX * scale;
    final dy = _viewport.height / 2 - focalY * scale;
    _tx.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
    setState(() {});
    return true;
  }

  /// Export PNG (web download parity) and open the share sheet.
  Future<void> exportPng(String familyName) async {
    final layout = _lastLayout;
    if (layout == null || layout.nodes.isEmpty) {
      throw Exception('Add family members before downloading the tree');
    }

    const pad = 28.0;
    const header = 56.0;
    const footer = 40.0;
    final width = layout.width + pad * 2;
    final height = layout.height + header + footer;
    const pixelRatio = 2.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio);

    final bg = Paint()..color = const Color(0xFFF8FAFC);
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bg);

    final titlePainter = TextPainter(
      text: TextSpan(
        text: familyName,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - pad * 2);
    titlePainter.paint(canvas, Offset(pad, 18));

    canvas.save();
    canvas.translate(pad, header);

    for (final band in layout.bands) {
      canvas.drawRect(
        Rect.fromLTWH(0, band.y, layout.width, band.height),
        Paint()..color = _parseHex(band.bg).withValues(alpha: 0.55),
      );
      final label = TextPainter(
        text: TextSpan(
          text: band.title,
          style: TextStyle(
            color: _parseHex(band.ink),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 160);
      label.paint(canvas, Offset(12, band.y + 16));
    }

    for (final edge in layout.edges) {
      if (edge.points.length < 2) continue;
      final paint = Paint()
        ..color = edge.kind == 'spouse'
            ? const Color(0xFFE11D48)
            : edge.kind == 'sibling'
                ? const Color(0xFF7C3AED)
                : const Color(0xFF2563EB)
        ..strokeWidth = edge.kind == 'spouse' ? 2.8 : 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final path = Path()..moveTo(edge.points.first.dx, edge.points.first.dy);
      for (var i = 1; i < edge.points.length; i++) {
        path.lineTo(edge.points[i].dx, edge.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    for (final node in layout.nodes) {
      final x = (node['x'] as num?)?.toDouble() ?? 0;
      final y = (node['y'] as num?)?.toDouble() ?? 0;
      final w = (node['w'] as num?)?.toDouble() ?? nodeW;
      final h = (node['h'] as num?)?.toDouble() ?? nodeH;
      final name = (node['name'] ?? 'Member').toString();
      final role = (node['treeRole'] ?? node['relationship'] ?? 'Family').toString();
      final isMe = _nodeIsMe(node);
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        const Radius.circular(12),
      );
      canvas.drawRRect(rrect, Paint()..color = Colors.white);
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = isMe ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isMe ? 2.5 : 1.5,
      );
      final nameTp = TextPainter(
        text: TextSpan(
          text: name,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: w - 24);
      nameTp.paint(canvas, Offset(x + 14, y + 28));
      final roleTp = TextPainter(
        text: TextSpan(
          text: isMe ? 'You' : role,
          style: const TextStyle(
            color: Color(0xFF1D4ED8),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: w - 24);
      roleTp.paint(canvas, Offset(x + 14, y + 48));
    }

    canvas.restore();

    final legend = TextPainter(
      text: const TextSpan(
        text: 'Blue: parent – child     Rose: spouse     Violet: siblings',
        style: TextStyle(
          color: Color(0xFF475569),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - pad * 2);
    legend.paint(canvas, Offset(pad, height - 28));

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (width * pixelRatio).ceil(),
      (height * pixelRatio).ceil(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw Exception('Could not download the tree');

    final safe = familyName.replaceAll(RegExp(r'[^\w\- ]+'), '').trim();
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/${safe.isEmpty ? 'family-tree' : safe}-family-tree.png',
    );
    await file.writeAsBytes(bytes.buffer.asUint8List());
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: '$familyName family tree',
      ),
    );
  }

  bool _nodeIsMe(Map<String, dynamic> node) {
    final me = widget.meUserId;
    if (me == null || me.isEmpty) return false;
    final userId = (node['userId'] ?? node['user_id'] ?? '').toString();
    final id = (node['id'] ?? '').toString();
    return userId == me || id == me;
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

  /// Mobile-first fit: keep cards readable (not tiny), center on screen.
  /// Pinch / +/- zoom still available to see the full tree.
  void _fitToViewport({bool force = false}) {
    if (_viewport == Size.zero || _content == Size.zero) return;
    final signature =
        '${widget.members.length}_${_content.width.round()}_${_viewport.width.round()}_${_viewport.height.round()}';
    if (!force && _fitSignature == signature) return;
    _fitSignature = signature;

    final isPhone = _viewport.width < 700;
    final pad = isPhone ? 12.0 : 24.0;
    final sx = (_viewport.width - pad * 2) / math.max(_content.width, 1);
    final sy = (_viewport.height - pad * 2) / math.max(_content.height, 1);
    final fitAll = math.min(sx, sy);

    // On phones, prefer readable card size over shrinking the whole tree.
    // Target ~48% of screen width per card when the full-fit would look tiny.
    final comfort = isPhone
        ? ((_viewport.width * 0.48) / nodeW).clamp(0.9, 1.55)
        : 1.0;

    double scale;
    if (isPhone && fitAll < comfort * 0.9) {
      scale = comfort;
    } else if (isPhone) {
      // Small trees: scale up so the circle fills the phone better.
      scale = math.max(fitAll, comfort * 0.92).clamp(0.85, 1.7);
    } else {
      scale = fitAll.clamp(0.35, 1.4);
    }

    // True center — horizontally and vertically.
    final dx = (_viewport.width - _content.width * scale) / 2;
    final dy = (_viewport.height - _content.height * scale) / 2;

    _tx.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
    if (mounted) setState(() {});
  }

  void _setZoom(double next) {
    if (_viewport == Size.zero) return;
    final clamped = next.clamp(0.35, 2.8).toDouble();
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
    _lastLayout = layout;
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
                boundaryMargin: const EdgeInsets.all(600),
                minScale: 0.35,
                maxScale: 2.8,
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
                                    .withValues(alpha: 0.42),
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 10),
                                  child: SizedBox(
                                    width: 108,
                                    child: Text(
                                      band.title,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _parseHex(band.ink),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
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
                        final isMe = _isLoggedIn(member);
                        final isFocus = _isFocus(member, focus);
                        final selected = widget.selectedId == member.id;
                        return Positioned(
                          left: x,
                          top: y,
                          width: w,
                          height: h,
                          child: _MemberNode(
                            member: member,
                            treeRole: treeRole,
                            isMe: isMe,
                            isFocus: isFocus,
                            selected: selected,
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
                            onMakeAdmin: widget.onMakeAdmin == null ||
                                    member.isOwner ||
                                    !member.hasLoginAccount
                                ? null
                                : () => widget.onMakeAdmin!(member),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              bottom: 10,
              child: Material(
                color: AppTheme.card.withValues(alpha: 0.96),
                elevation: 2,
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LegendRow(color: Color(0xFF2563EB), label: 'Parent–child'),
                      SizedBox(height: 4),
                      _LegendRow(color: Color(0xFFE11D48), label: 'Spouse'),
                      SizedBox(height: 4),
                      _LegendRow(color: Color(0xFF7C3AED), label: 'Siblings'),
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
                color: AppTheme.card.withValues(alpha: 0.96),
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
                        onPressed: () => _setZoom(_zoom - 0.15),
                        icon: const Icon(Icons.remove, size: 18),
                      ),
                      SizedBox(
                        width: 44,
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
                        onPressed: () => _setZoom(_zoom + 0.15),
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

  bool _isLoggedIn(FamilyMember member) {
    final me = widget.meUserId;
    if (me == null || me.isEmpty) return false;
    return member.userId == me || member.id == me;
  }

  bool _isFocus(FamilyMember member, String? focus) {
    if (focus == null || focus.isEmpty) return false;
    return member.userId == focus || member.id == focus;
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF475569),
          ),
        ),
      ],
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
  const _MemberNode({
    required this.member,
    required this.isMe,
    required this.isFocus,
    required this.selected,
    required this.canAdd,
    required this.showExpand,
    this.treeRole,
    this.onTap,
    this.onAdd,
    this.onLink,
    this.onExpand,
    this.onMakeAdmin,
  });

  final FamilyMember member;
  final String? treeRole;
  final bool isMe;
  final bool isFocus;
  final bool selected;
  final bool canAdd;
  final bool showExpand;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;
  final VoidCallback? onLink;
  final VoidCallback? onExpand;
  final VoidCallback? onMakeAdmin;

  String get _roleLabel {
    if (isMe) return 'You';
    final role = (treeRole ?? '').trim();
    if (role.isNotEmpty) return role;
    final rel = (member.relationship ?? '').trim();
    if (rel.isNotEmpty &&
        rel.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '') != 'sitecreator') {
      return rel;
    }
    final gender = (member.gender ?? '').trim();
    if (gender.isNotEmpty) return gender;
    return 'Family';
  }

  @override
  Widget build(BuildContext context) {
    final photo = mediaUrl(member.avatar);
    final pending =
        member.invitePending || (member.status ?? '').toLowerCase().contains('pending');
    final roleLabel = _roleLabel;
    final borderColor = selected
        ? AppTheme.forest
        : isMe
            ? const Color(0xFFFBBF24)
            : isFocus
                ? const Color(0xFF38BDF8)
                : pending
                    ? const Color(0xFFFECACA)
                    : AppTheme.border;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFECFDF5) : AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: selected || isMe || isFocus ? 2.5 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
                          radius: 20,
                          backgroundColor:
                              AppTheme.forest.withValues(alpha: 0.12),
                          backgroundImage:
                              photo != null ? NetworkImage(photo) : null,
                          child: photo == null
                              ? Text(
                                  member.name.isNotEmpty
                                      ? member.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 14,
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
                                    fontSize: 14,
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
                              if (member.isAdmin && !isMe)
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'ADMIN',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0369A1),
                                    ),
                                  ),
                                ),
                              if (pending)
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
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
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFE11D48),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            roleLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isFocus && !isMe
                                  ? const Color(0xFF0284C7)
                                  : const Color(0xFF1E40AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _NodeAction(
                  icon: Icons.person_outline,
                  color: const Color(0xFF475569),
                  bg: AppTheme.card,
                  border: AppTheme.borderSoft,
                  onTap: onTap,
                ),
                if (onMakeAdmin != null) ...[
                  const SizedBox(width: 6),
                  _NodeAction(
                    icon: member.isAdmin
                        ? Icons.shield_outlined
                        : Icons.admin_panel_settings_outlined,
                    color: const Color(0xFF0369A1),
                    bg: const Color(0xFFE0F2FE),
                    onTap: onMakeAdmin,
                  ),
                ],
                if (canAdd && onLink != null) ...[
                  const SizedBox(width: 6),
                  _NodeAction(
                    icon: Icons.link,
                    color: Colors.black,
                    bg: const Color(0xFFF97316),
                    onTap: onLink,
                  ),
                ],
                if (canAdd && onAdd != null) ...[
                  const SizedBox(width: 6),
                  _NodeAction(
                    icon: Icons.add,
                    color: Colors.black,
                    bg: const Color(0xFF059669),
                    onTap: onAdd,
                  ),
                ],
                if (showExpand && onExpand != null) ...[
                  const SizedBox(width: 6),
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
      width: 30,
      height: 30,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: border == null ? null : Border.all(color: border!),
            ),
            child: Icon(icon, size: 16, color: color),
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
      final color = switch (edge.kind) {
        'spouse' => const Color(0xFFE11D48).withValues(alpha: 0.8),
        'sibling' => const Color(0xFF7C3AED).withValues(alpha: 0.8),
        _ => const Color(0xFF2563EB).withValues(alpha: 0.78),
      };
      final paint = Paint()
        ..color = color
        ..strokeWidth = edge.kind == 'spouse' ? 3.2 : 2.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
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
