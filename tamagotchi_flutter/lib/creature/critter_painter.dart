import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

/// Draws a pre-composited critter [ui.Image] nearest-neighbor into the paint
/// box, for the crisp, chunky retro look. [FilterQuality.none] is the whole
/// point — it disables interpolation, so scaling a 32×32 source up to 128px
/// gives sharp 4×4 pixel blocks instead of a blurred smear.
///
/// The destination box is whatever size the host [CustomPaint] is given; callers
/// (see `CritterImage`) size it to an integer multiple of the source edge so the
/// blocks stay square.
class CritterPainter extends CustomPainter {
  CritterPainter(this.image);

  final ui.Image image;

  static final Paint _paint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, src, dst, _paint);
  }

  @override
  bool shouldRepaint(CritterPainter oldDelegate) =>
      !identical(oldDelegate.image, image);
}
