import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../models/admin_model.dart';

/// Repository managing Admin authentication, JWT token storage, and persistent login sessions.
class AuthRepository {
  static const String _keyToken = 'auth_admin_token';
  static const String _keyEmail = 'auth_admin_email';
  static const String _keyId = 'auth_admin_id';

  final ApiClient _apiClient;

  // In-memory fallback if platform storage is unavailable
  static String? _memToken;
  static AdminModel? _currentAdmin;

  AuthRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  AdminModel? get currentAdmin => _currentAdmin;
  bool get isAuthenticated => _currentAdmin != null || (_memToken != null && _memToken!.isNotEmpty);

  /// Authenticate admin credentials with backend
  Future<AdminModel> login({required String email, required String password}) async {
    final response = await _apiClient.post(
      '/auth/login',
      body: {
        'email': email.trim(),
        'password': password.trim(),
      },
    );

    final data = response['data'] as Map<String, dynamic>;
    final token = data['token'] as String;
    final adminJson = data['admin'] as Map<String, dynamic>;
    final admin = AdminModel.fromJson(adminJson);

    _memToken = token;
    _currentAdmin = admin;
    ApiClient.setAuthToken(token);

    // Save to persistent storage
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyToken, token);
      await prefs.setString(_keyEmail, admin.email);
      await prefs.setString(_keyId, admin.id);
    } catch (e) {
      debugPrint('[AuthRepository] SharedPreferences save error: $e');
    }

    return admin;
  }

  /// Restores persistent session on application start
  Future<AdminModel?> restoreSession() async {
    String? savedToken;
    try {
      final prefs = await SharedPreferences.getInstance();
      savedToken = prefs.getString(_keyToken);
    } catch (e) {
      debugPrint('[AuthRepository] SharedPreferences read error: $e');
      savedToken = _memToken;
    }

    if (savedToken == null || savedToken.isEmpty) {
      return null;
    }

    ApiClient.setAuthToken(savedToken);
    _memToken = savedToken;

    try {
      final response = await _apiClient.get('/auth/me');
      final data = response['data'] as Map<String, dynamic>;
      final admin = AdminModel.fromJson(data);
      _currentAdmin = admin;
      return admin;
    } catch (e) {
      debugPrint('[AuthRepository] Session verification failed: $e');
      await logout();
      return null;
    }
  }

  /// Terminates the current admin session
  Future<void> logout() async {
    try {
      if (ApiClient.authToken != null) {
        await _apiClient.post('/auth/logout');
      }
    } catch (_) {
      // Best-effort remote logout
    } finally {
      _memToken = null;
      _currentAdmin = null;
      ApiClient.setAuthToken(null);

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_keyToken);
        await prefs.remove(_keyEmail);
        await prefs.remove(_keyId);
      } catch (_) {}
    }
  }
}

