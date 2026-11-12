class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.data,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final dynamic data;

  bool get isFamilyInactive => code == 'FAMILY_INACTIVE';

  @override
  String toString() => message;
}
