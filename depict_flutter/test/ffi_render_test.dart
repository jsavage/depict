import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:depict_flutter/ffi/depict.dart';

void main() {
  print('[test] CWD = ${Directory.current.path}');

  test('depict_render_svg returns SVG and writes file', () {
    final depict = Depict();

    const input = 'digraph { a -> b }';

    final svg = depict.renderSvg(input);

    expect(svg, contains('<svg'));
    expect(svg, contains('</svg>'));

    final outFile = File('test_output.svg');
    outFile.writeAsStringSync(svg);

    expect(outFile.existsSync(), isTrue);
    expect(outFile.readAsStringSync(), contains('<svg'));

    print('[test] SVG output length: ${svg.length}');
    print('[test] Saved ${outFile.absolute.path}');

    // Clean up so repeated runs stay deterministic
    outFile.deleteSync();
  });
}
