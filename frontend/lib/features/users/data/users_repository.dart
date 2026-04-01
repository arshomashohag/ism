/// Users repository — API calls for user management.
library;

import '../../../core/network/api_client.dart';
import '../domain/app_user.dart';

/// Handles all user management API calls.
class UsersRepository {
  /// Creates a [UsersRepository].
  UsersRepository({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  /// Fetch a paginated list of users.
  Future<UserPage> listUsers({
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    final data =
        await _client.get('/users/', query: query);
    return UserPage.fromJson(
        data as Map<String, dynamic>);
  }

  /// Create a new user.
  Future<AppUser> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
      'role': role,
    };
    final data =
        await _client.post('/users/', body: body);
    return AppUser.fromJson(
        data as Map<String, dynamic>);
  }

  /// Partially update a user.
  Future<AppUser> updateUser(
    String id, {
    String? name,
    String? role,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (role != null) 'role': role,
      if (isActive != null) 'is_active': isActive,
    };
    final data =
        await _client.patch('/users/$id', body: body);
    return AppUser.fromJson(
        data as Map<String, dynamic>);
  }

  /// Soft-delete a user (set is_active=false).
  Future<void> deleteUser(String id) async {
    await _client.delete('/users/$id');
  }
}
