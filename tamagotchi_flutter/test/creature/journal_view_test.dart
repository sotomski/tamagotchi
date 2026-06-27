import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamagotchi_client/tamagotchi_client.dart';
import 'package:tamagotchi_flutter/creature/journal_format.dart';
import 'package:tamagotchi_flutter/creature/journal_provider.dart';
import 'package:tamagotchi_flutter/creature/journal_view.dart';

/// Builds a [JournalEntry] for the tests. Owner/creature ids are fixed dummies —
/// the view never reads them.
JournalEntry _entry({
  required JournalEvent event,
  DateTime? timestamp,
  String prose = '',
  StatDelta? statDelta,
}) => JournalEntry(
  creatureId: UuidValue.fromString('00000000-0000-0000-0000-000000000002'),
  ownerUuid: UuidValue.fromString('00000000-0000-0000-0000-000000000001'),
  timestamp: timestamp ?? DateTime.now(),
  event: event,
  prose: prose,
  statDelta: statDelta,
);

StatDelta _delta({
  int hunger = 0,
  int energy = 0,
  int love = 0,
  int illness = 0,
}) => StatDelta(
  hungerDelta: hunger,
  energyDelta: energy,
  loveDelta: love,
  illnessDelta: illness,
);

/// Pumps [JournalView] (the embeddable right-half widget — wrapped in a
/// [Scaffold] since it is no longer a screen of its own) with [journalProvider]
/// overridden to [override].
Future<void> _pumpJournal(
  WidgetTester tester,
  FutureOr<List<JournalEntry>> Function(Ref ref) override,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [journalProvider.overrideWith(override)],
      child: const MaterialApp(home: Scaffold(body: JournalView())),
    ),
  );
}

void main() {
  group('pure helpers', () {
    test('classifyEntry: hatched is origin regardless of delta', () {
      expect(
        classifyEntry(_entry(event: JournalEvent.hatched)),
        JournalEntryKind.origin,
      );
    });

    test('classifyEntry: all-zero or null delta is zeroDelta', () {
      expect(
        classifyEntry(_entry(event: JournalEvent.feed, statDelta: _delta())),
        JournalEntryKind.zeroDelta,
      );
      expect(
        classifyEntry(_entry(event: JournalEvent.feed)),
        JournalEntryKind.zeroDelta,
      );
    });

    test('classifyEntry: any non-zero delta is normal', () {
      expect(
        classifyEntry(
          _entry(event: JournalEvent.feed, statDelta: _delta(hunger: -10)),
        ),
        JournalEntryKind.normal,
      );
    });

    test('eventLabel maps play to "Pet" and the rest to their labels', () {
      expect(eventLabel(JournalEvent.play), 'Pet');
      expect(eventLabel(JournalEvent.feed), 'Fed');
      expect(eventLabel(JournalEvent.cure), 'Cured');
      expect(eventLabel(JournalEvent.hatched), 'Born');
    });

    test('groupByDay buckets consecutive days, preserving order', () {
      final today = DateTime(2026, 6, 27, 10);
      final entries = [
        _entry(
          event: JournalEvent.feed,
          timestamp: today.add(const Duration(hours: 2)),
        ),
        _entry(event: JournalEvent.play, timestamp: today),
        _entry(
          event: JournalEvent.cure,
          timestamp: today.subtract(const Duration(days: 1)),
        ),
      ];

      final days = groupByDay(entries);

      expect(days, hasLength(2));
      expect(days.first.entries, hasLength(2)); // both of "today"
      expect(days.last.entries, hasLength(1)); // "yesterday"
      // Newest-first order is preserved within a day.
      expect(days.first.entries.first.event, JournalEvent.feed);
      expect(days.first.entries.last.event, JournalEvent.play);
    });

    test('formatDayHeader: Today / Yesterday / dated', () {
      final now = DateTime(2026, 6, 27, 12);
      expect(formatDayHeader(DateTime(2026, 6, 27), now: now), 'Today');
      expect(formatDayHeader(DateTime(2026, 6, 26), now: now), 'Yesterday');
      expect(formatDayHeader(DateTime(2026, 6, 20), now: now), 'June 20');
      expect(formatDayHeader(DateTime(2025, 6, 20), now: now), 'June 20, 2025');
    });
  });

  group('JournalScreen', () {
    testWidgets('while loading it shows a spinner', (tester) async {
      await _pumpJournal(
        tester,
        (ref) => Completer<List<JournalEntry>>().future,
      );
      await tester.pump();

      expect(
        find.byKey(const Key('journalLoadingIndicator')),
        findsOneWidget,
      );
    });

    testWidgets('on error it shows a message and a retry', (tester) async {
      await _pumpJournal(
        tester,
        (ref) => Future<List<JournalEntry>>.error(Exception('boom')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not load'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
    });

    testWidgets('an empty journal shows the empty state', (tester) async {
      await _pumpJournal(tester, (ref) => <JournalEntry>[]);
      await tester.pumpAndSettle();

      expect(find.textContaining('No journal entries'), findsOneWidget);
    });

    testWidgets('day headers render newest-first', (tester) async {
      final now = DateTime.now();
      await _pumpJournal(
        tester,
        (ref) => [
          _entry(
            event: JournalEvent.feed,
            timestamp: now,
            statDelta: _delta(hunger: -5),
          ),
          _entry(
            event: JournalEvent.play,
            timestamp: now.subtract(const Duration(days: 1)),
            statDelta: _delta(love: 5),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
    });

    testWidgets(
      'the hatched entry renders as a distinct "Day one" origin card',
      (
        tester,
      ) async {
        await _pumpJournal(
          tester,
          (ref) => [_entry(event: JournalEvent.hatched)],
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('journalOriginCard')), findsOneWidget);
        expect(find.text('Day one'), findsOneWidget);
        // Graceful fallback prose while Phase 3 has not filled it in yet.
        expect(find.textContaining('came into the world'), findsOneWidget);
      },
    );

    testWidgets('a zero-delta entry is softened with no "+0" chips', (
      tester,
    ) async {
      await _pumpJournal(
        tester,
        (ref) => [
          _entry(
            event: JournalEvent.feed,
            prose: "I'm too full, thanks.",
            statDelta: _delta(),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Nothing changed'), findsOneWidget);
      expect(find.textContaining('+0'), findsNothing);
    });

    testWidgets('a normal entry shows its non-zero stat deltas', (
      tester,
    ) async {
      await _pumpJournal(
        tester,
        (ref) => [
          _entry(
            event: JournalEvent.feed,
            prose: 'Delicious!',
            statDelta: _delta(hunger: -10, love: 5),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Hunger -10'), findsOneWidget);
      expect(find.text('Love +5'), findsOneWidget);
      // Untouched stats render no chip.
      expect(find.textContaining('Energy'), findsNothing);
    });

    testWidgets('a play entry is labelled "Pet"', (tester) async {
      await _pumpJournal(
        tester,
        (ref) => [
          _entry(
            event: JournalEvent.play,
            prose: 'Wheee!',
            statDelta: _delta(love: 5, energy: -3),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Pet'), findsOneWidget);
    });
  });
}
