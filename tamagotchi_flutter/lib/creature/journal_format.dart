import 'package:tamagotchi_client/tamagotchi_client.dart';

/// Pure presentation helpers for the journal screen — kept Flutter-free so they
/// can be unit-tested in isolation (day-bucketing, day-header formatting, the
/// entry classifier, and the event→label map). No `intl`: headers are
/// hand-formatted (project convention).

/// The visual kind of a journal entry, which decides how the screen renders it.
///
/// - [origin]   — the `hatched` birth marker, shown as the distinct "Day one" card.
/// - [zeroDelta] — an interaction that changed nothing (e.g. a full refusal):
///   softened/relabelled, **kept** (never suppressed), no "+0" stat chips.
/// - [normal]   — an interaction with at least one non-zero stat delta.
enum JournalEntryKind { origin, zeroDelta, normal }

/// Classifies [entry] for rendering. `hatched` is always [origin]; otherwise an
/// absent or all-zero [JournalEntry.statDelta] is [zeroDelta], and any non-zero
/// delta is [normal].
JournalEntryKind classifyEntry(JournalEntry entry) {
  if (entry.event == JournalEvent.hatched) return JournalEntryKind.origin;
  final delta = entry.statDelta;
  final isZero =
      delta == null ||
      (delta.hungerDelta == 0 &&
          delta.energyDelta == 0 &&
          delta.loveDelta == 0 &&
          delta.illnessDelta == 0);
  return isZero ? JournalEntryKind.zeroDelta : JournalEntryKind.normal;
}

/// The short, human label for an event. `play` maps to **"Pet"** at this label
/// layer only — never rename the [JournalEvent] enum value (it serializes
/// by-name; a rename would break existing rows).
String eventLabel(JournalEvent event) => switch (event) {
  JournalEvent.hatched => 'Born',
  JournalEvent.feed => 'Fed',
  JournalEvent.play => 'Pet',
  JournalEvent.cure => 'Cured',
};

/// One calendar day's worth of entries. [entries] keep their incoming order
/// (newest-first, as the endpoint returns them); [date] is local midnight.
class JournalDay {
  JournalDay({required this.date, required this.entries});

  final DateTime date;
  final List<JournalEntry> entries;
}

/// Buckets a newest-first [entries] list into consecutive calendar-day groups
/// (newest day first). Relies on the incoming order already being sorted, so it
/// only needs to compare against the current group — no global sort.
List<JournalDay> groupByDay(List<JournalEntry> entries) {
  final days = <JournalDay>[];
  for (final entry in entries) {
    final local = entry.timestamp.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    if (days.isNotEmpty && days.last.date == day) {
      days.last.entries.add(entry);
    } else {
      days.add(JournalDay(date: day, entries: [entry]));
    }
  }
  return days;
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// A hand-formatted day header relative to [now]: "Today" / "Yesterday" /
/// "June 25" (current year) / "June 25, 2025" (other years). No `intl`.
String formatDayHeader(DateTime day, {required DateTime now}) {
  final thisDay = DateTime(day.year, day.month, day.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(thisDay).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  final monthDay = '${_monthNames[day.month - 1]} ${day.day}';
  return day.year == now.year ? monthDay : '$monthDay, ${day.year}';
}
