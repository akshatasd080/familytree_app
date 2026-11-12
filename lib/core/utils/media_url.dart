import '../constants/api_constants.dart';

/// Resolves backend upload paths the same way the web helpers do.
String? mediaUrl(String? path) {
  if (path == null || path.trim().isEmpty) return null;
  final value = path.trim();
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  final base = ApiConstants.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
  if (value.startsWith('/api/')) return '$base$value';
  if (value.startsWith('/uploads')) return '$base/api$value';
  if (value.startsWith('uploads/')) return '$base/api/$value';
  return '$base/api/uploads/$value';
}
