import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamagotchi_flutter/app/retro_theme.dart';

/// Locks the load-bearing invariants of [buildRetroTheme]. Widget tests wrap
/// their units in a bare default-theme `MaterialApp`, so they never exercise the
/// retro theme — the factory is asserted directly here instead.
void main() {
  group('buildRetroTheme', () {
    final theme = buildRetroTheme();

    test('retroScreenColor is the agreed shared hex (#0E1712)', () {
      // Phase 5's server prompt must mirror this exact value.
      expect(retroScreenColor, const Color(0xFF0E1712));
    });

    test('uses the VT323 pixel font across the text theme', () {
      expect(theme.textTheme.bodyMedium?.fontFamily, 'VT323');
      expect(theme.textTheme.titleLarge?.fontFamily, 'VT323');
    });

    test('is a dark colour scheme', () {
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.brightness, Brightness.dark);
    });

    test('scaffold sits on the shared screen colour', () {
      expect(theme.scaffoldBackgroundColor, retroScreenColor);
      expect(theme.canvasColor, retroScreenColor);
    });

    test('cards are flat and hard-edged (zero elevation, square corners)', () {
      expect(theme.cardTheme.elevation, 0);
      final shape = theme.cardTheme.shape;
      expect(shape, isA<RoundedRectangleBorder>());
      expect(
        (shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.zero,
      );
    });

    test('dialogs are flat and hard-edged', () {
      expect(theme.dialogTheme.elevation, 0);
      final shape = theme.dialogTheme.shape;
      expect(shape, isA<RoundedRectangleBorder>());
      expect(
        (shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.zero,
      );
    });

    test(
      'elevated buttons are flat, square, and larger than Material default',
      () {
        final style = theme.elevatedButtonTheme.style;
        expect(style, isNotNull);

        expect(style!.elevation?.resolve(<WidgetState>{}), 0);

        final minSize = style.minimumSize?.resolve(<WidgetState>{});
        expect(minSize, isNotNull);
        // Taller than Material's default (48 for M3 filled / 36 for legacy).
        expect(minSize!.height, greaterThan(48));

        final shape = style.shape?.resolve(<WidgetState>{});
        expect(shape, isA<RoundedRectangleBorder>());
        expect(
          (shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.zero,
        );
      },
    );
  });
}
