/// HTTP API client using package:http.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;

import '../config.dart';
import '../storage/token_storage.dart';

const _kAccessToken = 'access_token';
const _kRefreshToken = 'refresh_token';

/// Wraps a non-2xx HTTP response.
class ApiException implements Exception {
  /// Creates an [ApiException].
  const ApiException(this.statusCode, this.body);

  /// HTTP status code.
  final int statusCode;

  /// Response body string.
  final String body;

  /// Parsed detail message if the body is JSON with a 'detail' key.
  String get message {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded.containsKey('detail')) {
        return decoded['detail'].toString();
      }
    } catch (_) {}
    return body;
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Singleton HTTP client for the IMS backend.
///
/// Automatically attaches the Bearer token from secure storage
/// and refreshes it on 401 responses.
class ApiClient {
  ApiClient._();

  static final ApiClient _instance = ApiClient._();

  /// Returns the shared [ApiClient] instance.
  static ApiClient get instance => _instance;

  final TokenStorage _storage = TokenStorage.instance;
  final http.Client _http = http.Client();
  bool _isRefreshing = false;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse(AppConfig.backendUrl);
    final params = query?.map((k, v) => MapEntry(k, v.toString()));
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.port,
      path: path,
      queryParameters: params?.isEmpty == true ? null : params,
    );
  }

  Future<Map<String, String>> _buildHeaders({String? token}) async {
    final t = token ?? await _storage.read(_kAccessToken);
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  void _log(String method, String path, int status) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('ApiClient [$method] $path → $status');
    }
  }

  dynamic _decode(http.Response response) {
    if (response.body.isEmpty) return null;
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  void _assertOk(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, response.body);
    }
  }

  /// Executes [call] and retries once with a refreshed token on 401.
  Future<http.Response> _send(
    Future<http.Response> Function(String? token) call,
  ) async {
    final token = await _storage.read(_kAccessToken);
    var response = await call(token);

    if (response.statusCode != 401 || _isRefreshing) {
      return response;
    }

    _isRefreshing = true;
    try {
      final refreshToken = await _storage.read(_kRefreshToken);
      if (refreshToken == null) return response;

      final refreshResp = await _http.post(
        _uri('/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (refreshResp.statusCode != 200) return response;

      final data =
          jsonDecode(refreshResp.body) as Map<String, dynamic>;
      final newAccess = data['access_token'] as String;
      final newRefresh = data['refresh_token'] as String;
      await Future.wait([
        _storage.write(_kAccessToken, newAccess),
        _storage.write(_kRefreshToken, newRefresh),
      ]);
      return call(newAccess);
    } finally {
      _isRefreshing = false;
    }
  }

  /// GET request. Returns decoded JSON.
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final response = await _send(
      (token) async => _http.get(
        _uri(path, query),
        headers: await _buildHeaders(token: token),
      ),
    );
    _log('GET', path, response.statusCode);
    _assertOk(response);
    return _decode(response);
  }

  /// POST request with optional JSON body. Returns decoded JSON.
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _send(
      (token) async => _http.post(
        _uri(path),
        headers: await _buildHeaders(token: token),
        body: body != null ? jsonEncode(body) : null,
      ),
    );
    _log('POST', path, response.statusCode);
    _assertOk(response);
    return _decode(response);
  }

  /// GET without auth (used for public endpoints like tenant list).
  Future<dynamic> getPublic(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final response = await _http.get(
      _uri(path, query),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
    _log('GET', path, response.statusCode);
    _assertOk(response);
    return _decode(response);
  }

  /// POST without auth (used for login/register).
  Future<dynamic> postPublic(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final response = await _http.post(
      _uri(path),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(body),
    );
    _log('POST', path, response.statusCode);
    _assertOk(response);
    return _decode(response);
  }

  /// PATCH request with JSON body. Returns decoded JSON.
  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _send(
      (token) async => _http.patch(
        _uri(path),
        headers: await _buildHeaders(token: token),
        body: body != null ? jsonEncode(body) : null,
      ),
    );
    _log('PATCH', path, response.statusCode);
    _assertOk(response);
    return _decode(response);
  }

  /// DELETE request.
  Future<void> delete(String path) async {
    final response = await _send(
      (token) async => _http.delete(
        _uri(path),
        headers: await _buildHeaders(token: token),
      ),
    );
    _log('DELETE', path, response.statusCode);
    _assertOk(response);
  }
}
