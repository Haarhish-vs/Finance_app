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

  /// Backend API base URL.
  /// Can be overridden at build/run time via `--dart-define=API_BASE_URL=https://your-api.com/api/v1`
  static String get apiBaseUrl {
    const String customUrl = String.fromEnvironment('API_BASE_URL');
    if (customUrl.isNotEmpty) {
      return customUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:5000/api/v1';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Default to 127.0.0.1 which connects directly when using `adb reverse` or device bridge
        return 'http://127.0.0.1:5000/api/v1';
      case TargetPlatform.iOS:
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      default:
        return 'http://localhost:5000/api/v1';
    }
  }

  /// List of candidate base URLs to automatically try if the primary URL is unreachable
  static List<String> get candidateBaseUrls {
    const String customUrl = String.fromEnvironment('API_BASE_URL');
    if (customUrl.isNotEmpty) {
      return [customUrl];
    }

    if (kIsWeb) {
      return ['http://localhost:5000/api/v1', 'http://127.0.0.1:5000/api/v1'];
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return [
        'http://127.0.0.1:5000/api/v1',
        'http://10.206.134.75:5000/api/v1',
        'http://10.0.2.2:5000/api/v1',
        'http://localhost:5000/api/v1',
      ];
    }

    return [
      'http://localhost:5000/api/v1',
      'http://127.0.0.1:5000/api/v1',
    ];
  }

  /// Fast timeout for HTTP network requests so UI never hangs
  static const Duration requestTimeout = Duration(seconds: 4);

  /// Environment mode check
  static bool get isDevelopment => kDebugMode;
}
