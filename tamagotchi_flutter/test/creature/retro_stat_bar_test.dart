import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamagotchi_flutter/creature/retro_stat_bar.dart';

void main() {
  // Pumps a single bar under a bare MaterialApp (default theme is enough — the
  // segments only read `colorScheme` for their colours).
  Future<void> pumpBar(
    WidgetTester tester, {
    required int value,
    int max = 100,
    int segments = 10,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: RetroStatBar(
            label: 'Energy',
            value: value,
            max: max,
            segments: segments,
          ),
        ),
      ),
    ),
  );

  Finder filledBlocks() =>
      find.byWidgetPredicate((w) => w is RetroStatSegment && w.filled);
  Finder emptyBlocks() =>
      find.byWidgetPredicate((w) => w is RetroStatSegment && !w.filled);

  testWidgets('fills blocks proportionally and shows the numeric value', (
    tester,
  ) async {
    await pumpBar(tester, value: 60);
    await tester.pumpAndSettle();

    // 60 / 100 of 10 blocks → 6 filled, 4 empty.
    expect(filledBlocks(), findsNWidgets(6));
    expect(emptyBlocks(), findsNWidgets(4));
    // The number stays a findable standalone Text (the stat-value invariant).
    expect(find.text('60'), findsOneWidget);
  });

  testWidgets('a full stat lights every block', (tester) async {
    await pumpBar(tester, value: 100);
    await tester.pumpAndSettle();

    expect(filledBlocks(), findsNWidgets(10));
    expect(emptyBlocks(), findsNothing);
    expect(find.text('100'), findsOneWidget);
  });

  testWidgets('a zero stat lights no block but still prints 0', (tester) async {
    await pumpBar(tester, value: 0);
    await tester.pumpAndSettle();

    expect(filledBlocks(), findsNothing);
    expect(emptyBlocks(), findsNWidgets(10));
    expect(find.text('0'), findsOneWidget);
  });
}
