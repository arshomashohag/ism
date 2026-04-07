/// POS keyboard shortcuts and barcode scanner stream.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

// ── Intent declarations ────────────────────────────────────────

/// Intent: focus the product search field (F2).
class FocusSearchIntent extends Intent {
  /// Creates a [FocusSearchIntent].
  const FocusSearchIntent();
}

/// Intent: trigger checkout (F4).
class CheckoutIntent extends Intent {
  /// Creates a [CheckoutIntent].
  const CheckoutIntent();
}

/// Intent: void the last completed sale (F8).
class VoidLastSaleIntent extends Intent {
  /// Creates a [VoidLastSaleIntent].
  const VoidLastSaleIntent();
}

// ── Shortcut bindings ──────────────────────────────────────────

/// Keyboard shortcut map for the POS screen.
///
/// Bind these in the [Shortcuts] widget wrapping [PosScreen].
const Map<ShortcutActivator, Intent> posKeyboardShortcuts =
    <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.f2): FocusSearchIntent(),
  SingleActivator(LogicalKeyboardKey.f4): CheckoutIntent(),
  SingleActivator(LogicalKeyboardKey.f8): VoidLastSaleIntent(),
};

// ── Barcode scanner stream ─────────────────────────────────────

/// Detects rapid keystroke sequences from a USB/Bluetooth barcode scanner.
///
/// Barcode scanners typically send all characters of a barcode within
/// 50–100 ms and terminate with Enter. This service buffers keystrokes
/// and emits the complete barcode string when Enter is received or when
/// the inter-keystroke gap exceeds [_timeoutMs].
class BarcodeScannerService {
  /// Creates a [BarcodeScannerService].
  BarcodeScannerService();

  static const int _timeoutMs = 100;

  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  final StringBuffer _buffer = StringBuffer();
  Timer? _debounce;

  /// Stream of complete barcode strings detected from scanner input.
  Stream<String> get barcodes => _controller.stream;

  /// Feed a [KeyEvent] from [Focus.onKeyEvent] into the scanner detector.
  ///
  /// :param event: The key event to process.
  /// :return: [KeyEventResult] indicating whether the event was consumed.
  KeyEventResult handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final logical = event.logicalKey;

    if (logical == LogicalKeyboardKey.enter) {
      _flush();
      return _buffer.isNotEmpty
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }

    final label = logical.keyLabel;
    if (label.length == 1) {
      _buffer.write(label);
      _debounce?.cancel();
      _debounce = Timer(
        const Duration(milliseconds: _timeoutMs),
        _flush,
      );
      return KeyEventResult.ignored;
    }

    return KeyEventResult.ignored;
  }

  void _flush() {
    _debounce?.cancel();
    final code = _buffer.toString().trim();
    _buffer.clear();
    if (code.isNotEmpty) {
      _controller.add(code);
    }
  }

  /// Release resources.
  void dispose() {
    _debounce?.cancel();
    _controller.close();
  }
}
