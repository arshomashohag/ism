/// Isar local database singleton.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

/// Manages the single Isar database instance.
///
/// Collections are registered here as they are added in Step 2+.
/// Call [open] once at app startup before using [isar].
class IsarService {
  IsarService._();

  static final IsarService _instance = IsarService._();

  /// Returns the shared [IsarService] instance.
  static IsarService get instance => _instance;

  Isar? _isar;

  /// The open [Isar] database instance.
  ///
  /// Throws [StateError] if [open] has not been called yet.
  Isar get isar {
    if (_isar == null) {
      throw StateError('IsarService.open() must be called before use');
    }
    return _isar!;
  }

  /// Opens the Isar database with the registered collection schemas.
  ///
  /// No-op on web (Isar requires native file system access).
  /// Safe to call multiple times — subsequent calls are no-ops.
  Future<void> open() async {
    if (kIsWeb || _isar != null) return;

    final dir = await getApplicationDocumentsDirectory();

    // Collections are added here as domain models are introduced
    // in Step 2+ (e.g. ProductSchema, SaleSchema, etc.)
    _isar = await Isar.open(
      [],
      directory: dir.path,
    );
  }

  /// Closes the database. Primarily used in tests.
  Future<void> close() async {
    await _isar?.close();
    _isar = null;
  }
}
