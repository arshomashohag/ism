/// Products repository — API calls for products and categories.
library;

import '../../../core/network/api_client.dart';
import '../domain/category.dart';
import '../domain/product.dart';

/// Handles all product and category API calls.
class ProductsRepository {
  /// Creates a [ProductsRepository].
  ProductsRepository({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  // ── Products ────────────────────────────────────────────────

  /// Fetch a paginated, optionally filtered product list.
  Future<ProductPage> listProducts({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? categoryId,
    String? barcode,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
      if (search != null && search.isNotEmpty) 'search': search,
      if (categoryId != null) 'category_id': categoryId,
      if (barcode != null) 'barcode': barcode,
    };
    final data = await _client.get('/products/', query: query);
    return ProductPage.fromJson(data as Map<String, dynamic>);
  }

  /// Fetch a single product by [id].
  Future<Product> getProduct(String id) async {
    final data = await _client.get('/products/$id');
    return Product.fromJson(data as Map<String, dynamic>);
  }

  /// Create a new product. Requires admin or manager role.
  Future<Product> createProduct({
    required String sku,
    required String name,
    required double unitPrice,
    String? categoryId,
    String? barcode,
    double? costPrice,
    double? taxRate,
    Map<String, dynamic>? metadata,
  }) async {
    final body = <String, dynamic>{
      'sku': sku,
      'name': name,
      'unit_price': unitPrice,
      if (categoryId != null) 'category_id': categoryId,
      if (barcode != null) 'barcode': barcode,
      if (costPrice != null) 'cost_price': costPrice,
      if (taxRate != null) 'tax_rate': taxRate,
      if (metadata != null) 'metadata': metadata,
    };
    final data = await _client.post('/products/', body: body);
    return Product.fromJson(data as Map<String, dynamic>);
  }

  /// Partially update a product. Requires admin or manager role.
  Future<Product> updateProduct(
    String id, {
    String? name,
    double? unitPrice,
    String? categoryId,
    String? barcode,
    double? costPrice,
    double? taxRate,
    Map<String, dynamic>? metadata,
  }) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (unitPrice != null) 'unit_price': unitPrice,
      if (categoryId != null) 'category_id': categoryId,
      if (barcode != null) 'barcode': barcode,
      if (costPrice != null) 'cost_price': costPrice,
      if (taxRate != null) 'tax_rate': taxRate,
      if (metadata != null) 'metadata': metadata,
    };
    final data = await _client.patch('/products/$id', body: body);
    return Product.fromJson(data as Map<String, dynamic>);
  }

  /// Delete a product by [id] (soft-delete). Requires admin/manager.
  Future<void> deleteProduct(String id) async {
    await _client.delete('/products/$id');
  }

  // ── Categories ───────────────────────────────────────────────

  /// Fetch all categories as a nested tree.
  Future<List<Category>> listCategories() async {
    final data = await _client.get('/categories/');
    return (data as List<dynamic>)
        .map((c) => Category.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  /// Create a new category. Requires admin or manager role.
  Future<Category> createCategory({
    required String name,
    String? parentId,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      if (parentId != null) 'parent_id': parentId,
    };
    final data = await _client.post('/categories/', body: body);
    return Category.fromJson(data as Map<String, dynamic>);
  }
}
