/// Thrown when an API request fails, network is unreachable, or server returns an error.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode = 400,
    this.retryAfterSec,
  });

  final String code;
  final String message;
  final int statusCode;
  final int? retryAfterSec;

  bool get isOffline => code == 'offline';
  bool get isUnauthorized => statusCode == 401 || code == 'unauthorized';

  @override
  String toString() => 'ApiException($code, $message, status: $statusCode)';
}
