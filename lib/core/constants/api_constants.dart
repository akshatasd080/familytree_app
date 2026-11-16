enum Environment { local, uat, prod }

class ApiConstants {
  ApiConstants._();

  /// Default for release / Play Store builds.
  /// Override at build time:
  ///   flutter build appbundle --dart-define=API_BASE_URL=https://familytree.dhilwari.com/api
  static const Environment current = Environment.local;

  static const String _defineBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_defineBaseUrl.isNotEmpty) return _defineBaseUrl;
    switch (current) {
      case Environment.local:
        // Phone must use the PC's LAN address. localhost would be the phone itself.
        return 'http://192.168.1.15:3004/api';
      case Environment.uat:
        return 'https://familytree.dhilwari.com/api';
      case Environment.prod:
        return 'https://familytree.dhilwari.com/api';
    }
  }

  /// Matches web localStorage key `LMS_accessToken`
  static const String accessTokenKey = 'LMS_accessToken';
}
