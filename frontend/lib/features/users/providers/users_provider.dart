/// Users Riverpod providers — user list management.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/users_repository.dart';
import '../domain/app_user.dart';

// ── Repository ────────────────────────────────────────────────

/// Singleton users repository provider.
final usersRepositoryProvider = Provider<UsersRepository>(
  (_) => UsersRepository(),
);

// ── User list ─────────────────────────────────────────────────

/// Immutable state for the users list screen.
class UserListState {
  /// Creates a [UserListState].
  const UserListState({
    this.users = const [],
    this.total = 0,
    this.page = 1,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.hasMore = true,
  });

  /// Current page of users.
  final List<AppUser> users;

  /// Total matching users.
  final int total;

  /// Current page number.
  final int page;

  /// Whether initial load is in progress.
  final bool isLoading;

  /// Whether a subsequent page is loading.
  final bool isLoadingMore;

  /// Error message if load failed.
  final String? error;

  /// Whether more pages exist.
  final bool hasMore;

  /// Returns a copy with overridden fields.
  UserListState copyWith({
    List<AppUser>? users,
    int? total,
    int? page,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool? hasMore,
    bool clearError = false,
  }) {
    return UserListState(
      users: users ?? this.users,
      total: total ?? this.total,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : error ?? this.error,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Manages the paginated user list state.
class UserListNotifier
    extends AutoDisposeNotifier<UserListState> {
  static const _pageSize = 20;

  @override
  UserListState build() {
    Future.microtask(refresh);
    return const UserListState(isLoading: true);
  }

  /// Reload the first page of users.
  Future<void> refresh() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );
    try {
      final page = await ref
          .read(usersRepositoryProvider)
          .listUsers(page: 1, pageSize: _pageSize);
      state = state.copyWith(
        users: page.items,
        total: page.total,
        page: 1,
        isLoading: false,
        hasMore: page.items.length >= _pageSize,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load the next page and append results.
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.page + 1;
      final page = await ref
          .read(usersRepositoryProvider)
          .listUsers(page: nextPage, pageSize: _pageSize);
      state = state.copyWith(
        users: [...state.users, ...page.items],
        total: page.total,
        page: nextPage,
        isLoadingMore: false,
        hasMore: page.items.length >= _pageSize,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Prepend a newly created user to the list.
  void addUser(AppUser user) {
    state = state.copyWith(
      users: [user, ...state.users],
      total: state.total + 1,
    );
  }

  /// Replace an existing user entry in the list.
  void replaceUser(AppUser updated) {
    state = state.copyWith(
      users: state.users
          .map((u) => u.id == updated.id ? updated : u)
          .toList(),
    );
  }
}

/// Provider for [UserListNotifier].
final userListProvider = AutoDisposeNotifierProvider<
    UserListNotifier, UserListState>(UserListNotifier.new);
