import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// StateProvider moved to the legacy surface in Riverpod 3.x; the test uses it as
// a tiny flip-able seam for the hatch-flow override.
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamagotchi_client/tamagotchi_client.dart';
import 'package:tamagotchi_flutter/creature/creature_provider.dart';
import 'package:tamagotchi_flutter/creature/hatch_controller.dart';
import 'package:tamagotchi_flutter/home/home_screen.dart';

/// A canned creature status for the "present" states. Stats default to a
/// happy-looking spread so the assertions key on distinct numbers.
CreatureStatus _status({
  String name = 'Nibbles',
  CreatureMood mood = CreatureMood.happy,
  int hunger = 5,
  int energy = 95,
  int love = 90,
  int illness = 0,
}) => CreatureStatus(
  creature: Creature(
    ownerUuid: UuidValue.fromString('00000000-0000-0000-0000-000000000001'),
    name: name,
    hunger: hunger,
    energy: energy,
    love: love,
    illness: illness,
  ),
  mood: mood,
);

/// Test seam the flow tests flip to simulate a hatch landing a creature: the
/// overridden [creatureProvider] watches it, so setting it swaps the home from
/// the form to the stats view — the same effect the real controller produces by
/// invalidating [creatureProvider] after a successful hatch.
final _hatchedStatus = StateProvider<CreatureStatus?>((ref) => null);

/// A [HatchController] that records calls and, instead of hitting the server,
/// publishes a creature into [_hatchedStatus]. Lets the flow test exercise the
/// real form (validation, button) without an RPC.
class _FakeHatchController extends HatchController {
  int calls = 0;

  @override
  Future<void> hatch(String name) async {
    calls++;
    ref.read(_hatchedStatus.notifier).state = _status(name: name);
  }
}

void main() {
  testWidgets('while the creature is loading the home shows a spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // A future that never completes keeps the provider in the loading
          // state.
          creatureProvider.overrideWith(
            (ref) => Completer<CreatureStatus?>().future,
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('when the creature fetch fails the home shows an error + retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creatureProvider.overrideWith(
            (ref) => Future<CreatureStatus?>.error(Exception('network down')),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
  });

  testWidgets(
    'with a creature the home shows its name, four stats, and mood label',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [creatureProvider.overrideWith((ref) => _status())],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nibbles'), findsOneWidget);
      expect(find.text('Mood: happy'), findsOneWidget);
      // The four raw stat numbers (hunger 5, energy 95, love 90, illness 0).
      expect(find.text('5'), findsOneWidget);
      expect(find.text('95'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    },
  );

  testWidgets(
    'hatching from the empty state swaps the form for the stats view',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            creatureProvider.overrideWith((ref) => ref.watch(_hatchedStatus)),
            hatchControllerProvider.overrideWith(_FakeHatchController.new),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Empty state first: no creature yet.
      expect(find.widgetWithText(ElevatedButton, 'Hatch'), findsOneWidget);
      expect(find.text('Korek'), findsNothing);

      await tester.enterText(find.byType(TextField), 'Korek');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Hatch'));
      await tester.pumpAndSettle();

      // The stats view replaced the form.
      expect(find.text('Korek'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Hatch'), findsNothing);
    },
  );

  testWidgets('a blank name is blocked client-side and never calls hatch', (
    tester,
  ) async {
    final fake = _FakeHatchController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creatureProvider.overrideWith((ref) => ref.watch(_hatchedStatus)),
          hatchControllerProvider.overrideWith(() => fake),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Hatch with an empty field.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Hatch'));
    await tester.pumpAndSettle();

    // Still on the form, with an inline validation message; no hatch attempted.
    expect(find.widgetWithText(ElevatedButton, 'Hatch'), findsOneWidget);
    expect(find.text('Please enter a name'), findsOneWidget);
    expect(fake.calls, 0);
  });
}
