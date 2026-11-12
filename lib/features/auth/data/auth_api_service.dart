import '../../../core/network/api_client.dart';
import 'models/auth_models.dart';

class AuthApiService {
  AuthApiService(this._api);

  final ApiClient _api;

  Future<({String? token, AuthUser? user})> login({
    required String email,
    required String password,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final data = res.data ?? {};
    final token = data['token']?.toString() ??
        data['accessToken']?.toString();
    final userMap = data['user'] is Map
        ? Map<String, dynamic>.from(data['user'] as Map)
        : null;
    return (
      token: token,
      user: userMap == null ? null : AuthUser.fromJson(userMap),
    );
  }

  Future<AuthUser> me() async {
    final res = await _api.get<Map<String, dynamic>>('/auth/me');
    final data = res.data ?? {};
    final userMap = data['user'] is Map
        ? Map<String, dynamic>.from(data['user'] as Map)
        : Map<String, dynamic>.from(data);
    return AuthUser.fromJson(userMap);
  }

  Future<List<String>> permissions() async {
    final res = await _api.get('/auth/permissions');
    final data = res.data;
    dynamic raw = data;
    if (data is Map) raw = data['permissions'] ?? data;
    if (raw is! List) return const [];
    return raw
        .map((p) {
          if (p is String) return p;
          if (p is Map) return (p['name'] ?? p['displayName'] ?? '').toString();
          return p.toString();
        })
        .where((e) => e.isNotEmpty)
        .cast<String>()
        .toList();
  }

  Future<void> changePassword({
    required String newPassword,
    String? currentPassword,
  }) async {
    await _api.post(
      '/auth/change-password',
      data: {
        if (currentPassword != null) 'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmPassword': newPassword,
      },
    );
  }
}
