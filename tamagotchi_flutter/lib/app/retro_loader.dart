import 'package:flutter/material.dart';

/// A hard-edged retro activity indicator: a short row of pixel blocks with a
/// single lit block marching left-to-right on a loop. Replaces Material's round
/// [CircularProgressIndicator] across the app so "loading" reads as retro rather
/// than modern-Material.
///
/// Like a spinner, its animation never settles — pump the tree once (not
/// `pumpAndSettle`) in tests that assert it is visible.
class RetroLoader extends StatefulWidget {
  const RetroLoader({
    super.key,
    this.blockCount = 4,
    this.blockSize = 12,
    this.gap = 4,
    this.color,
    this.dimColor,
  }) : assert(blockCount > 0, 'blockCount must be positive');

  /// Number of blocks in the row.
  final int blockCount;

  /// Side length of each square block, in logical pixels.
  final double blockSize;

  /// Space between blocks.
  final double gap;

  /// The lit-block colour (defaults to the theme's primary phosphor accent).
  final Color? color;

  /// The unlit-block colour (defaults to the theme's outline).
  final Color? dimColor;

  @override
  State<RetroLoader> createState() => _RetroLoaderState();
}

class _RetroLoaderState extends State<RetroLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lit = widget.color ?? scheme.primary;
    final dim = widget.dimColor ?? scheme.outline;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final active =
            (_controller.value * widget.blockCount).floor() % widget.blockCount;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.blockCount; i++) ...[
              if (i > 0) SizedBox(width: widget.gap),
              Container(
                width: widget.blockSize,
                height: widget.blockSize,
                color: i == active ? lit : dim,
              ),
            ],
          ],
        );
      },
    );
  }
}
