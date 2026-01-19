import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

DynamicLibrary _loadDepictLibrary() {
  if (!Platform.isLinux) {
    throw UnsupportedError('depict_ffi is Linux-only for now');
  }

  final exeDir = File(Platform.resolvedExecutable).parent.path;

  final candidates = <String>[
    // Production bundle layout
    '$exeDir/lib/libdepict_ffi.so',

    // Running from bundle root
    '$exeDir/libdepict_ffi.so',

    // Flutter debug bundle
    'build/linux/x64/debug/bundle/lib/libdepict_ffi.so',

    // Flutter test / repo root fallback
    'libdepict_ffi.so',
  ];

  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) {
      print('[depict_ffi] Loading from: ${file.absolute.path}');
      return DynamicLibrary.open(file.absolute.path);
    }
  }

  throw StateError(
    'libdepict_ffi.so not found.\nChecked:\n  - ${candidates.join('\n  - ')}',
  );
}


/// C signature:
/// char *depict_render_svg(const char *input);
typedef _depict_render_svg_native = Pointer<Char> Function(
  Pointer<Char>,
);

typedef _depict_render_svg_dart = Pointer<Char> Function(
  Pointer<Char>,
);

/// C signature:
/// void depict_free_string(char *s);
typedef _depict_free_string_native = Void Function(
  Pointer<Char>,
);

typedef _depict_free_string_dart = void Function(
  Pointer<Char>,
);

class DepictFfiBindings {
  late final DynamicLibrary _lib;

  late final _depict_render_svg_dart depict_render_svg;
  late final _depict_free_string_dart depict_free_string;

  DepictFfiBindings() {
    _lib = _loadDepictLibrary();

    depict_render_svg = _lib
        .lookup<NativeFunction<_depict_render_svg_native>>(
            'depict_render_svg')
        .asFunction();

    depict_free_string = _lib
        .lookup<NativeFunction<_depict_free_string_native>>(
            'depict_free_string')
        .asFunction();
  }
}
