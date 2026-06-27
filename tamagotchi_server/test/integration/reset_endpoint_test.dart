import 'package:serverpod/serverpod.dart';
import 'package:tamagotchi_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

TestSessionBuilder _authedAs(TestSessionBuilder builder, String userUuid) =>
    builder.copyWith(
      authentication: AuthenticationOverride.authenticationInfo(
        userUuid,
        <Scope>{},
      ),
    );

Future<List<JournalEntry>> _journalFor(Session session, UuidValue creatureId) =>
    JournalEntry.db.find(
      session,
      where: (t) => t.creatureId.equals(creatureId),
    );

Future<List<CreaturePersonality>> _personalityFor(
  Session session,
  UuidValue creatureId,
) => CreaturePersonality.db.find(
  session,
  where: (t) => t.creatureId.equals(creatureId),
);

void main() {
  withServerpod('Given CreatureEndpoint.reset', (sessionBuilder, endpoints) {
    test(
      'deletes the creature and cascades to its personality and journal, '
      'leaving myCreature null',
      () async {
        final userUuid = const Uuid().v4();
        final authed = _authedAs(sessionBuilder, userUuid);
        final session = authed.build();

        final status = await endpoints.creature.hatch(authed, 'Doomed');
        final creatureId = status.creature.id!;

        // Precondition: hatch wrote all three rows (creature, personality,
        // hatched journal marker) so the cascade has something to remove.
        expect(await Creature.db.findById(session, creatureId), isNotNull);
        expect(await _personalityFor(session, creatureId), hasLength(1));
        expect(await _journalFor(session, creatureId), isNotEmpty);

        await endpoints.creature.reset(authed);

        // The creature and everything hanging off it is gone.
        expect(await endpoints.creature.myCreature(authed), isNull);
        expect(await Creature.db.findById(session, creatureId), isNull);
        expect(await _personalityFor(session, creatureId), isEmpty);
        expect(await _journalFor(session, creatureId), isEmpty);
      },
    );

    test(
      'reset with no creature completes without throwing (idempotent)',
      () async {
        final authed = _authedAs(sessionBuilder, const Uuid().v4());

        await expectLater(endpoints.creature.reset(authed), completes);
        expect(await endpoints.creature.myCreature(authed), isNull);
      },
    );

    test('hatch succeeds again after reset (no alreadyHatched)', () async {
      final authed = _authedAs(sessionBuilder, const Uuid().v4());

      await endpoints.creature.hatch(authed, 'First');
      await endpoints.creature.reset(authed);
      final second = await endpoints.creature.hatch(authed, 'Second');

      expect(second.creature.name, 'Second');
      expect(await endpoints.creature.myCreature(authed), isNotNull);
    });

    test(
      "is owner-scoped: resetting as B never deletes A's creature",
      () async {
        final authedA = _authedAs(sessionBuilder, const Uuid().v4());
        final authedB = _authedAs(sessionBuilder, const Uuid().v4());

        final a = await endpoints.creature.hatch(authedA, 'Ayla');
        await endpoints.creature.hatch(authedB, 'Bjorn');

        await endpoints.creature.reset(authedB);

        // A survives untouched; only B's creature is gone.
        expect(await endpoints.creature.myCreature(authedA), isNotNull);
        expect(
          await Creature.db.findById(authedA.build(), a.creature.id!),
          isNotNull,
        );
        expect(await endpoints.creature.myCreature(authedB), isNull);
      },
    );
  });
}
