/// Auth state domain objects.
library;

/// Authentication status of the current session.
enum AuthStatus {
  /// Status not yet determined (reading from storage).
  unknown,

  /// User has valid tokens.
  authenticated,

  /// No valid tokens found.
  unauthenticated,
}

/// Holds the current authentication state and tokens.
class AuthState {
  /// Creates an [AuthState].
  const AuthState({
    required this.status,
    this.accessToken,
    this.refreshToken,
    this.userRole,
  });

  /// Creates an initial unknown state.
  const AuthState.unknown()
      : status = AuthStatus.unknown,
        accessToken = null,
        refreshToken = null,
        userRole = null;

  /// Creates an unauthenticated state.
  const AuthState.unauthenticated()
      : status = AuthStatus.unauthenticated,
        accessToken = null,
        refreshToken = null,
        userRole = null;

  /// Authentication status.
  final AuthStatus status;

  /// JWT access token, null when unauthenticated.
  final String? accessToken;

  /// JWT refresh token, null when unauthenticated.
  final String? refreshToken;

  /// User role from the access token claims.
  final String? userRole;
}
