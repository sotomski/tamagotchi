import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:tamagotchi_client/tamagotchi_client.dart';

/// The transparent sentinel cell — mirrors the server's `kCritterTransparent`.
/// Never a palette key (Serverpod map values are non-null, so transparency is
/// encoded by *absence*); any cell that is this char, or any char missing from
/// the palette, renders transparent.
const String kCritterTransparent = '.';

/// Composites a [CritterSpec] into a `size`×`size` [ui.Image], one source pixel
/// per grid cell. The grid is the full square the model draws (Phase 0
/// adaptation — no un-mirroring): `base[r][c]` maps straight to pixel `(c, r)`.
///
/// A char absent from [CritterSpec.palette] (and the transparent `.`) leaves the
/// pixel fully transparent. The image is `size`×`size` — the [CritterPainter]
/// scales it up nearest-neighbor, so this stays a tiny buffer regardless of how
/// large it ultimately renders. Cells beyond the declared `size` (a model that
/// over-drew) are ignored; the spec is expected to already be validator-clean.
Future<ui.Image> compositeCritter(CritterSpec spec) {
  final size = spec.size;

  // Pre-parse each palette entry's `#RRGGBB` into its three byte channels once,
  // so the per-cell loop is a map lookup rather than a substring+parse.
  final channels = <String, List<int>>{};
  spec.palette.forEach((key, value) {
    channels[key] = [
      int.parse(value.substring(1, 3), radix: 16),
      int.parse(value.substring(3, 5), radix: 16),
      int.parse(value.substring(5, 7), radix: 16),
    ];
  });

  // RGBA8888, zero-initialised → every pixel starts fully transparent.
  final pixels = Uint8List(size * size * 4);
  for (var r = 0; r < spec.base.length && r < size; r++) {
    final row = spec.base[r];
    for (var c = 0; c < row.length && c < size; c++) {
      // transparent: '.' or any char absent from palette
      final rgb = channels[row[c]];
      if (rgb == null) {
        continue;
      }
      final i = (r * size + c) * 4;
      pixels[i] = rgb[0];
      pixels[i + 1] = rgb[1];
      pixels[i + 2] = rgb[2];
      pixels[i + 3] = 0xFF;
    }
  }

  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    size,
    size,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}
