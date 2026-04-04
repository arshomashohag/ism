/// Platform-aware printing service abstraction.
library;

import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'printing_service_other.dart'
    if (dart.library.io) 'printing_service_other.dart';

/// Abstract interface for platform-specific print operations.
///
/// Use [PrintingService.instance] to obtain the correct implementation
/// for the current platform at runtime.
abstract class PrintingService {
  /// Returns the platform-appropriate [PrintingService] implementation.
  ///
  /// - macOS / Windows: delegates to the `printing` package (PDF printing
  ///   via native print panel).
  /// - Web / Android / iOS: same `printing` package delegate.
  ///
  /// A Windows-native Win32 implementation can be substituted here
  /// when thermal ESC/POS printing is required (Phase 2 S13 Windows).
  static PrintingService get instance => _instance;

  static final PrintingService _instance = _resolve();

  static PrintingService _resolve() {
    return OtherPrintingService();
  }

  /// Sends [pdfBytes] to the platform print dialog.
  ///
  /// :param pdfBytes: Raw PDF bytes to print.
  /// :param name: Document name shown in the print dialog.
  /// :return: Future that completes when the print job is dispatched.
  Future<void> printDocument({
    required Uint8List pdfBytes,
    required String name,
  });
}
