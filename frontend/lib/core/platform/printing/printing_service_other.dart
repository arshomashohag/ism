/// Printing service implementation for macOS, web, Android, and iOS.
library;

import 'dart:typed_data';

import 'package:printing/printing.dart';

import 'printing_service.dart';

/// Delegates printing to the `printing` package, which handles macOS
/// native print panel, browser window.print(), and Android/iOS system
/// print dialogs without requiring a custom platform channel.
class OtherPrintingService extends PrintingService {
  /// Creates an [OtherPrintingService].
  OtherPrintingService();

  /// Sends [pdfBytes] to the system print dialog via the `printing` package.
  ///
  /// :param pdfBytes: Raw PDF bytes to print.
  /// :param name: Document name shown in the print dialog.
  /// :return: Future that completes when the print job is dispatched.
  @override
  Future<void> printDocument({
    required Uint8List pdfBytes,
    required String name,
  }) async {
    await Printing.layoutPdf(
      name: name,
      onLayout: (_) async => pdfBytes,
    );
  }
}
