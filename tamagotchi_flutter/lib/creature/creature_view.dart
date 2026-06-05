import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tamagotchi_client/tamagotchi_client.dart';

import 'feed_controller.dart';

/// The present-creature state: the creature's name, its derived [mood] label,
/// the four raw stat numbers (0–100, raw per MVP — no icons/bars), and the
/// Feed interaction.
///
/// A [ConsumerWidget] (was a `StatelessWidget`) so it can host the Feed button
/// and watch [feedControllerProvider]: while a feed is in flight the button is
/// replaced by a continuous loading animation (NFR-1); on success the
/// in-character `userResponse` renders below — styled distinctly when the
/// creature *refused* (`accepted == false`). The four [_StatRow]s re-render once
/// the controller invalidates `creatureProvider` after a feed.
class CreatureView extends ConsumerWidget {
  const CreatureView({required this.status, super.key});

  final CreatureStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final creature = status.creature;
    final feedState = ref.watch(feedControllerProvider);
    // The outcome of the most recent feed, if any (null before the first feed,
    // and while loading/errored).
    final feedResult = feedState.asData?.value;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(creature.name, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Mood: ${status.mood.name}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            _StatRow(label: 'Hunger', value: creature.hunger),
            _StatRow(label: 'Energy', value: creature.energy),
            _StatRow(label: 'Love', value: creature.love),
            _StatRow(label: 'Illness', value: creature.illness),
            const SizedBox(height: 24),
            // In-flight: a continuous animation in place of the button. On
            // success: the response below + the button stays for another feed.
            if (feedState.isLoading)
              const _FeedingIndicator()
            else
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(feedControllerProvider.notifier).feed(),
                icon: const Icon(Icons.restaurant),
                label: const Text('Feed'),
              ),
            // RPC/network failure only — refusals are data, rendered below.
            if (feedState.hasError && !feedState.isLoading) ...[
              const SizedBox(height: 16),
              Text(
                'Something went wrong feeding — please try again.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            // The in-character outcome of the most recent feed, if any.
            if (feedResult != null) ...[
              const SizedBox(height: 16),
              _FeedResponse(result: feedResult),
            ],
          ],
        ),
      ),
    );
  }
}

/// The continuous "feeding…" progress shown during the model round-trip.
class _FeedingIndicator extends StatelessWidget {
  const _FeedingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 8),
        Text('Feeding…'),
      ],
    );
  }
}

/// Renders a [FeedResult]'s in-character `userResponse`. An accepted feed reads
/// as the creature's happy reaction; a refusal (`accepted == false`) is styled
/// distinctly — italic, muted — so a "no" never looks like an error.
class _FeedResponse extends StatelessWidget {
  const _FeedResponse({required this.result});

  final FeedResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyLarge;
    final style = result.accepted
        ? base
        : base?.copyWith(
            fontStyle: FontStyle.italic,
            color: theme.colorScheme.onSurfaceVariant,
          );

    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: result.accepted
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        result.userResponse,
        textAlign: TextAlign.center,
        style: style,
      ),
    );
  }
}

/// One labelled stat line, e.g. `Energy  100`.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 100, child: Text(label)),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
