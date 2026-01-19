import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:depict_flutter/ffi/depict.dart';

void main() {
  print('[test] CWD = ${Directory.current.path}');
  test('depict_ffi library loads', () {
    // Ensure we are in the bundle directory context
    print('[test] CWD = ${Directory.current.path}');

    final depict = Depict();

    // We don’t even need to call render yet — constructor loads the lib
    print('[test] Depict instance created');

    // If DynamicLibrary.open fails, this test will throw
    expect(depict, isNotNull);
  });
}
