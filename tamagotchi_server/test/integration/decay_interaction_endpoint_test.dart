import 'package:serverpod/serverpod.dart';
import 'package:tamagotchi_server/src/creature/cure_service.dart';
import 'package:tamagotchi_server/src/creature/decay_service.dart';
import 'package:tamagotchi_server/src/creature/feed_service.dart';
import 'package:tamagotchi_server/src/creature/play_service.dart';
import 'package:tamagotchi_server/src/generated/protocol.dart';
import 'package:tamagotchi_server/src/llm/feed_copy.dart';
import 'package:tamagotchi_server/src/llm/play_copy.dart';
import 'package:tamagotchi_server/src/llm/stub_llm_service.dart';
import 'package:test/test.dart';

import '../helpers/scripted_random.dart';
import 'test_tools/serverpod_test_tools.dart';

/// A fixed instant the injected clock always returns, so the elapsed window each
/// test seeds is exact and reproducible.
final _now = DateTime.utc(2026, 6, 21, 12);

/// Pins the decay clock seam to [_now] for the duration of one test, restoring
/// production wiring afterwards (even on failure).
void _freezeClockAtNow() {
  clockFactory = (_) =>
      () => _now;
  addTearDown(() => clockFactory = clockFor);
}

/// Injects a [FeedService] with a scripted rng + hermetic stub LLM; self-cleans.
void _injectFeedService(List<double> doubles) {
  feedServiceFactory = (_) =>
      FeedService(rng: ScriptedRandom(doubles), llm: const StubLlmService());
  addTearDown(() => feedServiceFactory = feedServiceFor);
}

/// Injects a [PlayService] with a scripted rng (the stat path draws none — an
/// empty queue throws if it does) + hermetic stub LLM; self-cleans.
void _injectPlayService() {
  playServiceFactory = (_) =>
      PlayService(rng: ScriptedRandom(const []), llm: const StubLlmService());
  addTearDown(() => playServiceFactory = playServiceFor);
}

/// Injects a [CureService] with the hermetic stub LLM; self-cleans.
void _injectCureService() {
  cureServiceFactory = (_) => CureService(llm: const StubLlmService());
  addTearDown(() => cureServiceFactory = cureServiceFor);
}

TestSessionBuilder _authedAs(TestSessionBuilder builder, String userUuid) =>
    builder.copyWith(
      authentication: AuthenticationOverride.authenticationInfo(
        userUuid,
        <Scope>{},
      ),
    );

/// Seeds a creature whose `lastDecayedAt` sits [minutesAgo] before [_now], plus
/// its 1:1 baseline personality, bypassing hatch so the test controls the anchor
/// and stats.
Future<Creature> _seedCreature(
  Session session,
  String userUuid, {
  required int minutesAgo,
  int hunger = 0,
  int energy = 50,
  int love = 50,
  int illness = 0,
}) async {
  final anchor = _now.subtract(Duration(minutes: minutesAgo));
  final creature = await Creature.db.insertRow(
    session,
    Creature(
      ownerUuid: UuidValue.fromString(userUuid),
      name: 'Testy',
      hunger: hunger,
      energy: energy,
      love: love,
      illness: illness,
      hatchedAt: anchor,
      lastDecayedAt: anchor,
    ),
  );
  await CreaturePersonality.db.insertRow(
    session,
    CreaturePersonality(
      creatureId: creature.id!,
      hungerDecayMod: 1.0,
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

Future<List<JournalEntry>> _entries(
  Session session,
  UuidValue creatureId,
  JournalEvent event,
) => JournalEntry.db.find(
  session,
  where: (t) => t.creatureId.equals(creatureId) & t.event.equals(event),
);

void main() {
  withServerpod('Given an interaction after an idle period', (
    sessionBuilder,
    endpoints,
  ) {
    test(
      'feed decays first (hunger↑/energy↑/love↓) then applies the feed delta to '
      'the decayed stats, advances the anchor, and writes exactly one feed entry',
      () async {
        _freezeClockAtNow();
        _injectFeedService(const [0.5, 0.99]);
        final userUuid = const Uuid().v4();
        final authed = _authedAs(sessionBuilder, userUuid);
        final session = authed.build();
        // 60 game-min @1× ⇒ 6 ticks: hunger 80→92, energy 50→56, love 50→44.
        final creature = await _seedCreature(
          session,
          userUuid,
          minutesAgo: 60,
          hunger: 80,
          energy: 50,
          love: 50,
          illness: 0,
        );

        final result = await endpoints.creature.feed(authed);

        // Decay-then-feed: hunger 92−30=62 (NOT 80−30=50), energy 56−10=46.
        expect(result.accepted, isTrue);
        expect(result.status.creature.hunger, 62);
        expect(result.status.creature.energy, 46);
        expect(result.status.creature.love, 44);
        expect(result.status.creature.illness, 0);
        // 6 ticks = 60 real-min consumed ⇒ anchor lands exactly on `now`.
        expect(result.status.creature.lastDecayedAt, _now);

        // Persisted, not just returned.
        final stored = await Creature.db.findById(session, creature.id!);
        expect(stored!.hunger, 62);
        expect(stored.energy, 46);
        expect(stored.love, 44);
        expect(stored.lastDecayedAt, _now);

        // Exactly one feed entry — decay added none; the delta is the feed's.
        final entries = await _entries(
          session,
          creature.id!,
          JournalEvent.feed,
        );
        expect(entries, hasLength(1));
        expect(entries.single.statDelta!.hungerDelta, -30);
        expect(entries.single.statDelta!.energyDelta, -10);
      },
    );

    test(
      'play decays first then applies the play delta to the decayed stats, '
      'advances the anchor, and writes exactly one play entry',
      () async {
        _freezeClockAtNow();
        _injectPlayService();
        final userUuid = const Uuid().v4();
        final authed = _authedAs(sessionBuilder, userUuid);
        final session = authed.build();
        // 60 game-min @1× ⇒ 6 ticks: hunger 0→12, energy 50→56, love 50→44.
        final creature = await _seedCreature(
          session,
          userUuid,
          minutesAgo: 60,
          hunger: 0,
          energy: 50,
          love: 50,
          illness: 0,
        );

        final result = await endpoints.creature.play(authed);

        // Decay-then-play: love 44+15=59 (NOT 50+15=65), energy 56−4=52.
        expect(result.status.creature.love, 59);
        expect(result.status.creature.energy, 52);
        expect(result.status.creature.hunger, 12);
        expect(result.status.creature.illness, 0);
        expect(result.status.creature.lastDecayedAt, _now);

        final stored = await Creature.db.findById(session, creature.id!);
        expect(stored!.love, 59);
        expect(stored.energy, 52);
        expect(stored.hunger, 12);
        expect(stored.lastDecayedAt, _now);

        final entries = await _entries(
          session,
          creature.id!,
          JournalEvent.play,
        );
        expect(entries, hasLength(1));
        expect(entries.single.statDelta!.loveDelta, 15);
        expect(entries.single.statDelta!.energyDelta, -4);
      },
    );

    test(
      'cure decays first (non-illness stats move) then applies the cure delta, '
      'advances the anchor, and writes exactly one cure entry',
      () async {
        _freezeClockAtNow();
        _injectCureService();
        final userUuid = const Uuid().v4();
        final authed = _authedAs(sessionBuilder, userUuid);
        final session = authed.build();
        // 60 game-min @1× ⇒ 6 ticks: hunger 0→12, energy 50→56, love 50→44;
        // illness never decays ⇒ stays 80 until the cure relieves it.
        final creature = await _seedCreature(
          session,
          userUuid,
          minutesAgo: 60,
          hunger: 0,
          energy: 50,
          love: 50,
          illness: 80,
        );

        final result = await endpoints.creature.cure(authed);

        // Cure relieves illness 80−40=40; the decayed non-illness stats persist.
        expect(result.status.creature.illness, 40);
        expect(result.status.creature.hunger, 12);
        expect(result.status.creature.energy, 56);
        expect(result.status.creature.love, 44);
        expect(result.status.creature.lastDecayedAt, _now);

        final stored = await Creature.db.findById(session, creature.id!);
        expect(stored!.illness, 40);
        expect(stored.hunger, 12);
        expect(stored.energy, 56);
        expect(stored.love, 44);
        expect(stored.lastDecayedAt, _now);

        final entries = await _entries(
          session,
          creature.id!,
          JournalEvent.cure,
        );
        expect(entries, hasLength(1));
        expect(entries.single.statDelta!.illnessDelta, -40);
      },
    );

    test(
      'an exhausted feed across an idle window that fired a decay tick returns '
      'the post-decay (regenerated) energy but persists nothing: the anchor is '
      'NOT advanced and no feed entry lands (idempotent recompute next poll)',
      () async {
        _freezeClockAtNow();
        // Empty rng + stub LLM: the gate returns before decide()/the model, so
        // an empty queue throwing would surface a regressed gate.
        _injectFeedService(const []);
        final userUuid = const Uuid().v4();
        final authed = _authedAs(sessionBuilder, userUuid);
        final session = authed.build();
        // 60 game-min @1× ⇒ 6 ticks: energy regenerates 2→8 — a tick DID fire
        // (decayed.changed == true), yet 8 is still < feedEnergyCost (10).
        final creature = await _seedCreature(
          session,
          userUuid,
          minutesAgo: 60,
          hunger: 80,
          energy: 2,
        );
        final anchorBefore = creature.lastDecayedAt;

        final result = await endpoints.creature.feed(authed);

        // Gate fired on the post-decay energy.
        expect(result.exhausted, isTrue);
        expect(result.userResponse, isIn(feedExhaustedLines));
        expect(result.status.creature.energy, 8); // decay was computed
        expect(result.status.canFeed, isFalse);

        // Nothing persisted: the anchor still sits where we seeded it (NOT _now),
        // the stored energy is the un-decayed seed, and no feed entry was written.
        final stored = await Creature.db.findById(session, creature.id!);
        expect(stored!.lastDecayedAt, anchorBefore);
        expect(stored.lastDecayedAt, isNot(_now));
        expect(stored.energy, 2);
        expect(
          await _entries(session, creature.id!, JournalEvent.feed),
          isEmpty,
        );
      },
    );

    test(
      'an exhausted play across an idle window that fired a decay tick returns '
      'the post-decay energy but persists nothing: the anchor is NOT advanced '
      'and no play entry lands (idempotent recompute next poll)',
      () async {
        _freezeClockAtNow();
        _injectPlayService();
        final userUuid = const Uuid().v4();
        final authed = _authedAs(sessionBuilder, userUuid);
        final session = authed.build();
        // 30 game-min @1× ⇒ 3 ticks: energy regenerates 0→3 — a tick DID fire,
        // yet 3 is still < playEnergyCost(1.0) == 4.
        final creature = await _seedCreature(
          session,
          userUuid,
          minutesAgo: 30,
          hunger: 0,
          energy: 0,
        );
        final anchorBefore = creature.lastDecayedAt;

        final result = await endpoints.creature.play(authed);

        expect(result.exhausted, isTrue);
        expect(result.userResponse, isIn(playExhaustedLines));
        expect(result.status.creature.energy, 3); // decay was computed
        expect(result.status.canPlay, isFalse);

        final stored = await Creature.db.findById(session, creature.id!);
        expect(stored!.lastDecayedAt, anchorBefore);
        expect(stored.lastDecayedAt, isNot(_now));
        expect(stored.energy, 0);
        expect(
          await _entries(session, creature.id!, JournalEvent.play),
          isEmpty,
        );
      },
    );
  });
}
