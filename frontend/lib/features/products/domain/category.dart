/// Category domain entity.
library;

/// Represents a product category (possibly nested).
class Category {
  /// Creates a [Category].
  const Category({
    required this.id,
    required this.name,
    required this.tenantId,
    this.parentId,
    this.children = const [],
  });

  /// Category UUID.
  final String id;

  /// Category display name.
  final String name;

  /// Tenant this category belongs to.
  final String tenantId;

  /// Parent category UUID, null for root categories.
  final String? parentId;

  /// Nested child categories.
  final List<Category> children;

  /// Deserializes from a backend JSON map.
  factory Category.fromJson(Map<String, dynamic> json) {
    final rawChildren =
        json['children'] as List<dynamic>? ?? [];
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      tenantId: json['tenant_id'] as String,
      parentId: json['parent_id'] as String?,
      children: rawChildren
          .map((c) => Category.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}
