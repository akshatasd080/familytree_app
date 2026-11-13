import 'package:dio/dio.dart';

class GeocodeResult {
  const GeocodeResult({
    required this.lat,
    required this.lng,
    required this.label,
  });

  final double lat;
  final double lng;
  final String label;
}

/// Photon geocoder — same as web `FamilyMap.jsx` (`photon.komoot.io`).
class GeocodeService {
  GeocodeService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 12),
              ),
            );

  final Dio _dio;
  final Map<String, GeocodeResult?> _cache = {};

  Future<GeocodeResult?> geocodePlace(String query) async {
    final q = query.trim();
    if (q.isEmpty) return null;
    final key = q.toLowerCase();
    if (_cache.containsKey(key)) return _cache[key];

    try {
      final res = await _dio.get(
        'https://photon.komoot.io/api/',
        queryParameters: {'q': q, 'limit': 1},
      );
      final data = res.data;
      final features = data is Map && data['features'] is List
          ? data['features'] as List
          : const [];
      if (features.isEmpty) {
        _cache[key] = null;
        return null;
      }
      final feature = features.first;
      if (feature is! Map) {
        _cache[key] = null;
        return null;
      }
      final geometry = feature['geometry'];
      final coords = geometry is Map ? geometry['coordinates'] : null;
      if (coords is! List || coords.length < 2) {
        _cache[key] = null;
        return null;
      }
      final lng = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();
      final props = feature['properties'] is Map
          ? Map<String, dynamic>.from(feature['properties'] as Map)
          : <String, dynamic>{};
      final label = (props['name'] ??
              [
                props['city'],
                props['state'],
                props['country'],
              ].where((e) => e != null && e.toString().trim().isNotEmpty).join(', '))
          .toString();
      final result = GeocodeResult(
        lat: lat,
        lng: lng,
        label: label.isEmpty ? q : label,
      );
      _cache[key] = result;
      return result;
    } catch (_) {
      _cache[key] = null;
      return null;
    }
  }
}
