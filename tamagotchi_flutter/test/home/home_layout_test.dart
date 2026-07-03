import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamagotchi_client/tamagotchi_client.dart';
import 'package:tamagotchi_flutter/creature/creature_view.dart';
import 'package:tamagotchi_flutter/creature/journal_provider.dart';
import 'package:tamagotchi_flutter/creature/journal_view.dart';
import 'package:tamagotchi_flutter/home/home_screen.dart';

/// A canned present-creature status. The journal is stubbed empty, so the stat
/// values here don't matter — the layout, not the stats, is under test.
CreatureStatus _status() => CreatureStatus(
  creature: Creature(
    ownerUuid: UuidValue.fromString('00000000-0000-0000-0000-000000000001'),
    name: 'Nibbles',
    hunger: 50,
    energy: 50,
    love: 50,
    illness: 0,
  ),
  mood: CreatureMood.happy,
  canFeed: true,
  canPlay: true,
);

/// Pumps [HomeBody] at a fixed logical [size], with [journalProvider] stubbed to
/// an empty list — the embedded [JournalView] would otherwise round-trip to a
/// server that isn't running under `flutter test` (same seam as
/// `journal_view_test.dart`). Resets the view after the test.
Future<void> _pumpBody(WidgetTester tester, {required Size size}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [journalProvider.overrideWith((ref) => <JournalEntry>[])],
      child: MaterialApp(
        home: Scaffold(body: HomeBody(status: _status())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a narrow window splits into Creature/Journal tabs', (
    tester,
  ) async {
    await _pumpBody(tester, size: const Size(400, 800));

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Creature'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Journal'), findsOneWidget);
    // The desktop divider is absent in the tabbed layout.
    expect(find.byType(VerticalDivider), findsNothing);
  });

  testWidgets('a wide window keeps the side-by-side two-pane split', (
    tester,
  ) async {
    await _pumpBody(tester, size: const Size(1000, 800));

    expect(find.byType(VerticalDivider), findsOneWidget);
    // Both panes are present at once (no tabs).
    expect(find.byType(CreatureView), findsOneWidget);
    expect(find.byType(JournalView), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
  });
}
