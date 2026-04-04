/// Auth repository — login, logout, token refresh via backend API.
library;

import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/auth_state.dart';

const _kAccessToken = 'access_token';
const _kRefreshToken = 'refresh_token';

/// Handles authentication API calls and token persistence.
class AuthRepository {
  /// Creates an [AuthRepository].
  AuthRepository({TokenStorage? storage})
      : _storage = storage ?? TokenStorage.instance;

  final TokenStorage _storage;

  /// Login with [email] and [password].
  ///
  /// Stores tokens on success.
  /// Throws [ApiException] on failure.
  Future<AuthState> login(String email, String password) async {
    final data = await ApiClient.instance.postPublic(
      '/auth/login',
      body: {'email': email, 'password': password},
    ) as Map<String, dynamic>;

    final access = data['access_token'] as String;
    final refresh = data['refresh_token'] as String;
    await _saveTokens(access, refresh);
    return AuthState(
      status: AuthStatus.authenticated,
      accessToken: access,
      refreshToken: refresh,
      userRole: _roleFromToken(access),
    );
  }

  /// Register a new shop account with [shopName], [adminName],
  /// [email], and [password].
  ///
  /// The slug is derived from [shopName] on the backend.
  /// Stores tokens on success.
  /// Throws [ApiException] on failure.
  Future<AuthState> register({
    required String shopName,
    required String adminName,
    required String email,
    required String password,
  }) async {
    final slug = _slugFromName(shopName);
    final data = await ApiClient.instance.postPublic(
      '/auth/register',
      body: {
        'shop_name': shopName,
        'slug': slug,
        'admin_name': adminName,
        'email': email,
        'password': password,
      },
    ) as Map<String, dynamic>;

    final access = data['access_token'] as String;
    final refresh = data['refresh_token'] as String;
    await _saveTokens(access, refresh);
    return AuthState(
      status: AuthStatus.authenticated,
      accessToken: access,
      refreshToken: refresh,
      userRole: _roleFromToken(access),
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
    await _saveTokens(access, refresh);
    return AuthState(
      status: AuthStatus.authenticated,
      accessToken: access,
      refreshToken: refresh,
      userRole: _roleFromToken(access),
    );
  }

  /// Read stored tokens and return the current [AuthState].
  Future<AuthState> loadFromStorage() async {
    final access = await _storage.read(_kAccessToken);
    final refresh = await _storage.read(_kRefreshToken);
    if (access == null || refresh == null) {
      return const AuthState.unauthenticated();
    }
    return AuthState(
      status: AuthStatus.authenticated,
      accessToken: access,
      refreshToken: refresh,
      userRole: _roleFromToken(access),
    );
  }

  /// Read the access token from storage.
  Future<String?> getAccessToken() => _storage.read(_kAccessToken);

  /// Read the refresh token from storage.
  Future<String?> getRefreshToken() => _storage.read(_kRefreshToken);

  Future<void> _saveTokens(String access, String refresh) async {
    await Future.wait([
      _storage.write(_kAccessToken, access),
      _storage.write(_kRefreshToken, refresh),
    ]);
  }

  Future<void> _clearTokens() async {
    await Future.wait([
      _storage.delete(_kAccessToken),
      _storage.delete(_kRefreshToken),
    ]);
  }

  String _slugFromName(String name) {
    return name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
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
