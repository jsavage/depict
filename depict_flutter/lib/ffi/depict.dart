import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'depict_ffi_bindings.dart';

class Depict {
  final DepictFfiBindings _ffi = DepictFfiBindings();

  /// Calls Rust depict_render_svg.
  ///
  /// Returns:
  ///   - SVG string on success
  ///
  /// Throws:
  ///   - StateError if Rust returns NULL
  ///
  /// Memory ownership:
  ///   - Dart allocates and frees input
  ///   - Rust allocates output
  ///   - Dart frees output via depict_free_string
  String renderSvg(String input) {
    print('[depict] Calling depict_render_svg');
    print('[depict] Input: "$input"');

    final inputPtr = input.toNativeUtf8();

    try {
      final resultPtr =
          _ffi.depict_render_svg(inputPtr.cast<Char>());

      if (resultPtr == nullptr) {
        throw StateError('depict_render_svg returned NULL');
      }

      final svg = resultPtr.cast<Utf8>().toDartString();

      print('[depict] Rust returned SVG (${svg.length} bytes)');

      _ffi.depict_free_string(resultPtr);

      return svg;
    } finally {
      malloc.free(inputPtr);
    }
  }
}
