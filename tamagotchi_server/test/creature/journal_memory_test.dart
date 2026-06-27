import 'package:serverpod/serverpod.dart';
import 'package:tamagotchi_server/src/creature/journal_memory.dart';
import 'package:tamagotchi_server/src/generated/protocol.dart';
import 'package:test/test.dart';

/// A fixed "now" so relative-age rendering is deterministic. All timestamps in
/// the suite are expressed as offsets from this instant (UTC, matching how the
/// server stores `timestamp`).
final _now = DateTime.utc(2026, 6, 27, 12);

final _creatureId = UuidValue.fromString(
  '00000000-0000-7000-8000-000000000001',
);
final _ownerUuid = UuidValue.fromString('00000000-0000-7000-8000-000000000002');

/// Builds a journal entry [daysAgo]/[hoursAgo] before [_now] with a stable id so
/// dedup-by-id can be asserted.
JournalEntry _entry({
  required String id,
  required JournalEvent event,
  required String prose,
  int daysAgo = 0,
  int hoursAgo = 0,
}) => JournalEntry(
  id: UuidValue.fromString(id),
  creatureId: _creatureId,
  ownerUuid: _ownerUuid,
  timestamp: _now.subtract(Duration(days: daysAgo, hours: hoursAgo)),
  event: event,
  prose: prose,
);

void main() {
  group('relativeAge', () {
    test('same calendar day → "earlier today"', () {
      expect(
        relativeAge(_now.subtract(const Duration(hours: 3)), _now),
        'earlier today',
      );
    });

    test('previous calendar day → "yesterday"', () {
      expect(
        relativeAge(_now.subtract(const Duration(days: 1)), _now),
        'yesterday',
      );
    });

    test('a few days back → "N days ago"', () {
      expect(
        relativeAge(_now.subtract(const Duration(days: 3)), _now),
        '3 days ago',
      );
    });

    test('beyond a week → "a while back"', () {
      expect(
        relativeAge(_now.subtract(const Duration(days: 20)), _now),
        'a while back',
      );
    });
  });

  group('assembleMemoryWindow', () {
    test('renders event + relative age + prose, newest first', () {
      final window = assembleMemoryWindow(
        recent: [
          _entry(
            id: '00000000-0000-7000-8000-00000000000a',
            event: JournalEvent.feed,
            prose: 'Devoured a Quadruple-Truffle Soufflé.',
            hoursAgo: 2,
          ),
          _entry(
            id: '00000000-0000-7000-8000-00000000000b',
            event: JournalEvent.play,
            prose: 'Chased the ribbon for hours.',
            daysAgo: 1,
          ),
        ],
        birth: null,
        now: _now,
      );

      expect(window, hasLength(2));
      expect(window.first.event, JournalEvent.feed);
      expect(window.first.age, 'earlier today');
      expect(window.first.prose, contains('Soufflé'));
      expect(window[1].age, 'yesterday');
    });

    test('drops empty-prose entries', () {
      final window = assembleMemoryWindow(
        recent: [
          _entry(
            id: '00000000-0000-7000-8000-00000000000a',
            event: JournalEvent.feed,
            prose: 'Ate well.',
          ),
          _entry(
            id: '00000000-0000-7000-8000-00000000000b',
            event: JournalEvent.hatched,
            prose: '',
          ),
        ],
        birth: null,
        now: _now,
      );

      expect(window, hasLength(1));
      expect(window.single.event, JournalEvent.feed);
    });

    test(
      'pins the birth entry at the end when it falls outside the window',
      () {
        final birth = _entry(
          id: '00000000-0000-7000-8000-0000000000ff',
          event: JournalEvent.hatched,
          prose: 'I awoke as Nibbles and met my owner.',
          daysAgo: 30,
        );

        final window = assembleMemoryWindow(
          recent: [
            _entry(
              id: '00000000-0000-7000-8000-00000000000a',
              event: JournalEvent.feed,
              prose: 'A recent snack.',
            ),
          ],
          birth: birth,
          now: _now,
        );

        expect(window, hasLength(2));
        expect(window.last.event, JournalEvent.hatched);
        expect(window.last.prose, contains('Nibbles'));
        expect(window.last.age, 'a while back');
      },
    );

    test('does not duplicate the birth when it is already in the window', () {
      final birth = _entry(
        id: '00000000-0000-7000-8000-0000000000ff',
        event: JournalEvent.hatched,
        prose: 'I awoke as Nibbles.',
        hoursAgo: 5,
      );

      final window = assembleMemoryWindow(
        recent: [
          _entry(
            id: '00000000-0000-7000-8000-00000000000a',
            event: JournalEvent.feed,
            prose: 'A recent snack.',
            hoursAgo: 1,
          ),
          birth,
        ],
        birth: birth,
        now: _now,
      );

      final hatchedCount = window
          .where((e) => e.event == JournalEvent.hatched)
          .length;
      expect(hatchedCount, 1, reason: 'birth must appear exactly once');
      expect(window, hasLength(2));
    });
  });
}
