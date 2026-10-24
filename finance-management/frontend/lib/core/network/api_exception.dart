/// Standardized API and network exception
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  final dynamic details;

  const ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.details,
  });

  @override
  String toString() {
    if (statusCode != null) {
      return 'ApiException [$statusCode - $code]: $message';
    }
    return 'ApiException: $message';
  }

  /// Factory for parsing standard backend error responses
  /// Format: { "success": false, "error": { "message": "...", "code": "...", "details": [...] } }
  factory ApiException.fromResponse(int statusCode, dynamic jsonBody) {
    if (jsonBody is Map<String, dynamic>) {
      final errorObj = jsonBody['error'];
      if (errorObj is Map<String, dynamic>) {
        return ApiException(
          message: errorObj['message']?.toString() ?? 'An error occurred',
          statusCode: statusCode,
          code: errorObj['code']?.toString() ?? 'UNKNOWN_ERROR',
          details: errorObj['details'],
        );
      }
      if (jsonBody['message'] != null) {
        return ApiException(
          message: jsonBody['message'].toString(),
          statusCode: statusCode,
          code: jsonBody['code']?.toString(),
        );
      }
    }

    return ApiException(
      message: 'Request failed with status code $statusCode',
      statusCode: statusCode,
      code: 'HTTP_$statusCode',
    );
  }

  factory ApiException.networkError([String? customMessage]) {
    return ApiException(
      message: customMessage ?? 'Unable to connect to the server. Please check network connection.',
      code: 'NETWORK_ERROR',
    );
  }

  factory ApiException.timeout([String? customMessage]) {
    return ApiException(
      message: customMessage ?? 'Request timed out while contacting server.',
      code: 'TIMEOUT_ERROR',
    );
  }
}
