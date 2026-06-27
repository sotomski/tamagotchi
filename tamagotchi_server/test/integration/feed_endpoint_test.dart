import 'package:serverpod/serverpod.dart';
import 'package:tamagotchi_server/src/creature/feed_service.dart';
import 'package:tamagotchi_server/src/generated/protocol.dart';
import 'package:tamagotchi_server/src/llm/feed_copy.dart';
import 'package:tamagotchi_server/src/llm/llm_service.dart';
import 'package:tamagotchi_server/src/llm/stub_llm_service.dart';
import 'package:test/test.dart';

import '../helpers/scripted_random.dart';
import 'test_tools/serverpod_test_tools.dart';

/// An [LlmService] that always throws, to drive the degrade path: the endpoint
/// must catch this, substitute canned copy, and still commit the stat+journal
/// pair.
class _ThrowingLlmService implements LlmService {
  const _ThrowingLlmService();

  @override
  Future<({String userResponse, String journalNarrative})> generateInteraction(
    Session session,
    InteractionRequest request,
  ) async => throw Exception('model unreachable');
}

/// Reassigns the production [feedServiceFactory] seam to inject a [FeedService]
/// with a scripted rng and (by default) the hermetic [StubLlmService]. The whole
/// point of the seam: the endpoint stays production code; the test does the work
/// of faking.
void _injectFeedService(
  List<double> doubles, {
  LlmService llm = const StubLlmService(),
}) {
  feedServiceFactory = (_) =>
      FeedService(rng: ScriptedRandom(doubles), llm: llm);
  // Self-cleaning: restore the production wiring when this test ends — even on
  // failure. Co-locating the reset with the mutation makes it impossible to add
  // an injection path that forgets to clean up, so a fake can never leak into the
  // next sequential test. (Cross-file parallelism is already isolate-isolated.)
  addTearDown(() => feedServiceFactory = feedServiceFor);
}

TestSessionBuilder _authedAs(TestSessionBuilder builder, String userUuid) =>
    builder.copyWith(
      authentication: AuthenticationOverride.authenticationInfo(
        userUuid,
        <Scope>{},
      ),
    );

/// Seeds a creature + its 1:1 personality directly (bypassing hatch so the test
/// controls `hunger` and `hungerDecayMod`, the only inputs the gate reads). A
/// freshly hatched creature has `hunger == 0` (full), so direct seeding is the
/// only way to reach the accept/picky paths.
Future<Creature> _seedCreature(
  Session session,
  String userUuid, {
  required int hunger,
  int energy = 100,
  double hungerDecayMod = 1.0,
}) async {
  final creature = await Creature.db.insertRow(
    session,
    Creature(
      ownerUuid: UuidValue.fromString(userUuid),
      name: 'Testy',
      hunger: hunger,
      energy: energy,
      love: 50,
      illness: 0,
    ),
  );
  await CreaturePersonality.db.insertRow(
    session,
    CreaturePersonality(
      creatureId: creature.id!,
      hungerDecayMod: hungerDecayMod,
      hungerRegenMod: 1.0,
      energyDecayMod: 1.0,
      energyRegenMod: 1.0,
      loveRegenMod: 1.0,
      illnessDecayMod: 1.0,
      illnessRegenMod: 1.0,
    ),
  );
  return creature;
}

Future<List<JournalEntry>> _feedEntries(
  Session session,
  UuidValue creatureId,
) => JournalEntry.db.find(
  session,
  where: (t) =>
      t.creatureId.equals(creatureId) & t.event.equals(JournalEvent.feed),
);

void main() {
  withServerpod('Given CreatureEndpoint.feed', (sessionBuilder, endpoints) {
    test(
      'an accepted feed drops hunger -30 / energy -10 (clamped), writes exactly '
      'one feed journal entry with the matching delta + prose, and re-derives '
      'mood',
      () async {
        // picky = pickyFactor(1.0) = 0.5; tastiness 0.5 → reject p = 0.05; the
        // reject roll 0.99 ≥ 0.05 ⇒ accepted. Draw order: tastiness, then roll.
        _injectFeedService(const [0.5, 0.99]);
        final userUuid = const Uuid().v4();
        final authed = _authedAs(sessionBuilder, userUuid);
        final session = authed.build();
        final creature = await _seedCreature(session, userUuid, hunger: 80);

        final result = await endpoints.creature.feed(authed);

        // Returned outcome: accepted, stub accept copy, post-feed stats + mood.
        expect(result.accepted, isTrue);
        expect(result.exhausted, isFalse); // affordable: gate did not fire
        expect(result.status.canFeed, isTrue); // energy 100 >= 10
        expect(result.userResponse, stubAcceptUserResponse);
        expect(result.status.creature.hunger, 50);
        expect(result.status.creature.energy, 90);
        expect(result.status.creature.love, 50);
        expect(result.status.creature.illness, 0);
        // deriveMood(50, 90, 50, 0): worst distress 50 ⇒ content.
        expect(result.status.mood, CreatureMood.content);

        // Persisted stat change.
        final stored = await Creature.db.findById(session, creature.id!);
        expect(stored!.hunger, 50);
        expect(stored.energy, 90);

        // Exactly one feed entry with the matching delta and non-empty prose.
        final entries = await _feedEntries(session, creature.id!);
        expect(entries, hasLength(1));
        final entry = entries.single;
        expect(entry.prose, stubAcceptJournalNarrative);
        expect(entry.statDelta!.hungerDelta, -30);
        expect(entry.statDelta!.energyDelta, -10);
        expect(entry.statDelta!.loveDelta, 0);
        expect(entry.statDelta!.illnessDelta, 0);
      },
    );

    test(
      'a full creature (hunger==0) flows through the LLM and writes exactly one '
      'zero-delta feed entry narrated as fullness, leaving stats unchanged',
      () async {
        // Full path draws no nextDouble (the gate short-circuits on hunger==0
        // before any roll, and no canned-line pick remains) — an empty script
        // throws if drawn, asserting that.
        _injectFeedService(const []);
        final userUuid = const Uuid().v4();
        final authed = _authedAs(sessionBuilder, userUuid);
        final session = authed.build();
        final creature = await _seedCreature(session, userUuid, hunger: 0);

        final result = await endpoints.creature.feed(authed);

        // The refusal is in-character via the model (stub here), not a canned
        // line, and reads as fullness — distinct from the picky refuse copy.
        expect(result.accepted, isFalse);
        expect(result.userResponse, stubFullRefusalUserResponse);
        expect(result.status.creature.hunger, 0);
        expect(result.status.creature.energy, 100);

        // Stats untouched (a refusal moves nothing).
        final stored = await Creature.db.findById(session, creature.id!);
        expect(stored!.hunger, 0);
        expect(stored.energy, 100);

        // The full refusal is now recorded — one entry, zero delta (not null),
        // full-refusal prose. Mirrors the picky test below.
        final entries = await _feedEntries(session, creature.id!);
        expect(entries, hasLength(1));
        final entry = entries.single;
        expect(entry.prose, stubFullRefusalJournalNarrative);
        expect(entry.statDelta!.hungerDelta, 0);
        expect(entry.statDelta!.energyDelta, 0);
        expect(entry.statDelta!.loveDelta, 0);
        expect(entry.statDelta!.illnessDelta, 0);
      },
    );

    test(
      'a picky refusal accepts nothing, leaves stats unchanged, but still writes '
      'a feed journal entry with a zero delta + refusal prose',
      () async {
        // picky = pickyFactor(0.5) = 1.0; tastiness 0.0 → reject p = 0.9; the
        // reject roll 0.0 < 0.9 ⇒ refuse.
        _injectFeedService(const [0.0, 0.0]);
        final userUuid = const Uuid().v4();
        final authed = _authedAs(sessionBuilder, userUuid);
        final session = authed.build();
        final creature = await _seedCreature(
          session,
          userUuid,
          hunger: 10,
          hungerDecayMod: 0.5,
        );

        final result = await endpoints.creature.feed(authed);

        expect(result.accepted, isFalse);
        expect(result.userResponse, stubRefuseUserResponse);

        // Stats untouched.
        final stored = await Creature.db.findById(session, creature.id!);
        expect(stored!.hunger, 10);
        expect(stored.energy, 100);

        // The refusal is still recorded — one entry, zero delta, refusal prose.
        final entries = await _feedEntries(session, creature.id!);
        expect(entries, hasLength(1));
        final entry = entries.single;
        expect(entry.prose, stubRefuseJournalNarrative);
        expect(entry.statDelta!.hungerDelta, 0);
        expect(entry.statDelta!.energyDelta, 0);
        expect(entry.statDelta!.loveDelta, 0);
        expect(entry.statDelta!.illnessDelta, 0);
      },
    );

    test(
      'when the model call fails the feed degrades: stats still change, a feed '
      'entry lands with the degrade prose, and feed() does not throw',
      () async {
        _injectFeedService(const [0.5, 0.99], llm: const _ThrowingLlmService());
        final userUuid = const Uuid().v4();
        final authed = _authedAs(sessionBuilder, userUuid);
        final session = authed.build();
        final creature = await _seedCreature(session, userUuid, hunger: 80);

        final result = await endpoints.creature.feed(authed);

        expect(result.accepted, isTrue);
        expect(result.userResponse, degradeUserResponse);

        final stored = await Creature.db.findById(session, creature.id!);
        expect(stored!.hunger, 50);
        expect(stored.energy, 90);

        final entries = await _feedEntries(session, creature.id!);
        expect(entries, hasLength(1));
        expect(entries.single.prose, degradeJournalNarrative);
        expect(entries.single.statDelta!.hungerDelta, -30);
      },
    );

    test(
      'an exhausted creature (energy < feedEnergyCost) is gated: a canned '
      'exhausted line, no LLM call, no journal entry, no stat change, '
      'exhausted/accepted flags, and canFeed false',
      () async {
        // Gate path draws no gate roll (decide() is never reached) — an empty
        // ScriptedRandom throws if a nextDouble is drawn, asserting that. The
        // throwing LLM proves the model is never called: if the gate regressed
        // and feed proceeded, the response would be the degrade line, not a pool
        // line (and the empty rng would throw at decide()).
        _injectFeedService(const [], llm: const _ThrowingLlmService());
        final userUuid = const Uuid().v4();
        final authed = _authedAs(sessionBuilder, userUuid);
        final session = authed.build();
        // energy 5 < feedEnergyCost (10); hunger 80 so it is NOT a full-refusal.
        final creature = await _seedCreature(
          session,
          userUuid,
          hunger: 80,
          energy: 5,
        );

        final result = await endpoints.creature.feed(authed);

        expect(result.exhausted, isTrue);
        expect(result.accepted, isFalse);
        expect(result.userResponse, isIn(feedExhaustedLines));
        expect(result.status.canFeed, isFalse);
        // Stats unchanged on the returned status.
        expect(result.status.creature.energy, 5);
        expect(result.status.creature.hunger, 80);

        // Nothing persisted: energy/hunger untouched, no feed journal entry.
        final stored = await Creature.db.findById(session, creature.id!);
        expect(stored!.energy, 5);
        expect(stored.hunger, 80);
        expect(await _feedEntries(session, creature.id!), isEmpty);
      },
    );

    test(
      'a creature that is both full (hunger==0) and exhausted (energy < '
      'feedEnergyCost) returns the exhausted line, not the full-refusal line: '
      'the energy gate takes priority over the full-refusal check',
      () async {
        // Empty rng + throwing LLM: the gate path draws no roll and never calls
        // the model. If the gate regressed and the full-refusal check ran first,
        // userResponse would be a fullRefusalLines member instead.
        _injectFeedService(const [], llm: const _ThrowingLlmService());
        final userUuid = const Uuid().v4();
        final authed = _authedAs(sessionBuilder, userUuid);
        final session = authed.build();
        // hunger 0 (full) AND energy 5 < feedEnergyCost (10) (exhausted).
        final creature = await _seedCreature(
          session,
          userUuid,
          hunger: 0,
          energy: 5,
        );

        final result = await endpoints.creature.feed(authed);

        // Exhausted wins: the response is a tired line, not a full line.
        expect(result.exhausted, isTrue);
        expect(result.userResponse, isIn(feedExhaustedLines));
        expect(result.userResponse, isNot(isIn(fullRefusalLines)));

        // Still a non-event: nothing persisted, no journal entry.
        final stored = await Creature.db.findById(session, creature.id!);
        expect(stored!.energy, 5);
        expect(stored.hunger, 0);
        expect(await _feedEntries(session, creature.id!), isEmpty);
      },
    );

    test(
      'feeding with no creature throws CreatureFeedError(noCreature)',
      () async {
        _injectFeedService(const [0.5, 0.99]);
        final authed = _authedAs(sessionBuilder, const Uuid().v4());

        await expectLater(
          () => endpoints.creature.feed(authed),
          throwsA(
            isA<CreatureFeedError>().having(
              (e) => e.reason,
              'reason',
              CreatureFeedErrorReason.noCreature,
            ),
          ),
        );
      },
    );

    test(
      'feed is owner-scoped: feeding as user B never touches user A\'s creature',
      () async {
        _injectFeedService(const [0.5, 0.99]);
        final userA = const Uuid().v4();
        final userB = const Uuid().v4();
        final session = sessionBuilder.build();
        final creatureA = await _seedCreature(session, userA, hunger: 80);
        final creatureB = await _seedCreature(session, userB, hunger: 80);

        // B feeds — only B's creature should change.
        await endpoints.creature.feed(_authedAs(sessionBuilder, userB));

        final storedA = await Creature.db.findById(session, creatureA.id!);
        final storedB = await Creature.db.findById(session, creatureB.id!);
        expect(storedA!.hunger, 80, reason: "A's creature must be untouched");
        expect(storedB!.hunger, 50, reason: "B's creature was fed");

        expect(await _feedEntries(session, creatureA.id!), isEmpty);
        expect(await _feedEntries(session, creatureB.id!), hasLength(1));
      },
    );
  });
}
