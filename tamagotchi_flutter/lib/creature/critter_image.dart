import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:tamagotchi_client/tamagotchi_client.dart';

import 'critter_compositor.dart';
import 'critter_painter.dart';

/// Renders a creature's generated pixel body, slotted into `CreatureView` below
/// the mood label. Composites [spec] into a [ui.Image] once (re-running only
/// when the spec instance changes) and paints it nearest-neighbor at an integer
/// multiple of the grid edge so the pixels stay crisp.
///
/// A null [spec] — every pre-feature creature, whose `image` column is null —
/// renders [SizedBox.shrink], so legacy creatures show the rest of the view with
/// no layout break and no placeholder gap.
class CritterImage extends StatefulWidget {
  const CritterImage({required this.spec, this.scale = 4, super.key});

  /// The critter to draw, or null for a creature with no generated image.
  final CritterSpec? spec;

  /// Integer pixels-per-cell. The painted box is `spec.size * scale` square
  /// (32 × 4 = 128px), keeping every source cell a square `scale`×`scale` block.
  final int scale;

  @override
  State<CritterImage> createState() => _CritterImageState();
}

class _CritterImageState extends State<CritterImage> {
  /// The in-flight/completed composite for the current spec, or null when there
  /// is no spec to draw. Cached so a rebuild doesn't re-composite the buffer.
  Future<ui.Image>? _image;

  @override
  void initState() {
    super.initState();
    _composite();
  }

  @override
  void didUpdateWidget(CritterImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-composite only when the spec instance actually changes — a parent
    // rebuild with the same spec keeps the cached image.
    if (!identical(oldWidget.spec, widget.spec)) {
      _composite();
    }
  }

  void _composite() {
    final spec = widget.spec;
    _image = spec == null ? null : compositeCritter(spec);
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final image = _image;
    if (spec == null || image == null) return const SizedBox.shrink();

    final side = (spec.size * widget.scale).toDouble();
    return FutureBuilder<ui.Image>(
      future: image,
      builder: (context, snapshot) {
        // Reserve the final box even before the (synchronous-in-practice)
        // decode lands, so the layout never jumps.
        if (!snapshot.hasData) return SizedBox.square(dimension: side);
        return CustomPaint(
          key: const Key('critterImage'),
          size: Size.square(side),
          painter: CritterPainter(snapshot.data!),
        );
      },
    );
  }
}
