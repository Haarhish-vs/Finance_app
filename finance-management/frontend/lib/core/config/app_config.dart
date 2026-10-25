import 'package:flutter/foundation.dart';

/// Application configuration and environment settings.
///
/// NOTE: Supabase secret keys must NEVER be placed in the frontend app.
/// All database operations are proxied through our backend API at [apiBaseUrl].
class AppConfig {
  AppConfig._();

  /// Application display name
  static const String appName = 'Finance Manager';

  /// Application version
  static const String appVersion = '1.0.0';

  /// Admin identity title
  static const String adminRoleTitle = 'Single Administrator';

  /// Backend API base URL deployed on Render.
  /// Can be overridden at build/run time via `--dart-define=API_BASE_URL=https://your-api.com/api/v1`
  static String get apiBaseUrl {
    const String customUrl = String.fromEnvironment('API_BASE_URL');
    if (customUrl.isNotEmpty) {
      return customUrl;
    }

    return 'https://finance-app-odjk.onrender.com/api/v1';
  }

  /// List of candidate base URLs to automatically try if the primary URL is unreachable
  static List<String> get candidateBaseUrls {
    const String customUrl = String.fromEnvironment('API_BASE_URL');
    if (customUrl.isNotEmpty) {
      return [customUrl];
    }

    // In production / release builds, strictly use the deployed HTTPS endpoint
    if (kReleaseMode) {
      return [apiBaseUrl];
    }

    // In local development / debug builds, allow local server fallback
    return [
      apiBaseUrl,
      'http://127.0.0.1:5000/api/v1',
      'http://localhost:5000/api/v1',
    ];
  }

  /// Timeout for HTTP network requests (45s ensures cloud spin-up resilience)
  static const Duration requestTimeout = Duration(seconds: 45);

  /// Environment mode check
  static bool get isDevelopment => kDebugMode;
}
