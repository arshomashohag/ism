/// Domain models for the super admin panel.
library;

/// A tenant record as seen by the super admin.
class SuperAdminTenant {
  /// Creates a [SuperAdminTenant].
  const SuperAdminTenant({
    required this.id,
    required this.name,
    required this.slug,
    required this.plan,
    required this.isActive,
    required this.schemaName,
    required this.createdAt,
  });

  /// Deserialise from API JSON map.
  factory SuperAdminTenant.fromJson(Map<String, dynamic> json) {
    return SuperAdminTenant(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      plan: json['plan'] as String,
      isActive: json['is_active'] as bool,
      schemaName: json['schema_name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Tenant UUID.
  final String id;

  /// Shop / business display name.
  final String name;

  /// URL-safe unique identifier.
  final String slug;

  /// Subscription plan tier.
  final String plan;

  /// Whether the account is active.
  final bool isActive;

  /// PostgreSQL schema name.
  final String schemaName;

  /// Provisioning timestamp.
  final DateTime createdAt;
}

/// Paginated list of tenants.
class TenantPage {
  /// Creates a [TenantPage].
  const TenantPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  /// Deserialise from API JSON map.
  factory TenantPage.fromJson(Map<String, dynamic> json) {
    final rawItems =
        (json['items'] as List).cast<Map<String, dynamic>>();
    return TenantPage(
      items: rawItems.map(SuperAdminTenant.fromJson).toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      pageSize: json['page_size'] as int,
    );
  }

  /// Tenant records on this page.
  final List<SuperAdminTenant> items;

  /// Total tenant count across all pages.
  final int total;

  /// Current page number (1-based).
  final int page;

  /// Items per page.
  final int pageSize;
}

/// Platform health snapshot.
class PlatformHealth {
  /// Creates a [PlatformHealth].
  const PlatformHealth({
    required this.ecsRunningTasks,
    required this.ecsTasks,
    required this.rdsConnections,
    required this.rdsConnectionsLimit,
  });

  /// Deserialise from API JSON map.
  factory PlatformHealth.fromJson(Map<String, dynamic> json) {
    final rawTasks =
        (json['ecs_tasks'] as List).cast<Map<String, dynamic>>();
    return PlatformHealth(
      ecsRunningTasks: json['ecs_running_tasks'] as int,
      ecsTasks: rawTasks.map(EcsTaskInfo.fromJson).toList(),
      rdsConnections: json['rds_connections'] as int,
      rdsConnectionsLimit: json['rds_connections_limit'] as int,
    );
  }

  /// Number of running ECS tasks.
  final int ecsRunningTasks;

  /// Per-task details.
  final List<EcsTaskInfo> ecsTasks;

  /// Current active RDS connection count.
  final int rdsConnections;

  /// Configured max_connections limit.
  final int rdsConnectionsLimit;
}

/// Summary of a single ECS task.
class EcsTaskInfo {
  /// Creates an [EcsTaskInfo].
  const EcsTaskInfo({
    required this.taskArn,
    required this.status,
    required this.cpu,
    required this.memory,
  });

  /// Deserialise from API JSON map.
  factory EcsTaskInfo.fromJson(Map<String, dynamic> json) {
    return EcsTaskInfo(
      taskArn: json['task_arn'] as String,
      status: json['status'] as String,
      cpu: json['cpu'] as String,
      memory: json['memory'] as String,
    );
  }

  /// Full task ARN.
  final String taskArn;

  /// Last known status string.
  final String status;

  /// CPU units allocated.
  final String cpu;

  /// Memory MiB allocated.
  final String memory;
}

/// A single audit-log entry.
class AuditLogEntry {
  /// Creates an [AuditLogEntry].
  const AuditLogEntry({
    required this.id,
    required this.tenantId,
    required this.userId,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.createdAt,
  });

  /// Deserialise from API JSON map.
  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String?,
      userId: json['user_id'] as String?,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      action: json['action'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Entry UUID.
  final String id;

  /// Owning tenant UUID (may be null).
  final String? tenantId;

  /// Acting user UUID (may be null).
  final String? userId;

  /// Affected table name.
  final String entityType;

  /// Affected row identifier.
  final String entityId;

  /// Action type: create | update | delete | void.
  final String action;

  /// When the action occurred.
  final DateTime createdAt;
}

/// Paginated audit log.
class AuditLogPage {
  /// Creates an [AuditLogPage].
  const AuditLogPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  /// Deserialise from API JSON map.
  factory AuditLogPage.fromJson(Map<String, dynamic> json) {
    final rawItems =
        (json['items'] as List).cast<Map<String, dynamic>>();
    return AuditLogPage(
      items: rawItems.map(AuditLogEntry.fromJson).toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      pageSize: json['page_size'] as int,
    );
  }

  /// Log entries on this page.
  final List<AuditLogEntry> items;

  /// Total matching entries.
  final int total;

  /// Current page (1-based).
  final int page;

  /// Items per page.
  final int pageSize;
}
