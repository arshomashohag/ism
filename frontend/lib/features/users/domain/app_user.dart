/// User domain objects for the users feature.
library;

/// Represents a tenant user account.
class AppUser {
  /// Creates an [AppUser].
  const AppUser({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  /// Deserialise from API JSON.
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// User UUID.
  final String id;

  /// Owning tenant UUID.
  final String tenantId;

  /// Display name.
  final String name;

  /// Login email.
  final String email;

  /// RBAC role: admin, manager, or salesman.
  final String role;

  /// Whether the account is active.
  final bool isActive;

  /// Account creation timestamp.
  final DateTime createdAt;

  /// Return a copy with selected fields replaced.
  AppUser copyWith({
    String? id,
    String? tenantId,
    String? name,
    String? email,
    String? role,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Paginated user list response.
class UserPage {
  /// Creates a [UserPage].
  const UserPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  /// Deserialise from API JSON.
  factory UserPage.fromJson(Map<String, dynamic> json) {
    return UserPage(
      items: (json['items'] as List<dynamic>)
          .map((e) => AppUser.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      pageSize: json['page_size'] as int,
    );
  }

  /// Users on this page.
  final List<AppUser> items;

  /// Total matching users across all pages.
  final int total;

  /// Current page number (1-based).
  final int page;

  /// Items per page.
  final int pageSize;
}
