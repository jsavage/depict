import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'ffi/depict.dart';

void main() {
  runApp(const DepictApp());
}

class DepictApp extends StatelessWidget {
  const DepictApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DepictHome(),
    );
  }
}

class DepictHome extends StatefulWidget {
  const DepictHome({super.key});

  @override
  State<DepictHome> createState() => _DepictHomeState();
}

class _DepictHomeState extends State<DepictHome> {
  final _controller = TextEditingController(
    text: 'digraph { a -> b }',
  );

  final _depict = Depict();

  String? _svg;
  String? _status;

  void _render() {
    setState(() {
      _status = 'Rendering…';
      _svg = null;
    });

    try {
      final svg = _depict.renderSvg(_controller.text);

      if (svg == null) {
        setState(() {
          _status = 'Render failed (Rust returned null)';
        });
        return;
      }

      final outFile = File('output.svg');
      outFile.writeAsStringSync(svg);

      setState(() {
        _svg = svg;
        _status = 'SVG saved to: ${outFile.absolute.path}';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Depict'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Graph input:'),
            TextField(
              controller: _controller,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _render,
              child: const Text('Render'),
            ),
            const SizedBox(height: 8),
            if (_status != null)
              Text(
                _status!,
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: _svg == null
                  ? const Center(child: Text('No SVG rendered'))
                  : InteractiveViewer(
                      child: RepaintBoundary(
                        child: SvgPicture.string(
                          _svg!,
                          allowDrawingOutsideViewBox: true,
                          theme: const SvgTheme(
                            currentColor: Colors.black,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
