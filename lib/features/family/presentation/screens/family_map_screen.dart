import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/ft_page.dart';
import '../../data/family_api_service.dart';
import '../../data/models/family_models.dart';
import '../providers/family_providers.dart';

class FamilyMapScreen extends StatefulWidget {
  const FamilyMapScreen({super.key});

  @override
  State<FamilyMapScreen> createState() => _FamilyMapScreenState();
}

class _FamilyMapScreenState extends State<FamilyMapScreen> {
  List<FamilyMember> _members = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final session = context.read<FamilySessionProvider>();
    if (session.familyId == null) await session.loadMine();
    final familyId = session.familyId;
    if (familyId == null) {
      setState(() => _loading = false);
      return;
    }
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
      setState(() {
        _members = list
            .whereType<Map>()
            .map((e) => FamilyMember.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  LatLng? _coords(FamilyMember m) {
    final lat = m.profileInfo['lat'] ?? m.profileInfo['latitude'];
    final lng = m.profileInfo['lng'] ??
        m.profileInfo['lon'] ??
        m.profileInfo['longitude'];
    if (lat == null || lng == null) return null;
    final la = double.tryParse(lat.toString());
    final lo = double.tryParse(lng.toString());
    if (la == null || lo == null) return null;
    return LatLng(la, lo);
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];
    for (final m in _members) {
      final c = _coords(m);
      if (c == null) continue;
      markers.add(
        Marker(
          point: c,
          width: 40,
          height: 40,
          child: Tooltip(
            message: m.name,
            child: const Icon(Icons.location_on, color: Colors.red, size: 36),
          ),
        ),
      );
    }

    return FtPage(
      title: 'Family Map',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              options: MapOptions(
                initialCenter: markers.isNotEmpty
                    ? markers.first.point
                    : const LatLng(20.5937, 78.9629),
                initialZoom: markers.isNotEmpty ? 5 : 4,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.familytree_app',
                ),
                MarkerLayer(markers: markers),
              ],
            ),
    );
  }
}
