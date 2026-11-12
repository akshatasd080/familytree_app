class ApiConstants {
  ApiConstants._();

  /// Same default as web `VITE_BASE_URL` in tree_frontend/.env
  /// Android emulator: use http://10.0.2.2:3004/api
  /// Physical device: use your PC LAN IP, e.g. http://192.168.1.10:3004/api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.3:3004/api',
  );

  /// Matches web localStorage key `LMS_accessToken`
  static const String accessTokenKey = 'LMS_accessToken';
}
