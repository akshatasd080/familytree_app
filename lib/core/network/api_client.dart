import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import 'api_exception.dart';

typedef FamilyInactiveHandler = void Function();

/// Dio client matching tree_frontend `src/api/axios.js`.
class ApiClient {
  ApiClient({FamilyInactiveHandler? onFamilyInactive})
      : _onFamilyInactive = onFamilyInactive {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        headers: {'Accept': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString(ApiConstants.accessTokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          final data = error.response?.data;
          final code = data is Map ? data['code']?.toString() : null;
          if (code == 'FAMILY_INACTIVE') {
            clearToken();
            _onFamilyInactive?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  late final Dio _dio;
  final FamilyInactiveHandler? _onFamilyInactive;

  Dio get dio => _dio;

  Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiConstants.accessTokenKey, token);
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiConstants.accessTokenKey);
    _dio.options.headers.remove('Authorization');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(ApiConstants.accessTokenKey);
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) =>
      _guard(() => _dio.get<T>(path, queryParameters: queryParameters));

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      _guard(
        () => _dio.post<T>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
        ),
      );

  Future<Response<T>> put<T>(String path, {dynamic data}) =>
      _guard(() => _dio.put<T>(path, data: data));

  Future<Response<T>> patch<T>(String path, {dynamic data}) =>
      _guard(() => _dio.patch<T>(path, data: data));

  Future<Response<T>> delete<T>(String path, {dynamic data}) =>
      _guard(() => _dio.delete<T>(path, data: data));

  Future<Response<T>> _guard<T>(Future<Response<T>> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  ApiException _mapError(DioException e) {
    final data = e.response?.data;
    String message = e.message ?? 'Request failed';
    String? code;
    if (data is Map) {
      message = (data['message'] ?? data['error'] ?? message).toString();
      code = data['code']?.toString();
    }
    if (kDebugMode) {
      debugPrint('API error ${e.response?.statusCode}: $message');
    }
    return ApiException(
      message: message,
      statusCode: e.response?.statusCode,
      code: code,
      data: data,
    );
  }
}
