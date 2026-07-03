import 'package:flutter/material.dart';

/// Renders a creature's generated pixel body from its public storage URL,
/// slotted into `CreatureView` below the mood label. The image lives in
/// Serverpod `public` DB storage and is served without auth, so a plain
/// [Image.network] loads it.
///
/// A null [imageUrl] — every pre-feature creature, whose `imageUrl` column is
/// null — renders [SizedBox.shrink], so legacy creatures show the rest of the
/// view with no layout break and no placeholder gap. While the bytes are in
/// flight the box is reserved at [size] so the layout never jumps, and a load
/// failure falls back to a neutral in-box glyph rather than Flutter's red error.
class CritterImage extends StatelessWidget {
  const CritterImage({required this.imageUrl, this.size = 256, super.key});

  /// The public URL of the critter image, or null for a creature with no
  /// generated image.
  final String? imageUrl;

  /// The rendered square's edge in logical pixels; the box is reserved at this
  /// size in every load state so the surrounding column doesn't reflow.
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null) return const SizedBox.shrink();

    return SizedBox.square(
      dimension: size,
      child: Image.network(
        url,
        key: const Key('critterImage'),
        width: size,
        height: size,
        fit: BoxFit.contain,
        // Nearest-neighbour so the 16-bit pixel-art stays crisp and blocky
        // instead of being smeared by bilinear. The 1024² source down to the
        // 256px default is a 4× downscale (half the old 128px 8× ratio), which
        // keeps the nearest-neighbour aliasing risk manageable — see the
        // downscale/aliasing note in the retro-revamp plan.
        filterQuality: FilterQuality.none,
        // Reserve the box until the bytes land, so the layout never jumps.
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
        // A failed load is neutral, not an error: a muted glyph in the same box.
        errorBuilder: (context, error, stackTrace) => Center(
          child: Icon(
            Icons.pets,
            size: size / 2,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
