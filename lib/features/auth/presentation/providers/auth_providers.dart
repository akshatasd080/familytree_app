import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/phone_utils.dart';
import '../../data/auth_api_service.dart';
import '../../data/models/auth_models.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._api) : _authApi = AuthApiService(_api);

  final ApiClient _api;
  final AuthApiService _authApi;

  AuthUser? user;
  List<String> permissions = const [];
  bool loading = true;
  bool initialized = false;
  Object? error;

  bool get isAuthenticated => user != null;
  bool hasPermission(String name) => permissions.contains(name);

  Future<void> restoreSession() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final token = await _api.getToken();
      if (token == null || token.isEmpty || _isTokenExpired(token)) {
        await _api.clearToken();
        user = null;
        permissions = const [];
        return;
      }
      try {
        final results = await Future.wait([
          _authApi.me(),
          _authApi.permissions(),
        ]);
        user = results[0] as AuthUser;
        permissions = results[1] as List<String>;
      } catch (_) {
        await _api.clearToken();
        user = null;
        permissions = const [];
      }
    } finally {
      loading = false;
      initialized = true;
      notifyListeners();
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final loginId = normalizeLoginIdentifier(email);
      final result = await _authApi.login(
        email: loginId,
        password: password.trim(),
      );
      if (result.token != null && result.token!.isNotEmpty) {
        await _api.setToken(result.token!);
      }
      user = result.user;
      try {
        permissions = await _authApi.permissions();
      } catch (_) {
        permissions = const [];
      }
      if (user == null) {
        user = await _authApi.me();
      }
    } on ApiException catch (e) {
      error = e.isFamilyInactive
          ? {'code': e.code, 'message': e.message}
          : e.message;
      rethrow;
    } finally {
      loading = false;
      initialized = true;
      notifyListeners();
    }
  }

  /// Used after family OTP / join flows that already set a token.
  Future<void> adoptSession({
    required String token,
    AuthUser? sessionUser,
  }) async {
    await _api.setToken(token);
    user = sessionUser;
    try {
      permissions = await _authApi.permissions();
      user ??= await _authApi.me();
    } catch (_) {
      permissions = const [];
    }
    initialized = true;
    notifyListeners();
  }

  Future<void> logout() async {
    await _api.clearToken();
    user = null;
    permissions = const [];
    error = null;
    notifyListeners();
  }

  void clearMustChangePassword() {
    if (user == null) return;
    user = user!.copyWith(mustChangePassword: false);
    notifyListeners();
  }

  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return true;
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }
      final map = jsonDecode(utf8.decode(base64Decode(payload)));
      if (map is Map && map['exp'] is num) {
        return (map['exp'] as num) * 1000 < DateTime.now().millisecondsSinceEpoch;
      }
      return false;
    } catch (_) {
      return true;
    }
  }
}
