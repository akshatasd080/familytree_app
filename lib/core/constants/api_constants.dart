class ApiConstants {
  ApiConstants._();

  /// Backend API base URL.
  ///
  /// Local / LAN default for development.
  /// Play Store / production build — pass HTTPS URL:
  ///   flutter build appbundle --dart-define=API_BASE_URL=https://YOUR_API/api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.3:3004/api',
  );

  /// Matches web localStorage key `LMS_accessToken`
  static const String accessTokenKey = 'LMS_accessToken';
}
