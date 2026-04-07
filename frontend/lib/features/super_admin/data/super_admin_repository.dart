/// Repository for super admin API calls.
library;

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/super_admin_models.dart';

const _kSuperAdminToken = 'super_admin_token';

/// Provides access to /sadmin endpoints.
class SuperAdminRepository {
  /// Creates a [SuperAdminRepository].
  SuperAdminRepository()
      : _client = ApiClient.instance,
        _storage = TokenStorage.instance;

  final ApiClient _client;
  final TokenStorage _storage;

  /// Persist the super admin JWT to local storage.
  Future<void> saveToken(String token) =>
      _storage.write(_kSuperAdminToken, token);

  /// Load the super admin JWT from local storage.
  Future<String?> loadToken() =>
      _storage.read(_kSuperAdminToken);

  /// Clear the super admin JWT from local storage.
  Future<void> clearToken() =>
      _storage.delete(_kSuperAdminToken);

  /// Initiate WebAuthn registration and return the options + challenge.
  Future<Map<String, dynamic>> initiateRegistration(
    String email,
  ) async {
    final data = await _client.postPublic(
      '/sadmin/auth/register-key',
      body: {'email': email},
    );
    return data as Map<String, dynamic>;
  }

  /// Submit the registration credential and receive a JWT on success.
  Future<String> verifyRegistration({
    required String email,
    required Map<String, dynamic> credential,
    required String challenge,
    required String origin,
  }) async {
    final data = await _client.postPublic(
      '/sadmin/auth/verify-registration',
      body: {
        'email': email,
        'credential': credential,
        'challenge': challenge,
        'origin': origin,
      },
    );
    final json = data as Map<String, dynamic>;
    return json['access_token'] as String;
  }

  /// Initiate WebAuthn authentication and return options + challenge.
  Future<Map<String, dynamic>> initiateAuthentication(
    String email,
  ) async {
    final data = await _client.postPublic(
      '/sadmin/auth/authenticate',
      body: {'email': email},
    );
    return data as Map<String, dynamic>;
  }

  /// Submit the assertion credential and receive a JWT on success.
  Future<String> verifyAuthentication({
    required String email,
    required Map<String, dynamic> credential,
    required String challenge,
    required String origin,
  }) async {
    final data = await _client.postPublic(
      '/sadmin/auth/verify-authentication',
      body: {
        'email': email,
        'credential': credential,
        'challenge': challenge,
        'origin': origin,
      },
    );
    final json = data as Map<String, dynamic>;
    return json['access_token'] as String;
  }


  /// Fetch platform health metrics.
  Future<PlatformHealth> getHealth() async {
    final data = await _client.get('/sadmin/health');
    return PlatformHealth.fromJson(
      data as Map<String, dynamic>,
    );
  }

  /// Fetch a paginated list of tenants.
  Future<TenantPage> listTenants({int page = 1}) async {
    final data = await _client.get(
      '/sadmin/tenants',
      query: {'page': page, 'page_size': 20},
    );
    return TenantPage.fromJson(data as Map<String, dynamic>);
  }

  /// Provision a new tenant.
  Future<SuperAdminTenant> provisionTenant({
    required String name,
    required String slug,
    required String plan,
    required String adminEmail,
    required String adminPassword,
  }) async {
    final data = await _client.post(
      '/sadmin/tenants',
      body: {
        'name': name,
        'slug': slug,
        'plan': plan,
        'admin_email': adminEmail,
        'admin_password': adminPassword,
      },
    );
    return SuperAdminTenant.fromJson(
      data as Map<String, dynamic>,
    );
  }

  /// Update a tenant's plan or active status.
  Future<SuperAdminTenant> updateTenant(
    String slug, {
    String? plan,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (plan != null) body['plan'] = plan;
    if (isActive != null) body['is_active'] = isActive;

    final data = await _client.patch(
      '/sadmin/tenants/$slug',
      body: body,
    );
    return SuperAdminTenant.fromJson(
      data as Map<String, dynamic>,
    );
  }

  /// Trigger Alembic migration on a tenant schema.
  Future<void> migrateTenant(String slug) async {
    await _client.post('/sadmin/tenants/$slug/migrate');
  }

  /// Fetch paginated audit log with optional filters.
  Future<AuditLogPage> getAuditLog({
    int page = 1,
    String? entityType,
    String? action,
    String? tenantId,
  }) async {
    final query = <String, dynamic>{'page': page, 'page_size': 50};
    if (entityType != null) query['entity_type'] = entityType;
    if (action != null) query['action'] = action;
    if (tenantId != null) query['tenant_id'] = tenantId;

    final data = await _client.get('/sadmin/audit-log', query: query);
    return AuditLogPage.fromJson(data as Map<String, dynamic>);
  }
}
