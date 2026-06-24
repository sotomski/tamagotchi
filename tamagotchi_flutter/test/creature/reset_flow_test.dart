import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// StateProvider moved to the legacy surface in Riverpod 3.x; used here as a
// flip-able seam for the reset-flow swap test.
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamagotchi_client/tamagotchi_client.dart';
import 'package:tamagotchi_flutter/creature/creature_provider.dart';
import 'package:tamagotchi_flutter/creature/reset_controller.dart';
import 'package:tamagotchi_flutter/home/home_screen.dart';

/// A canned present-creature status — enough for the home to render the stats
/// view (and therefore the AppBar Reset action).
CreatureStatus _status({String name = 'Nibbles'}) => CreatureStatus(
  creature: Creature(
    ownerUuid: UuidValue.fromString('00000000-0000-0000-0000-000000000001'),
    name: name,
    hunger: 5,
    energy: 95,
    love: 90,
    illness: 0,
  ),
  mood: CreatureMood.happy,
);

/// A [ResetController] that records calls instead of hitting the server, so the
/// tests can assert whether the confirm dialog gated the reset (lesson #2 —
/// override the action notifier, never round-trip a real RPC).
class _FakeResetController extends ResetController {
  int calls = 0;

  @override
  Future<void> reset() async {
    calls++;
  }
}

/// Flip-able seam for the reset-flow swap test: the overridden
/// [creatureProvider] watches it, so nulling it re-renders the home from the
/// stats view back to the empty [HatchForm] — the same effect the real
/// controller produces by invalidating [creatureProvider] after a reset.
final _creatureSeam = StateProvider<CreatureStatus?>((ref) => _status());

/// A [ResetController] that, instead of an RPC, nulls [_creatureSeam] — the
/// widget-level stand-in for the real `invalidate(creatureProvider)` returning
/// "no creature" after the delete.
class _SwappingResetController extends ResetController {
  @override
  Future<void> reset() async {
    ref.read(_creatureSeam.notifier).state = null;
  }
}

void main() {
  testWidgets('the Reset action is hidden when no creature exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [creatureProvider.overrideWith((ref) => null)],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Empty (HatchForm) state — nothing to reset, so no Reset affordance.
    expect(find.byKey(const Key('resetButton')), findsNothing);
    expect(find.widgetWithText(TextButton, 'Reset'), findsNothing);
  });

  testWidgets('the Reset action shows when a creature exists', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [creatureProvider.overrideWith((ref) => _status())],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('resetButton')), findsOneWidget);
  });

  testWidgets('tapping Reset opens the confirmation dialog', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [creatureProvider.overrideWith((ref) => _status())],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('resetButton')));
    await tester.pumpAndSettle();

    // The destructive confirm dialog is up, warning the loss is permanent.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('permanently'), findsOneWidget);
    expect(find.byKey(const Key('resetConfirmButton')), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
  });

  testWidgets('Cancel dismisses the dialog without calling reset', (
    tester,
  ) async {
    final fake = _FakeResetController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creatureProvider.overrideWith((ref) => _status()),
          resetControllerProvider.overrideWith(() => fake),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('resetButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Dialog gone, creature untouched: reset was never called.
    expect(find.byType(AlertDialog), findsNothing);
    expect(fake.calls, 0);
  });

  testWidgets('confirming calls reset exactly once', (tester) async {
    final fake = _FakeResetController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creatureProvider.overrideWith((ref) => _status()),
          resetControllerProvider.overrideWith(() => fake),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('resetButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('resetConfirmButton')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(fake.calls, 1);
  });

  testWidgets('confirming swaps the home back to the HatchForm empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creatureProvider.overrideWith((ref) => ref.watch(_creatureSeam)),
          resetControllerProvider.overrideWith(_SwappingResetController.new),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Stats view first: the creature is present, Reset is offered.
    expect(find.text('Nibbles'), findsOneWidget);
    expect(find.byKey(const Key('resetButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('resetButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('resetConfirmButton')));
    await tester.pumpAndSettle();

    // The empty state took over: HatchForm's prompt + button, no creature, and
    // the Reset action is gone (nothing left to delete).
    expect(find.textContaining('No creature yet'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Hatch'), findsOneWidget);
    expect(find.text('Nibbles'), findsNothing);
    expect(find.byKey(const Key('resetButton')), findsNothing);
  });
}
