import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamagotchi_client/tamagotchi_client.dart';
import 'package:tamagotchi_flutter/creature/critter_compositor.dart';
import 'package:tamagotchi_flutter/creature/critter_image.dart';
import 'package:tamagotchi_flutter/creature/critter_painter.dart';

/// A tiny, fully-valid spec — a 4×4 grid with one filled cell at (col 1, row 2)
/// over an otherwise transparent field. Small enough to read pixels back and
/// assert exact placement without a 32×32 wall of dots.
CritterSpec _tinySpec() => CritterSpec(
  v: 1,
  size: 4,
  palette: {'R': '#FF0000'},
  base: const [
    '....',
    '....',
    '.R..',
    '....',
  ],
);

/// Reads [image] back as straight RGBA bytes for per-pixel assertions.
Future<List<int>> _rgbaOf(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.buffer.asUint8List();
}

void main() {
  group('compositeCritter', () {
    test('produces a size×size image', () async {
      final image = await compositeCritter(_tinySpec());
      expect(image.width, 4);
      expect(image.height, 4);
    });

    test('maps base[r][c] to pixel (c, r) with the palette colour', () async {
      final image = await compositeCritter(_tinySpec());
      final bytes = await _rgbaOf(image);
      // The filled cell is row 2, col 1 → pixel (x=1, y=2).
      final i = (2 * 4 + 1) * 4;
      expect(bytes.sublist(i, i + 4), [0xFF, 0x00, 0x00, 0xFF]);
    });

    test('leaves "." and palette-absent cells fully transparent', () async {
      final image = await compositeCritter(_tinySpec());
      final bytes = await _rgbaOf(image);
      // Pixel (0,0) is a '.' cell → alpha 0 (and zeroed channels).
      expect(bytes.sublist(0, 4), [0, 0, 0, 0]);
      // A char with no palette entry is also transparent.
      final spec = _tinySpec().copyWith(
        base: const [
          'Z...',
          '....',
          '....',
          '....',
        ],
      );
      final unknown = await _rgbaOf(await compositeCritter(spec));
      expect(unknown.sublist(0, 4), [0, 0, 0, 0]);
    });
  });

  group('CritterPainter', () {
    test('repaints only when the image identity changes', () async {
      final a = await compositeCritter(_tinySpec());
      final b = await compositeCritter(_tinySpec());
      expect(CritterPainter(a).shouldRepaint(CritterPainter(a)), isFalse);
      expect(CritterPainter(b).shouldRepaint(CritterPainter(a)), isTrue);
    });
  });

  group('CritterImage', () {
    testWidgets('reserves a box sized scale× the grid edge', (tester) async {
      // The box is `size * scale` even before the async decode lands, so the
      // layout never jumps. 4 cells × default scale 4 = 16px square.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CritterImage(spec: _tinySpec())),
        ),
      );
      await tester.pump();
      expect(tester.getSize(find.byType(CritterImage)), const Size(16, 16));
    });

    testWidgets('paints the composited image once the decode lands', (
      tester,
    ) async {
      // The image decode completes on an engine callback, so it only runs under
      // runAsync; poll a few frames until the painted CustomPaint appears.
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: CritterImage(spec: _tinySpec())),
          ),
        );
        final key = find.byKey(const Key('critterImage'));
        for (var i = 0; i < 20 && key.evaluate().isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          await tester.pump();
        }
      });

      final paint = tester.widget<CustomPaint>(
        find.byKey(const Key('critterImage')),
      );
      expect(paint.painter, isA<CritterPainter>());
      expect(paint.size, const Size(16, 16));
    });

    testWidgets('renders nothing for a null spec', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CritterImage(spec: null))),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('critterImage')), findsNothing);
      // The widget collapses to a zero-size box — no layout footprint.
      final box = tester.getSize(find.byType(CritterImage));
      expect(box, Size.zero);
    });
  });
}
