import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../llm/llm_service.dart';
import 'decay_service.dart';

/// How many recent interactions feed the short-term memory window, before the
/// permanently-pinned birth entry (ORQ-1).
const int memoryWindowSize = 10;

/// Renders a journal entry's [timestamp] as a short relative age against [now],
/// in whole calendar days (both compared in UTC, matching how the server stores
/// timestamps). "earlier today" / "yesterday" / "N days ago" / "a while back".
/// Pure so the window assembly stays deterministic under a fixed clock.
String relativeAge(DateTime timestamp, DateTime now) {
  final today = DateTime.utc(now.year, now.month, now.day);
  final day = DateTime.utc(timestamp.year, timestamp.month, timestamp.day);
  final daysAgo = today.difference(day).inDays;
  if (daysAgo <= 0) return 'earlier today';
  if (daysAgo == 1) return 'yesterday';
  if (daysAgo <= 6) return '$daysAgo days ago';
  return 'a while back';
}

/// Pure assembly of the structured memory window: the most recent interactions
/// (newest first) plus the **permanently pinned** birth entry so the creature
/// can always recall its origin. Each entry carries its event, a relative age
/// (rendered against [now]), and its prose. Empty-prose entries are dropped (a
/// legacy blank `hatched` marker never reaches the prompt); the birth is
/// appended at the end (oldest) only when it doesn't already fall within
/// [recent], so it is never duplicated.
List<JournalMemory> assembleMemoryWindow({
  required List<JournalEntry> recent,
  required JournalEntry? birth,
  required DateTime now,
}) {
  JournalMemory render(JournalEntry e) =>
      (event: e.event, age: relativeAge(e.timestamp, now), prose: e.prose);

  final window = [
    for (final e in recent)
      if (e.prose.isNotEmpty) render(e),
  ];

  // Pin the birth permanently — append it (oldest, at the end) unless it is
  // already inside the recent window.
  if (birth != null &&
      birth.prose.isNotEmpty &&
      !recent.any((e) => e.id == birth.id)) {
    window.add(render(birth));
  }

  return window;
}

/// Loads the structured memory window for [creature]: the last
/// [memoryWindowSize] entries (newest first) plus the pinned birth entry. The
/// single source of the window used by feed/play/cure — replaces the formerly
/// 3×-duplicated flat-prose assembly. Relative ages are rendered server-side
/// from the [clockFactory] seam so the prompt builder stays clock-free.
Future<List<JournalMemory>> recentJournalMemory(
  Session session,
  Creature creature,
) async {
  final recent = await JournalEntry.db.find(
    session,
    where: (t) => t.creatureId.equals(creature.id!),
    orderBy: (t) => t.timestamp,
    orderDescending: true,
    limit: memoryWindowSize,
  );
  final birth = await JournalEntry.db.findFirstRow(
    session,
    where: (t) =>
        t.creatureId.equals(creature.id!) &
        t.event.equals(JournalEvent.hatched),
  );
  return assembleMemoryWindow(
    recent: recent,
    birth: birth,
    now: clockFactory(session)(),
  );
}
