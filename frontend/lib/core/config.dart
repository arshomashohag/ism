/// Application-wide configuration constants.
library;

/// Holds compile-time configuration for the IMS app.
///
/// Change [backendUrl] to match your dev environment:
/// - Android emulator: `http://10.0.2.2:8000`
/// - iOS simulator / macOS: `http://localhost:8000`
/// - Physical device: use your machine's LAN IP
class AppConfig {
  AppConfig._();

  /// Base URL of the IMS backend API.
  static const String backendUrl = 'http://localhost:8000';

  /// Connection timeout in seconds.
  static const int connectionTimeoutSeconds = 30;

  /// Receive timeout in seconds.
  static const int receiveTimeoutSeconds = 30;
}
