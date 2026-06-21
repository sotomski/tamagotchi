import 'package:serverpod/serverpod.dart';
import 'package:tamagotchi_server/src/creature/decay_service.dart';
import 'package:tamagotchi_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// A fixed instant the injected clock always returns, so the elapsed window each
/// test seeds is exact and reproducible.
final _now = DateTime.utc(2026, 6, 21, 12);

/// Pins the decay clock seam to [_now] for the duration of one test, restoring
/// the production wiring afterwards (even on failure) — the same self-cleaning
/// factory-seam discipline `feed_endpoint_test.dart` uses for its rng/LLM.
void _freezeClockAtNow() {
  clockFactory = (_) =>
      () => _now;
  addTearDown(() => clockFactory = clockFor);
}

TestSessionBuilder _authedAs(TestSessionBuilder builder, String userUuid) =>
    builder.copyWith(
      authentication: AuthenticationOverride.authenticationInfo(
        userUuid,
        <Scope>{},
      ),
    );

/// Seeds a creature whose `lastDecayedAt` sits [minutesAgo] before [_now], plus
/// its 1:1 personality (decay reads the dials), bypassing hatch so the test
/// controls the anchor and stats.
Future<Creature> _seedCreature(
  Session session,
  String userUuid, {
  required int minutesAgo,
  int hunger = 0,
  int energy = 50,
  int love = 50,
  int illness = 30,
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

void main() {
  withServerpod('Given CreatureEndpoint.myCreature with decay', (
    sessionBuilder,
    endpoints,
  ) {
    test(
      'an idle creature decays on read (hunger↑, energy↑, love↓, illness fixed), '
      'persists the decayed row with an advanced anchor, and re-derives mood; '
      'an immediate second read is a no-op',
      () async {
        _freezeClockAtNow();
        final userUuid = const Uuid().v4();
        final authed = _authedAs(sessionBuilder, userUuid);
        final session = authed.build();
        // 60 game-min @1× ⇒ 6 ticks: hunger +12, energy +6, love −6.
        final creature = await _seedCreature(
          session,
          userUuid,
          minutesAgo: 60,
          hunger: 0,
          energy: 50,
          love: 50,
          illness: 30,
        );

        final status = await endpoints.creature.myCreature(authed);
        expect(status, isNotNull);
        expect(status!.creature.hunger, 12);
        expect(status.creature.energy, 56);
        expect(status.creature.love, 44);
        expect(status.creature.illness, 30);
        // 6 ticks = 60 real-min consumed ⇒ anchor lands exactly on `now`.
        expect(status.creature.lastDecayedAt, _now);
        // deriveMood(12, 56, 44, 30): worst distress 56 ⇒ sad.
        expect(status.mood, CreatureMood.sad);

        // Persisted, not just returned.
        final stored = await Creature.db.findById(session, creature.id!);
        expect(stored!.hunger, 12);
        expect(stored.energy, 56);
        expect(stored.love, 44);
        expect(stored.lastDecayedAt, _now);

        // Second read at the same instant: no whole tick elapsed ⇒ no change.
        final again = await endpoints.creature.myCreature(authed);
        expect(again!.creature.hunger, 12);
        expect(again.creature.energy, 56);
        expect(again.creature.love, 44);
        expect(again.creature.lastDecayedAt, _now);
      },
    );

    test(
      'a higher timeScale applies proportionally more decay on the same window',
      () async {
        _freezeClockAtNow();
        final userUuid = const Uuid().v4();
        final authed = _authedAs(sessionBuilder, userUuid);
        final session = authed.build();
        // 30 real-min × 2× = 60 game-min ⇒ 6 ticks ⇒ hunger +12.
        await _seedCreature(session, userUuid, minutesAgo: 30, hunger: 0);

        final status = await endpoints.creature.myCreature(
          authed,
          timeScale: 2.0,
        );
        expect(status!.creature.hunger, 12);
      },
    );
  });
}
