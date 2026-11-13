import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/ft_page.dart';
import '../../data/family_api_service.dart';
import '../../data/geocode_service.dart';
import '../../data/models/family_models.dart';
import '../providers/family_providers.dart';

const _markerColors = <Color>[
  Color(0xFF0EA5E9),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
];

class _MapPin {
  const _MapPin({
    required this.member,
    required this.point,
    required this.locationText,
    required this.resolvedLabel,
    required this.color,
  });

  final FamilyMember member;
  final LatLng point;
  final String locationText;
  final String resolvedLabel;
  final Color color;
}

class FamilyMapScreen extends StatefulWidget {
  const FamilyMapScreen({super.key});

  @override
  State<FamilyMapScreen> createState() => _FamilyMapScreenState();
}

class _FamilyMapScreenState extends State<FamilyMapScreen> {
  final _mapController = MapController();
  final _search = TextEditingController();
  final _geocoder = GeocodeService();

  List<FamilyMember> _members = const [];
  List<_MapPin> _pins = const [];
  bool _loading = true;
  bool _geoLoading = false;
  String? _activeId;
  String _query = '';

  static const _india = LatLng(22.9734, 78.6569);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    _mapController.dispose();
    super.dispose();
  }

  String _locationText(FamilyMember m) {
    final fromMember = (m.location ?? '').trim();
    if (fromMember.isNotEmpty) return fromMember;
    final info = m.profileInfo;
    return (info['location'] ?? '').toString().trim();
  }

  List<_MapPin> get _filteredPins {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _pins;
    return _pins.where((p) {
      final hay = [
        p.member.name,
        p.member.relationship ?? '',
        p.locationText,
        p.resolvedLabel,
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  List<FamilyMember> get _missing =>
      _members.where((m) => _locationText(m).isEmpty).toList();

  List<FamilyMember> get _withLocation =>
      _members.where((m) => _locationText(m).isNotEmpty).toList();

  Future<void> _load() async {
    final session = context.read<FamilySessionProvider>();
    if (session.familyId == null) await session.loadMine();
    if (!mounted) return;
    final familyId = session.familyId;
    if (familyId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _pins = const [];
      _activeId = null;
    });
    try {
      final res =
          await context.read<FamilyApiService>().listFamilyMembers(familyId);
      final data = res.data;
      List list = const [];
      if (data is Map && data['members'] is List) {
        list = data['members'] as List;
      } else if (data is List) {
        list = data;
      }
      final members = list
          .whereType<Map>()
          .map((e) => FamilyMember.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (!mounted) return;
      setState(() {
        _members = members;
        _loading = false;
      });
      await _geocodeMembers(members);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _geocodeMembers(List<FamilyMember> members) async {
    final withLoc = members
        .map((m) => (m, _locationText(m)))
        .where((e) => e.$2.isNotEmpty)
        .toList();
    if (withLoc.isEmpty) {
      if (mounted) setState(() => _pins = const []);
      return;
    }
    setState(() => _geoLoading = true);
    final pins = <_MapPin>[];
    for (var i = 0; i < withLoc.length; i++) {
      final member = withLoc[i].$1;
      final text = withLoc[i].$2;
      final geo = await _geocoder.geocodePlace(text);
      if (!mounted) return;
      if (geo == null) continue;
      pins.add(
        _MapPin(
          member: member,
          point: LatLng(geo.lat, geo.lng),
          locationText: text,
          resolvedLabel: geo.label,
          color: _markerColors[i % _markerColors.length],
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      _pins = pins;
      _geoLoading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitAll();
    });
  }

  void _fitAll() {
    if (_pins.isEmpty) return;
    try {
      if (_pins.length == 1) {
        _mapController.move(_pins.first.point, 11);
        return;
      }
      final bounds = LatLngBounds.fromPoints(
        _pins.map((p) => p.point).toList(),
      );
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
      );
    } catch (_) {}
  }

  void _focusPin(_MapPin pin) {
    setState(() => _activeId = pin.member.id);
    try {
      _mapController.move(pin.point, 12);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<FamilySessionProvider>();
    final familyName = session.current?.name ?? 'Family';
    final showEmptyCta =
        !_loading && !_geoLoading && _pins.isEmpty && _withLocation.isEmpty;

    return FtPage(
      title: 'Family Map',
      actions: [
        TextButton.icon(
          onPressed: _pins.isEmpty ? null : _fitAll,
          icon: const Icon(Icons.center_focus_strong, size: 18),
          label: const Text('Fit all'),
        ),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Track where everyone lives · $familyName',
                      style: AppTheme.body(size: 12, color: AppTheme.muted),
                    ),
                  ),
                ),
                if (session.families.length > 1)
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: session.families.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
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
                Expanded(
                  flex: 58,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _pins.isNotEmpty
                              ? _pins.first.point
                              : _india,
                          initialZoom: _pins.isNotEmpty ? 5 : 4.5,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all &
                                ~InteractiveFlag.rotate,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName:
                                'com.example.familytree_app',
                          ),
                          MarkerLayer(
                            markers: [
                              for (final pin in _pins)
                                Marker(
                                  point: pin.point,
                                  width: _activeId == pin.member.id ? 48 : 42,
                                  height:
                                      _activeId == pin.member.id ? 56 : 50,
                                  child: GestureDetector(
                                    onTap: () => _focusPin(pin),
                                    child: _PinMarker(
                                      pin: pin,
                                      active:
                                          _activeId == pin.member.id,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        right: 10,
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.96),
                          elevation: 2,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.sensors,
                                  size: 16,
                                  color: AppTheme.forest,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'LIVE FAMILY PINS',
                                        style: AppTheme.body(
                                          size: 10,
                                          weight: FontWeight.w800,
                                          color: AppTheme.forest,
                                        ),
                                      ),
                                      Text(
                                        'Click a member to fly to their city on the map.',
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
                          ),
                        ),
                      ),
                      if (showEmptyCta)
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Material(
                              color: Colors.white,
                              elevation: 6,
                              borderRadius: BorderRadius.circular(18),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      size: 36,
                                      color: Color(0xFF0284C7),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Start mapping your family',
                                      textAlign: TextAlign.center,
                                      style: AppTheme.display(size: 18),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'When you add a member, enter their city. Everyone with a location appears here as a pin.',
                                      textAlign: TextAlign.center,
                                      style: AppTheme.body(
                                        size: 12,
                                        color: AppTheme.muted,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF0284C7),
                                      ),
                                      onPressed: () =>
                                          context.go('/family/members'),
                                      child: const Text(
                                        'Add member location',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_geoLoading)
                        const Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Chip(
                              avatar: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              label: Text('Locating…'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 42,
                  child: Material(
                    color: Colors.white,
                    elevation: 8,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                          child: TextField(
                            controller: _search,
                            onChanged: (v) => setState(() => _query = v),
                            decoration: InputDecoration(
                              hintText: 'Search member or city…',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Text(
                                '${_pins.length} on map',
                                style: AppTheme.body(
                                  size: 12,
                                  weight: FontWeight.w800,
                                  color: AppTheme.forest,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '· ${_members.length} members',
                                style: AppTheme.body(
                                  size: 12,
                                  color: AppTheme.muted,
                                ),
                              ),
                              if (_geoLoading) ...[
                                const SizedBox(width: 8),
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                            children: [
                              if (_filteredPins.isEmpty &&
                                  _withLocation.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.location_off_outlined,
                                        size: 28,
                                        color: AppTheme.muted
                                            .withValues(alpha: 0.7),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'No locations yet',
                                        style: AppTheme.body(
                                          weight: FontWeight.w700,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            context.go('/family/profile'),
                                        child: const Text(
                                          'Add location from Profile',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ..._filteredPins.map((pin) {
                                final active =
                                    _activeId == pin.member.id;
                                final url = mediaUrl(pin.member.avatar);
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 8),
                                  child: Material(
                                    color: active
                                        ? const Color(0xFFECFDF5)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    child: InkWell(
                                      onTap: () => _focusPin(pin),
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      child: Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 18,
                                              backgroundColor: pin.color
                                                  .withValues(alpha: 0.18),
                                              backgroundImage: url != null
                                                  ? NetworkImage(url)
                                                  : null,
                                              child: url == null
                                                  ? Text(
                                                      pin.member.name
                                                              .isNotEmpty
                                                          ? pin.member
                                                              .name[0]
                                                              .toUpperCase()
                                                          : '?',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight
                                                                .w800,
                                                        color: pin.color,
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .start,
                                                children: [
                                                  Text(
                                                    pin.member.name,
                                                    maxLines: 1,
                                                    overflow: TextOverflow
                                                        .ellipsis,
                                                    style: AppTheme.body(
                                                      weight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                  Text(
                                                    [
                                                      pin.member
                                                              .relationship ??
                                                          '',
                                                      pin.locationText,
                                                    ]
                                                        .where((e) => e
                                                            .trim()
                                                            .isNotEmpty)
                                                        .join(' · '),
                                                    maxLines: 1,
                                                    overflow: TextOverflow
                                                        .ellipsis,
                                                    style: AppTheme.body(
                                                      size: 11,
                                                      color:
                                                          AppTheme.muted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.near_me_outlined,
                                              size: 18,
                                              color: pin.color,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              if (_missing.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'MISSING LOCATION (${_missing.length})',
                                  style: AppTheme.body(
                                    size: 11,
                                    weight: FontWeight.w800,
                                    color: const Color(0xFFB45309),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ..._missing.take(8).map((m) {
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      m.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTheme.body(
                                        weight: FontWeight.w700,
                                        size: 13,
                                      ),
                                    ),
                                    subtitle: Text(
                                      m.relationship ?? 'Member',
                                      style: AppTheme.body(
                                        size: 11,
                                        color: AppTheme.muted,
                                      ),
                                    ),
                                  );
                                }),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: () =>
                                        context.go('/family/members'),
                                    child: const Text(
                                      'Add locations from Members',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _PinMarker extends StatelessWidget {
  const _PinMarker({required this.pin, required this.active});

  final _MapPin pin;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final url = mediaUrl(pin.member.avatar);
    return Transform.scale(
      scale: active ? 1.12 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: pin.color, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
              image: url != null
                  ? DecorationImage(
                      image: NetworkImage(url),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: url == null
                ? Text(
                    pin.member.name.isNotEmpty
                        ? pin.member.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: pin.color,
                    ),
                  )
                : null,
          ),
          CustomPaint(
            size: const Size(14, 10),
            painter: _PinTipPainter(pin.color),
          ),
        ],
      ),
    );
  }
}

class _PinTipPainter extends CustomPainter {
  _PinTipPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PinTipPainter oldDelegate) =>
      oldDelegate.color != color;
}
