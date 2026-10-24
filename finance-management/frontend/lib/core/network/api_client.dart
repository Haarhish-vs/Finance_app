import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'api_exception.dart';

/// Central HTTP API Client for all backend interactions.
///
/// NOTE: The frontend communicates ONLY with our Express backend.
/// Supabase secret keys are never handled on the client side.
class ApiClient {
  final http.Client _client;
  String _baseUrl;
  final Duration _timeout;

  /// Cached working base URL across API client instances
  static String? _activeBaseUrl;

  ApiClient({
    http.Client? client,
    String? baseUrl,
    Duration? timeout,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? _activeBaseUrl ?? AppConfig.apiBaseUrl,
        _timeout = timeout ?? AppConfig.requestTimeout;

  /// Base URL used by this client instance
  String get baseUrl => _activeBaseUrl ?? _baseUrl;

  /// Default headers sent with each request
  Map<String, String> get _defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Uri _buildUri(String baseUrl, String endpoint, [Map<String, dynamic>? queryParameters]) {
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final fullUrl = '$baseUrl$cleanEndpoint';

    final uri = Uri.parse(fullUrl);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      final stringParams = queryParameters.map(
        (key, value) => MapEntry(key, value.toString()),
      );
      return uri.replace(queryParameters: stringParams);
    }
    return uri;
  }

  /// Sends a GET request
  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    return _sendRequest(
      (base) => _client.get(
        _buildUri(base, endpoint, queryParameters),
        headers: {..._defaultHeaders, ...?headers},
      ),
    );
  }

  /// Sends a POST request
  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    return _sendRequest(
      (base) => _client.post(
        _buildUri(base, endpoint),
        headers: {..._defaultHeaders, ...?headers},
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  /// Sends a PUT request
  Future<dynamic> put(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    return _sendRequest(
      (base) => _client.put(
        _buildUri(base, endpoint),
        headers: {..._defaultHeaders, ...?headers},
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  /// Sends a PATCH request
  Future<dynamic> patch(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    return _sendRequest(
      (base) => _client.patch(
        _buildUri(base, endpoint),
        headers: {..._defaultHeaders, ...?headers},
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  /// Sends a DELETE request
  Future<dynamic> delete(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    return _sendRequest(
      (base) => _client.delete(
        _buildUri(base, endpoint),
        headers: {..._defaultHeaders, ...?headers},
      ),
    );
  }

  Future<dynamic> _sendRequest(Future<http.Response> Function(String baseUrl) requestFn) async {
    final List<String> candidates = _activeBaseUrl != null
        ? [_activeBaseUrl!]
        : [_baseUrl, ...AppConfig.candidateBaseUrls.where((u) => u != _baseUrl)];

    Object? lastError;

    for (final candidate in candidates) {
      try {
        final response = await requestFn(candidate).timeout(_timeout);
        final result = _handleResponse(response);
        _activeBaseUrl = candidate;
        _baseUrl = candidate;
        return result;
      } on TimeoutException {
        lastError = ApiException.timeout();
      } on SocketException catch (e) {
        lastError = ApiException.networkError(e.message);
      } on http.ClientException catch (e) {
        lastError = ApiException.networkError(e.message);
      } catch (e) {
        if (e is ApiException) {
          _activeBaseUrl = candidate;
          _baseUrl = candidate;
          rethrow;
        }
        lastError = e;
      }
    }

    if (lastError is ApiException) throw lastError;
    throw ApiException(
      message: lastError?.toString() ?? 'Unable to connect to backend server.',
      code: 'CONNECTION_FAILED',
    );
  }

  dynamic _handleResponse(http.Response response) {
    dynamic parsedBody;
    try {
      if (response.body.isNotEmpty) {
        parsedBody = jsonDecode(response.body);
      }
    } catch (_) {
      parsedBody = response.body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return parsedBody;
    }

    debugPrint(
      '[ApiClient Error] ${response.request?.method} ${response.request?.url} -> HTTP ${response.statusCode}',
    );

    throw ApiException.fromResponse(response.statusCode, parsedBody);
  }

  void close() {
    _client.close();
  }
}
