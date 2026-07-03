import 'package:flutter/material.dart';

/// A chunky retro segmented stat bar: the [label] on the left, a row of
/// hard-edged [segments] blocks lit proportionally to [value] / [max], and the
/// numeric [value] shown at the right.
///
/// The number stays a standalone `Text('$value')` so the existing stat-value
/// finders survive the visual rework: `CreatureView` wraps each bar in a
/// `Key('statRow-<label>')`, and ~15 widget asserts plus 2 Patrol e2e finders
/// scope to that key and read the number (see the plan's stat-number invariant).
/// A bar therefore *wraps* the number rather than replacing it.
class RetroStatBar extends StatelessWidget {
  const RetroStatBar({
    required this.label,
    required this.value,
    this.max = 100,
    this.segments = 10,
    super.key,
  });

  final String label;
  final int value;
  final int max;

  /// How many blocks the bar is divided into (the "resolution" of the meter).
  final int segments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Fill by proportion of the clamped value; the printed number stays raw.
    final clamped = value.clamp(0, max);
    final filled = max <= 0 ? 0 : (clamped / max * segments).round();

    // Capped width so the bar reads as a chunky meter on a wide pane instead of
    // stretching edge-to-edge; the Expanded segments still shrink to fit a
    // narrow pane, so it never overflows.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 84,
              child: Text(label, style: theme.textTheme.titleMedium),
            ),
            Expanded(
              child: Row(
                children: [
                  for (var i = 0; i < segments; i++)
                    Expanded(child: RetroStatSegment(filled: i < filled)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 40,
              child: Text(
                '$value',
                textAlign: TextAlign.right,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One hard-edged block in a [RetroStatBar]: [filled] lights it with the
/// phosphor accent, otherwise it reads as a dim empty cell. Public (not private)
/// so the widget test can count filled vs empty blocks by `filled`.
class RetroStatSegment extends StatelessWidget {
  const RetroStatSegment({required this.filled, super.key});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: filled ? scheme.primary : scheme.surface,
        border: Border.all(color: scheme.outline, width: 1),
      ),
    );
  }
}
