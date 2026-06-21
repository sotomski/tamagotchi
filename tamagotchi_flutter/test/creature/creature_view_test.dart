import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// StateProvider moved to the legacy surface in Riverpod 3.x; the test uses it as
// a tiny flip-able seam for the hatch-flow override.
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamagotchi_client/tamagotchi_client.dart';
import 'package:tamagotchi_flutter/creature/creature_provider.dart';
import 'package:tamagotchi_flutter/creature/cure_controller.dart';
import 'package:tamagotchi_flutter/creature/feed_controller.dart';
import 'package:tamagotchi_flutter/creature/hatch_controller.dart';
import 'package:tamagotchi_flutter/creature/last_interaction.dart';
import 'package:tamagotchi_flutter/creature/play_controller.dart';
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

/// Flip-able seam for the Feed-flow tests: the overridden [creatureProvider]
/// watches it, so flipping it to a post-feed status re-renders the stat rows —
/// the same effect the real controller produces by invalidating
/// [creatureProvider] after a feed.
final _creatureSeam = StateProvider<CreatureStatus?>((ref) => null);

/// What [_FakeFeedController.feed] publishes: the canned outcome it sets as its
/// own state, and (optionally) a post-feed status to flip [_creatureSeam] to.
final _feedResultSeam = StateProvider<FeedResult?>((ref) => null);
final _postFeedSeam = StateProvider<CreatureStatus?>((ref) => null);

FeedResult _feedResult({
  required bool accepted,
  required String userResponse,
  CreatureStatus? status,
}) => FeedResult(
  userResponse: userResponse,
  accepted: accepted,
  status: status ?? _status(),
);

/// A [FeedController] that records calls and, instead of an RPC, publishes a
/// canned [FeedResult] from [_feedResultSeam], writes the shared
/// [lastInteractionProvider] (mirroring the real controller), and (if set) flips
/// [_creatureSeam] to the post-feed status — exercising the real
/// button/loading/response UI without a server (lesson #2).
class _FakeFeedController extends FeedController {
  int calls = 0;

  @override
  Future<void> feed() async {
    calls++;
    final post = ref.read(_postFeedSeam);
    if (post != null) ref.read(_creatureSeam.notifier).state = post;
    final result = ref.read(_feedResultSeam);
    if (result != null) {
      ref
          .read(lastInteractionProvider.notifier)
          .set(userResponse: result.userResponse, accepted: result.accepted);
    }
    state = AsyncData(result);
  }
}

/// A [FeedController] stuck in flight: `feed()` enters loading and never
/// resolves, so the loading animation stays up under a single `pump()`.
class _LoadingFeedController extends FeedController {
  @override
  Future<void> feed() async {
    state = const AsyncLoading();
    await Completer<void>().future;
  }
}

/// What [_FakePlayController.play] publishes: the canned outcome it sets as its own
/// state, and (optionally) a post-play status to flip [_creatureSeam] to.
final _playResultSeam = StateProvider<PlayResult?>((ref) => null);
final _postPlaySeam = StateProvider<CreatureStatus?>((ref) => null);

PlayResult _playResult({
  required String userResponse,
  CreatureStatus? status,
}) => PlayResult(userResponse: userResponse, status: status ?? _status());

/// A [PlayController] that records calls and, instead of an RPC, publishes a
/// canned [PlayResult] from [_playResultSeam], writes the shared
/// [lastInteractionProvider] (`accepted: true` — Play never refuses), and (if
/// set) flips [_creatureSeam] to the post-play status — the Play analogue of
/// [_FakeFeedController] (lesson #2).
class _FakePlayController extends PlayController {
  int calls = 0;

  @override
  Future<void> play() async {
    calls++;
    final post = ref.read(_postPlaySeam);
    if (post != null) ref.read(_creatureSeam.notifier).state = post;
    final result = ref.read(_playResultSeam);
    if (result != null) {
      ref
          .read(lastInteractionProvider.notifier)
          .set(userResponse: result.userResponse, accepted: true);
    }
    state = AsyncData(result);
  }
}

/// A [PlayController] stuck in flight: `play()` enters loading and never resolves,
/// so the playing animation stays up under a single `pump()`.
class _LoadingPlayController extends PlayController {
  @override
  Future<void> play() async {
    state = const AsyncLoading();
    await Completer<void>().future;
  }
}

/// What [_FakeCureController.cure] publishes: the canned outcome it sets as its
/// own state, and (optionally) a post-cure status to flip [_creatureSeam] to.
final _cureResultSeam = StateProvider<CureResult?>((ref) => null);
final _postCureSeam = StateProvider<CreatureStatus?>((ref) => null);

CureResult _cureResult({
  required String userResponse,
  CreatureStatus? status,
}) => CureResult(userResponse: userResponse, status: status ?? _status());

/// A [CureController] that records calls and, instead of an RPC, publishes a
/// canned [CureResult] from [_cureResultSeam], writes the shared
/// [lastInteractionProvider] (`accepted: true` — Cure never refuses), and (if
/// set) flips [_creatureSeam] to the post-cure status — the Cure analogue of
/// [_FakePlayController] (lesson #2).
class _FakeCureController extends CureController {
  int calls = 0;

  @override
  Future<void> cure() async {
    calls++;
    final post = ref.read(_postCureSeam);
    if (post != null) ref.read(_creatureSeam.notifier).state = post;
    final result = ref.read(_cureResultSeam);
    if (result != null) {
      ref
          .read(lastInteractionProvider.notifier)
          .set(userResponse: result.userResponse, accepted: true);
    }
    state = AsyncData(result);
  }
}

/// A [CureController] stuck in flight: `cure()` enters loading and never
/// resolves, so the curing animation stays up under a single `pump()`.
class _LoadingCureController extends CureController {
  @override
  Future<void> cure() async {
    state = const AsyncLoading();
    await Completer<void>().future;
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
    expect(find.text('Please enter a name.'), findsOneWidget);
    expect(fake.calls, 0);
  });

  testWidgets(
    'a present creature shows Feed, Play and Cure buttons (no response yet)',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [creatureProvider.overrideWith((ref) => _status())],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Feed'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Play with'), findsOneWidget);
      expect(find.byKey(const Key('cureButton')), findsOneWidget);
      // No interaction attempted yet → no loading, no response bubble.
      expect(find.text('Feeding…'), findsNothing);
      expect(find.text('Playing…'), findsNothing);
      expect(find.text('Curing…'), findsNothing);
      expect(find.byKey(const Key('interactionResponse')), findsNothing);
    },
  );

  testWidgets('tapping Feed calls the controller and renders the accepted '
      'response', (tester) async {
    final fake = _FakeFeedController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creatureProvider.overrideWith((ref) => _status()),
          feedControllerProvider.overrideWith(() => fake),
          _feedResultSeam.overrideWith(
            (ref) => _feedResult(
              accepted: true,
              userResponse: 'Nom nom — the gilded truffle was divine!',
            ),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Nothing rendered before the tap.
    expect(find.textContaining('gilded truffle'), findsNothing);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Feed'));
    await tester.pumpAndSettle();

    expect(fake.calls, 1);
    expect(find.textContaining('gilded truffle'), findsOneWidget);
    // The button stays for another feed.
    expect(find.widgetWithText(ElevatedButton, 'Feed'), findsOneWidget);
  });

  testWidgets('a refusal renders its distinct (italic) copy, not as an error', (
    tester,
  ) async {
    final fake = _FakeFeedController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creatureProvider.overrideWith((ref) => _status()),
          feedControllerProvider.overrideWith(() => fake),
          _feedResultSeam.overrideWith(
            (ref) => _feedResult(
              accepted: false,
              userResponse: 'Ugh, not the soggy gruel again — hard pass.',
            ),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Feed'));
    await tester.pumpAndSettle();

    final refusal = find.textContaining('soggy gruel');
    expect(refusal, findsOneWidget);
    // A refusal is data, not an AsyncError — styled italic, no error message.
    expect(tester.widget<Text>(refusal).style?.fontStyle, FontStyle.italic);
    expect(find.textContaining('Something went wrong'), findsNothing);
  });

  testWidgets('a feed in flight shows the loading animation in place of the '
      'button', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creatureProvider.overrideWith((ref) => _status()),
          feedControllerProvider.overrideWith(_LoadingFeedController.new),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Feed'));
    // Single pump — the feed never completes; loading must already be visible.
    await tester.pump();

    expect(find.text('Feeding…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Feed'), findsNothing);
  });

  testWidgets('stats refresh after a successful feed', (tester) async {
    final fake = _FakeFeedController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creatureProvider.overrideWith((ref) => ref.watch(_creatureSeam)),
          _creatureSeam.overrideWith((ref) => _status(hunger: 80)),
          feedControllerProvider.overrideWith(() => fake),
          _feedResultSeam.overrideWith(
            (ref) => _feedResult(accepted: true, userResponse: 'Yum!'),
          ),
          // The fake flips _creatureSeam to this post-feed status, mirroring the
          // real invalidate(creatureProvider).
          _postFeedSeam.overrideWith((ref) => _status(hunger: 50)),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Pre-feed hunger.
    expect(find.text('80'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Feed'));
    await tester.pumpAndSettle();

    // Post-feed hunger replaced it.
    expect(find.text('50'), findsOneWidget);
    expect(find.text('80'), findsNothing);
  });

  testWidgets('tapping Play calls the controller and renders the response in '
      'the shared area', (tester) async {
    final fake = _FakePlayController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creatureProvider.overrideWith((ref) => _status()),
          playControllerProvider.overrideWith(() => fake),
          _playResultSeam.overrideWith(
            (ref) => _playResult(
              userResponse: 'Wheee! Chase me again, that was the best game!',
            ),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Nothing rendered before the tap.
    expect(find.textContaining('best game'), findsNothing);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Play with'));
    await tester.pumpAndSettle();

    expect(fake.calls, 1);
    // Play is always accepted → normal styling, rendered in the shared area.
    final response = find.textContaining('best game');
    expect(response, findsOneWidget);
    expect(
      tester.widget<Text>(response).style?.fontStyle,
      isNot(FontStyle.italic),
    );
    expect(find.byKey(const Key('interactionResponse')), findsOneWidget);
    // Both buttons stay for another interaction.
    expect(find.widgetWithText(ElevatedButton, 'Play with'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Feed'), findsOneWidget);
  });

  testWidgets('a play in flight shows the playing animation in place of the '
      'buttons', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creatureProvider.overrideWith((ref) => _status()),
          playControllerProvider.overrideWith(_LoadingPlayController.new),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Play with'));
    // Single pump — the play never completes; loading must already be visible.
    await tester.pump();

    expect(find.text('Playing…'), findsOneWidget);
    expect(find.byKey(const Key('playingIndicator')), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Play with'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Feed'), findsNothing);
  });

  testWidgets('the most-recent interaction wins the shared response area', (
    tester,
  ) async {
    final feedFake = _FakeFeedController();
    final playFake = _FakePlayController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creatureProvider.overrideWith((ref) => _status()),
          feedControllerProvider.overrideWith(() => feedFake),
          playControllerProvider.overrideWith(() => playFake),
          _feedResultSeam.overrideWith(
            (ref) => _feedResult(accepted: true, userResponse: 'Nom nom!'),
          ),
          _playResultSeam.overrideWith(
            (ref) => _playResult(userResponse: 'Wheee, again!'),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Play first → its response shows.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Play with'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Wheee'), findsOneWidget);
    expect(find.textContaining('Nom nom'), findsNothing);

    // Then Feed → the feed response replaces it (most-recent wins).
    await tester.tap(find.widgetWithText(ElevatedButton, 'Feed'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nom nom'), findsOneWidget);
    expect(find.textContaining('Wheee'), findsNothing);
  });

  testWidgets('stats refresh after a successful play', (tester) async {
    final fake = _FakePlayController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creatureProvider.overrideWith((ref) => ref.watch(_creatureSeam)),
          _creatureSeam.overrideWith((ref) => _status(love: 40, energy: 90)),
          playControllerProvider.overrideWith(() => fake),
          _playResultSeam.overrideWith(
            (ref) => _playResult(userResponse: 'Wheee, again!'),
          ),
          // The fake flips _creatureSeam to this post-play status, mirroring the
          // real invalidate(creatureProvider): love up, energy down.
          _postPlaySeam.overrideWith((ref) => _status(love: 55, energy: 86)),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Pre-play love/energy.
    expect(find.text('40'), findsOneWidget);
    expect(find.text('90'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Play with'));
    await tester.pumpAndSettle();

    // Post-play love/energy replaced them.
    expect(find.text('55'), findsOneWidget);
    expect(find.text('86'), findsOneWidget);
    expect(find.text('40'), findsNothing);
  });

  testWidgets('Cure is disabled on a healthy creature (illness == 0) and never '
      'calls the controller', (tester) async {
    final fake = _FakeCureController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Default _status() is illness 0 — nothing to heal.
          creatureProvider.overrideWith((ref) => _status(illness: 0)),
          cureControllerProvider.overrideWith(() => fake),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final cure = find.widgetWithText(ElevatedButton, 'Cure');
    expect(cure, findsOneWidget);
    // Disabled → onPressed is null.
    expect(tester.widget<ElevatedButton>(cure).onPressed, isNull);

    await tester.tap(cure, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(fake.calls, 0);
  });

  testWidgets(
    'tapping Cure on a sick creature calls the controller and renders '
    'the response in the shared area',
    (tester) async {
      final fake = _FakeCureController();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            creatureProvider.overrideWith((ref) => _status(illness: 60)),
            cureControllerProvider.overrideWith(() => fake),
            _cureResultSeam.overrideWith(
              (ref) => _cureResult(
                userResponse: 'Aaah, the fever lifts — I feel so much better!',
              ),
            ),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final cure = find.widgetWithText(ElevatedButton, 'Cure');
      // Enabled when illness > 0.
      expect(tester.widget<ElevatedButton>(cure).onPressed, isNotNull);
      // Nothing rendered before the tap.
      expect(find.textContaining('fever lifts'), findsNothing);

      await tester.tap(cure);
      await tester.pumpAndSettle();

      expect(fake.calls, 1);
      // Cure is always accepted → normal styling, rendered in the shared area.
      final response = find.textContaining('fever lifts');
      expect(response, findsOneWidget);
      expect(
        tester.widget<Text>(response).style?.fontStyle,
        isNot(FontStyle.italic),
      );
      expect(find.byKey(const Key('interactionResponse')), findsOneWidget);
      // All three buttons stay for another interaction.
      expect(find.widgetWithText(ElevatedButton, 'Cure'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Feed'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Play with'), findsOneWidget);
    },
  );

  testWidgets('a cure in flight shows the curing animation in place of the '
      'buttons', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creatureProvider.overrideWith((ref) => _status(illness: 60)),
          cureControllerProvider.overrideWith(_LoadingCureController.new),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Cure'));
    // Single pump — the cure never completes; loading must already be visible.
    await tester.pump();

    expect(find.text('Curing…'), findsOneWidget);
    expect(find.byKey(const Key('curingIndicator')), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Cure'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Feed'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Play with'), findsNothing);
  });

  testWidgets('stats refresh after a successful cure (illness drops)', (
    tester,
  ) async {
    final fake = _FakeCureController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creatureProvider.overrideWith((ref) => ref.watch(_creatureSeam)),
          _creatureSeam.overrideWith((ref) => _status(illness: 70)),
          cureControllerProvider.overrideWith(() => fake),
          _cureResultSeam.overrideWith(
            (ref) => _cureResult(userResponse: 'Much better!'),
          ),
          // The fake flips _creatureSeam to this post-cure status, mirroring the
          // real invalidate(creatureProvider): illness down.
          _postCureSeam.overrideWith((ref) => _status(illness: 30)),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Pre-cure illness.
    expect(find.text('70'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Cure'));
    await tester.pumpAndSettle();

    // Post-cure illness replaced it.
    expect(find.text('30'), findsOneWidget);
    expect(find.text('70'), findsNothing);
  });
}
