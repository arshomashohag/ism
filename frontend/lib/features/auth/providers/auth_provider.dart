/// Auth state provider — manages login/logout/refresh lifecycle.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/auth_state.dart';

/// Global auth repository instance.
final authRepositoryProvider = Provider<AuthRepository>(
  (_) => AuthRepository(),
);

/// Async notifier that manages [AuthState].
class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final repo = ref.read(authRepositoryProvider);
    return repo.loadFromStorage();
  }

  /// Login with [email] and [password].
  ///
  /// Updates state to authenticated on success or rethrows on failure.
  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() {
      return ref.read(authRepositoryProvider).login(email, password);
    });
  }

  /// Logout the current user.
  Future<void> logout() async {
    final current = state.valueOrNull;
    if (current?.refreshToken != null) {
      await ref
          .read(authRepositoryProvider)
          .logout(current!.refreshToken!);
    }
    state = const AsyncValue.data(AuthState.unauthenticated());
  }

  /// Refresh tokens using the stored refresh token.
  ///
  /// Used by the Dio interceptor on 401 responses.
  Future<AuthState?> refreshTokens() async {
    final repo = ref.read(authRepositoryProvider);
    final refreshToken = await repo.getRefreshToken();
    if (refreshToken == null) {
      state = const AsyncValue.data(AuthState.unauthenticated());
      return null;
    }
    try {
      final newState = await repo.refreshTokens(refreshToken);
      state = AsyncValue.data(newState);
      return newState;
    } catch (_) {
      state = const AsyncValue.data(AuthState.unauthenticated());
      return null;
    }
  }
}

/// Provider for [AuthNotifier].
final authProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
