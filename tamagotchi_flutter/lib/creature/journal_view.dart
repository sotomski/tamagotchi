import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tamagotchi_client/tamagotchi_client.dart';

import '../app/retro_loader.dart';
import 'journal_format.dart';
import 'journal_provider.dart';

/// The creature's journal, embedded as the **right half** of the home screen
/// beside [CreatureView]. Shows the history newest-first, grouped by calendar
/// day: each day gets a header ("Today" / "Yesterday" / "June 25") and every
/// entry renders as a [Card]; the `hatched` birth entry gets a distinct
/// **"Day one"** origin card, and zero-delta entries are softened (no "+0"
/// chips, a muted "nothing changed" line) rather than suppressed.
///
/// Driven by [journalProvider] via `AsyncValue.when`: a spinner while loading,
/// an inline error + retry (re-invalidating the provider) on failure, and the
/// day-grouped list — or an empty-state message — on data. The interaction
/// controllers invalidate [journalProvider] so a feed/play/cure entry shows up
/// here immediately.
class JournalView extends ConsumerWidget {
  const JournalView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final journal = ref.watch(journalProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Journal', style: theme.textTheme.titleLarge),
        ),
        const Divider(height: 1),
        Expanded(
          child: journal.when(
            loading: () => const Center(
              child: RetroLoader(key: Key('journalLoadingIndicator')),
            ),
            error: (error, _) => _JournalLoadError(
              onRetry: () => ref.invalidate(journalProvider),
            ),
            data: (entries) => entries.isEmpty
                ? const _JournalEmpty()
                : _JournalList(entries: entries),
          ),
        ),
      ],
    );
  }
}

/// Shown when [journalProvider] fails — a message plus a retry that
/// re-invalidates the provider (mirrors the home screen's error path).
class _JournalLoadError extends StatelessWidget {
  const _JournalLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Could not load the journal.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state — a creature with no journal yet (in practice rare, since the
/// hatched marker always exists, but covered for completeness).
class _JournalEmpty extends StatelessWidget {
  const _JournalEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No journal entries yet.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// A header row or an entry row in the flattened day-grouped list.
sealed class _Row {
  const _Row();
}

class _HeaderRow extends _Row {
  const _HeaderRow(this.label);
  final String label;
}

class _EntryRow extends _Row {
  const _EntryRow(this.entry);
  final JournalEntry entry;
}

/// The day-grouped journal as a single scrollable [ListView.builder]. Flattens
/// the [JournalDay] groups into header/entry rows up front so a flat builder can
/// virtualise the (bounded, ≤500) list.
class _JournalList extends StatelessWidget {
  const _JournalList({required this.entries});

  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final rows = <_Row>[];
    for (final day in groupByDay(entries)) {
      rows.add(_HeaderRow(formatDayHeader(day.date, now: now)));
      for (final entry in day.entries) {
        rows.add(_EntryRow(entry));
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return switch (row) {
          _HeaderRow(:final label) => _DayHeader(label: label),
          _EntryRow(:final entry) => _EntryCard(entry: entry),
        };
      },
    );
  }
}

/// A calendar-day section header.
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// One journal entry as a [Card], branching on its [JournalEntryKind]: a
/// distinct origin card for the birth marker, a softened card for zero-delta
/// entries, and a normal card with signed stat chips otherwise.
class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = classifyEntry(entry);

    if (kind == JournalEntryKind.origin) {
      return Card(
        key: const Key('journalOriginCard'),
        color: theme.colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Day one',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                // Graceful even before Phase 3 fills in real birth prose: the
                // hatched marker may still carry an empty `prose`.
                entry.prose.isEmpty
                    ? 'Your creature came into the world.'
                    : entry.prose,
              ),
            ],
          ),
        ),
      );
    }

    final isZeroDelta = kind == JournalEntryKind.zeroDelta;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eventLabel(entry.event),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (entry.prose.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(entry.prose),
            ],
            const SizedBox(height: 8),
            if (isZeroDelta)
              Text(
                'Nothing changed.',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _deltaChips(entry.statDelta!, theme),
              ),
          ],
        ),
      ),
    );
  }

  /// One [_DeltaChip] per **non-zero** stat — so a zero-delta entry would render
  /// no "+0" chips (it never reaches here; this only runs for [normal] entries).
  List<Widget> _deltaChips(StatDelta delta, ThemeData theme) {
    final stats = <(String, int)>[
      ('Hunger', delta.hungerDelta),
      ('Energy', delta.energyDelta),
      ('Love', delta.loveDelta),
      ('Illness', delta.illnessDelta),
    ];
    return [
      for (final (label, value) in stats)
        if (value != 0) _DeltaChip(label: label, value: value),
    ];
  }
}

/// A signed stat-delta chip, e.g. `Hunger +5` or `Energy -3`.
class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sign = value > 0 ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $sign$value',
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}
