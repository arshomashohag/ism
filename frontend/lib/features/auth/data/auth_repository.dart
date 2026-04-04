/// Auth repository — login, logout, token refresh via backend API.
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../domain/auth_state.dart';

const _kAccessToken = 'access_token';
const _kRefreshToken = 'refresh_token';
const _kTenantSlug = 'tenant_slug';

/// Handles authentication API calls and token persistence.
class AuthRepository {
  /// Creates an [AuthRepository].
  AuthRepository({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// Return a list of active tenant slugs from the public endpoint.
  ///
  /// Throws [ApiException] on failure.
  Future<List<String>> fetchTenantSlugs() async {
    final data = await ApiClient.instance.getPublic(
      '/admin/tenants/public',
    ) as List<dynamic>;
    return data.cast<String>();
  }

  /// Login with [email], [password], and [tenantSlug].
  ///
  /// Stores tokens and slug in secure storage on success.
  /// Throws [ApiException] on failure.
  Future<AuthState> login(
    String email,
    String password,
    String tenantSlug,
  ) async {
    final data = await ApiClient.instance.postPublic(
      '/auth/login',
      body: {
        'email': email,
        'password': password,
        'tenant_slug': tenantSlug,
      },
    ) as Map<String, dynamic>;

    final access = data['access_token'] as String;
    final refresh = data['refresh_token'] as String;
    await _saveTokens(access, refresh, tenantSlug);
    return AuthState(
      status: AuthStatus.authenticated,
      accessToken: access,
      refreshToken: refresh,
      userRole: _roleFromToken(access),
      tenantSlug: tenantSlug,
    );
  }

  /// Logout by blacklisting the refresh token on the server.
  ///
  /// Clears stored tokens regardless of server response.
  Future<void> logout(String refreshToken) async {
    try {
      await ApiClient.instance.post(
        '/auth/logout',
        body: {'refresh_token': refreshToken},
      );
    } finally {
      await _clearTokens();
    }
  }

  /// Refresh the token pair using [refreshToken].
  ///
  /// Stores new tokens on success, clears storage on failure.
  Future<AuthState> refreshTokens(String refreshToken) async {
    final data = await ApiClient.instance.postPublic(
      '/auth/refresh',
      body: {'refresh_token': refreshToken},
    ) as Map<String, dynamic>;

    final access = data['access_token'] as String;
    final refresh = data['refresh_token'] as String;
    final slug = await _storage.read(key: _kTenantSlug);
    await _saveTokens(access, refresh, slug ?? '');
    return AuthState(
      status: AuthStatus.authenticated,
      accessToken: access,
      refreshToken: refresh,
      userRole: _roleFromToken(access),
      tenantSlug: slug,
    );
  }

  /// Read stored tokens and return the current [AuthState].
  Future<AuthState> loadFromStorage() async {
    final access = await _storage.read(key: _kAccessToken);
    final refresh = await _storage.read(key: _kRefreshToken);
    final slug = await _storage.read(key: _kTenantSlug);
    if (access == null || refresh == null) {
      return const AuthState.unauthenticated();
    }
    return AuthState(
      status: AuthStatus.authenticated,
      accessToken: access,
      refreshToken: refresh,
      userRole: _roleFromToken(access),
      tenantSlug: slug,
    );
  }

  /// Read the access token from storage.
  Future<String?> getAccessToken() =>
      _storage.read(key: _kAccessToken);

  /// Read the refresh token from storage.
  Future<String?> getRefreshToken() =>
      _storage.read(key: _kRefreshToken);

  Future<void> _saveTokens(
    String access,
    String refresh,
    String slug,
  ) async {
    await Future.wait([
      _storage.write(key: _kAccessToken, value: access),
      _storage.write(key: _kRefreshToken, value: refresh),
      _storage.write(key: _kTenantSlug, value: slug),
    ]);
  }

  Future<void> _clearTokens() async {
    await Future.wait([
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
      _storage.delete(key: _kTenantSlug),
    ]);
  }

  String? _roleFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final claims = jsonDecode(payload) as Map<String, dynamic>;
      return claims['role'] as String?;
    } catch (_) {
      return null;
    }
  }
}
