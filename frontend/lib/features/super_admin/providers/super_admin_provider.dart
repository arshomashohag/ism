/// Providers for super admin state management.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/super_admin_repository.dart';
import '../domain/super_admin_models.dart';

/// Global super admin repository instance.
final superAdminRepositoryProvider = Provider<SuperAdminRepository>(
  (_) => SuperAdminRepository(),
);

/// Super admin authentication state.
///
/// Holds the email of the authenticated super admin, or null.
class SuperAdminAuthNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final repo = ref.read(superAdminRepositoryProvider);
    final token = await repo.loadToken();
    return token != null ? 'authenticated' : null;
  }

  /// Persist a newly issued super admin token.
  Future<void> setToken(String token) async {
    await ref.read(superAdminRepositoryProvider).saveToken(token);
    state = const AsyncValue.data('authenticated');
  }

  /// Clear the super admin session.
  Future<void> logout() async {
    await ref.read(superAdminRepositoryProvider).clearToken();
    state = const AsyncValue.data(null);
  }
}

/// Provider for [SuperAdminAuthNotifier].
final superAdminAuthProvider =
    AsyncNotifierProvider<SuperAdminAuthNotifier, String?>(
  SuperAdminAuthNotifier.new,
);

/// Paginated tenant list state.
class TenantListNotifier extends AutoDisposeAsyncNotifier<TenantPage> {
  int _page = 1;

  @override
  Future<TenantPage> build() => _fetch();

  Future<TenantPage> _fetch() {
    return ref
        .read(superAdminRepositoryProvider)
        .listTenants(page: _page);
  }

  /// Reload the tenant list from page 1.
  Future<void> refresh() async {
    _page = 1;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Navigate to [page].
  Future<void> goToPage(int page) async {
    _page = page;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Suspend or reactivate a tenant by [slug].
  Future<void> setActive(String slug, {required bool active}) async {
    await ref.read(superAdminRepositoryProvider).updateTenant(
          slug,
          isActive: active,
        );
    await refresh();
  }

  /// Change a tenant's plan.
  Future<void> setPlan(String slug, String plan) async {
    await ref.read(superAdminRepositoryProvider).updateTenant(
          slug,
          plan: plan,
        );
    await refresh();
  }

  /// Provision a new tenant and refresh the list.
  Future<void> provision({
    required String name,
    required String slug,
    required String plan,
    required String adminEmail,
    required String adminPassword,
  }) async {
    await ref.read(superAdminRepositoryProvider).provisionTenant(
          name: name,
          slug: slug,
          plan: plan,
          adminEmail: adminEmail,
          adminPassword: adminPassword,
        );
    await refresh();
  }
}

/// Provider for [TenantListNotifier].
final tenantListProvider = AsyncNotifierProvider.autoDispose<
    TenantListNotifier, TenantPage>(TenantListNotifier.new);

/// Platform health metrics provider.
final healthProvider = FutureProvider.autoDispose<PlatformHealth>(
  (ref) => ref.read(superAdminRepositoryProvider).getHealth(),
);

/// Paginated audit log state.
class AuditLogNotifier extends AutoDisposeAsyncNotifier<AuditLogPage> {
  int _page = 1;
  String? _entityType;
  String? _action;

  @override
  Future<AuditLogPage> build() => _fetch();

  Future<AuditLogPage> _fetch() {
    return ref.read(superAdminRepositoryProvider).getAuditLog(
          page: _page,
          entityType: _entityType,
          action: _action,
        );
  }

  /// Reload with optional filter updates.
  Future<void> refresh({String? entityType, String? action}) async {
    _page = 1;
    if (entityType != null) _entityType = entityType;
    if (action != null) _action = action;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Navigate to [page].
  Future<void> goToPage(int page) async {
    _page = page;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Clear all filters.
  Future<void> clearFilters() async {
    _entityType = null;
    _action = null;
    _page = 1;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }
}

/// Provider for [AuditLogNotifier].
final auditLogProvider = AsyncNotifierProvider.autoDispose<
    AuditLogNotifier, AuditLogPage>(AuditLogNotifier.new);
