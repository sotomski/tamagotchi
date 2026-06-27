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

/// Seeds a creature directly (bypassing hatch — the read path doesn't care how
/// the creature was born, only who owns it).
Future<Creature> _seedCreature(
  Session session,
  String userUuid, {
  String name = 'Testy',
}) => Creature.db.insertRow(
  session,
  Creature(
    ownerUuid: UuidValue.fromString(userUuid),
    name: name,
    hunger: 0,
    energy: 100,
    love: 50,
    illness: 0,
  ),
);

/// Seeds one journal entry. `timestamp` is set explicitly so ordering is
/// deterministic (the model's `default=now` would otherwise cluster inserts).
Future<JournalEntry> _seedEntry(
  Session session,
  Creature creature, {
  required JournalEvent event,
  String prose = '',
  required DateTime timestamp,
}) => JournalEntry.db.insertRow(
  session,
  JournalEntry(
    creatureId: creature.id!,
    ownerUuid: creature.ownerUuid,
    event: event,
    prose: prose,
    statDelta: null,
    timestamp: timestamp,
  ),
);

void main() {
  withServerpod('Given CreatureEndpoint.readJournal', (
    sessionBuilder,
    endpoints,
  ) {
    test(
      'a non-owner read never returns another owner\'s journal entries (IDOR)',
      () async {
        final userA = const Uuid().v4();
        final userB = const Uuid().v4();
        final session = sessionBuilder.build();

        final creatureA = await _seedCreature(session, userA, name: 'Aysha');
        final creatureB = await _seedCreature(session, userB, name: 'Bodun');
        await _seedEntry(
          session,
          creatureA,
          event: JournalEvent.feed,
          prose: "A's secret dinner",
          timestamp: DateTime.utc(2026, 6, 1),
        );
        await _seedEntry(
          session,
          creatureB,
          event: JournalEvent.feed,
          prose: "B's own dinner",
          timestamp: DateTime.utc(2026, 6, 1),
        );

        final asB = await endpoints.creature.readJournal(
          _authedAs(sessionBuilder, userB),
        );

        // B sees only B's rows — never A's.
        expect(
          asB.every((e) => e.ownerUuid == UuidValue.fromString(userB)),
          isTrue,
          reason: "B's read must contain only B's entries",
        );
        expect(
          asB.any((e) => e.creatureId == creatureA.id),
          isFalse,
          reason: "A's creature entries must never leak to B",
        );
        expect(asB.map((e) => e.prose), isNot(contains("A's secret dinner")));
      },
    );

    test(
      'the owner reads all their entries newest-first, including the '
      'empty-prose hatched marker',
      () async {
        final userA = const Uuid().v4();
        final session = sessionBuilder.build();
        final creature = await _seedCreature(session, userA);

        // Oldest is the empty-prose hatched marker; newest is a play entry.
        await _seedEntry(
          session,
          creature,
          event: JournalEvent.hatched,
          prose: '',
          timestamp: DateTime.utc(2026, 6, 1),
        );
        await _seedEntry(
          session,
          creature,
          event: JournalEvent.feed,
          prose: 'mid',
          timestamp: DateTime.utc(2026, 6, 2),
        );
        await _seedEntry(
          session,
          creature,
          event: JournalEvent.play,
          prose: 'newest',
          timestamp: DateTime.utc(2026, 6, 3),
        );

        final entries = await endpoints.creature.readJournal(
          _authedAs(sessionBuilder, userA),
        );

        expect(entries, hasLength(3));
        // Newest-first ordering.
        expect(entries.first.event, JournalEvent.play);
        expect(entries.last.event, JournalEvent.hatched);
        // The empty-prose hatched marker is kept (not dropped like the LLM
        // memory window does).
        expect(
          entries.any(
            (e) => e.event == JournalEvent.hatched && e.prose.isEmpty,
          ),
          isTrue,
        );
      },
    );
  });
}
