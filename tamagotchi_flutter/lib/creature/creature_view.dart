import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tamagotchi_client/tamagotchi_client.dart';

import 'critter_image.dart';
import 'cure_controller.dart';
import 'decay_poll.dart';
import 'feed_controller.dart';
import 'last_interaction.dart';
import 'play_controller.dart';
import 'time_scale_provider.dart';

/// The present-creature state: the creature's name, its derived [mood] label,
/// the four raw stat numbers (0–100, raw per MVP — no icons/bars), and the
/// Feed + Play + Cure interactions.
///
/// A [ConsumerWidget] (was a `StatelessWidget`) so it can host the interaction
/// buttons and watch [feedControllerProvider] / [playControllerProvider] /
/// [cureControllerProvider]: while *any* interaction is in flight the buttons
/// are replaced by a continuous loading animation (NFR-1). The most-recent
/// outcome (Feed, Play, *or* Cure) renders below in one shared area — read from
/// [lastInteractionProvider] — styled distinctly when the creature *refused* a
/// feed (`accepted == false`); Play and Cure always accept. Cure is disabled
/// when `illness == 0` (nothing to heal — a client-side UX guard only; the
/// endpoint still processes it). The four [_StatRow]s re-render once a
/// controller invalidates `creatureProvider` after an interaction.
class CreatureView extends ConsumerWidget {
  const CreatureView({required this.status, super.key});

  final CreatureStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final creature = status.creature;
    // Keep the scaled refresh poll alive for as long as the creature is on
    // screen; it disposes (cancelling its timer) when this view leaves the tree.
    ref.watch(decayPollProvider);
    final timeScale = ref.watch(timeScaleProvider);
    final feedState = ref.watch(feedControllerProvider);
    final playState = ref.watch(playControllerProvider);
    final cureState = ref.watch(cureControllerProvider);
    // The most-recent interaction outcome, if any (null before the first
    // interaction). Shared by Feed, Play, and Cure — whichever ran most recently
    // wins.
    final lastInteraction = ref.watch(lastInteractionProvider);

    final isLoading =
        feedState.isLoading || playState.isLoading || cureState.isLoading;
    final hasError =
        (feedState.hasError && !feedState.isLoading) ||
        (playState.hasError && !playState.isLoading) ||
        (cureState.hasError && !cureState.isLoading);

    // Scrollable so the (taller) content can't overflow the half-height pane it
    // now occupies beside the journal — the journal half scrolls too.
    return SingleChildScrollView(
      child: Center(
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
              // The generated pixel body, below the mood label. Renders nothing
              // for pre-feature creatures (`image == null`), so the rest of the
              // view is unaffected.
              if (creature.image != null) ...[
                const SizedBox(height: 16),
                CritterImage(spec: creature.image),
              ],
              const SizedBox(height: 24),
              _StatRow(label: 'Hunger', value: creature.hunger),
              _StatRow(label: 'Energy', value: creature.energy),
              _StatRow(label: 'Love', value: creature.love),
              _StatRow(label: 'Illness', value: creature.illness),
              const SizedBox(height: 16),
              // Time-acceleration control (FR-008): drag 1×–8× to compress both
              // how fast stats decay and how often the view refreshes.
              _SpeedControl(timeScale: timeScale),
              const SizedBox(height: 16),
              // In-flight: a continuous animation in place of the buttons. On
              // success: the response below + the buttons stay for another go.
              if (feedState.isLoading)
                const _InteractionIndicator(
                  label: 'Feeding…',
                  indicatorKey: Key('feedingIndicator'),
                )
              else if (playState.isLoading)
                const _InteractionIndicator(
                  label: 'Playing…',
                  indicatorKey: Key('playingIndicator'),
                )
              else if (cureState.isLoading)
                const _InteractionIndicator(
                  label: 'Curing…',
                  indicatorKey: Key('curingIndicator'),
                )
              else
                // A Wrap (not a Row) so the three buttons reflow onto a second
                // line when the creature occupies only half the width (it now
                // shares the home with the journal) — a bare Row overflows in
                // that narrower column.
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    // Disabled when the creature can't afford the feed's energy
                    // cost (FR-007) — `onPressed: null` greys it out and an
                    // "out of energy" hint appears below. The server enforces the
                    // gate authoritatively; this is the proactive client guard.
                    ElevatedButton.icon(
                      key: const Key('feedButton'),
                      onPressed: status.canFeed
                          ? () =>
                                ref.read(feedControllerProvider.notifier).feed()
                          : null,
                      icon: const Icon(Icons.restaurant),
                      label: const Text('Feed'),
                    ),
                    // Disabled when the creature can't afford the play's energy
                    // cost (FR-007) — same shape as Feed above.
                    ElevatedButton.icon(
                      key: const Key('playButton'),
                      onPressed: status.canPlay
                          ? () =>
                                ref.read(playControllerProvider.notifier).play()
                          : null,
                      icon: const Icon(Icons.sports_esports),
                      label: const Text('Play with'),
                    ),
                    // Disabled when there is nothing to heal (`illness == 0`) — a
                    // client-side UX guard only; the endpoint has no illness
                    // precondition. `onPressed: null` greys the button out.
                    ElevatedButton.icon(
                      key: const Key('cureButton'),
                      onPressed: creature.illness == 0
                          ? null
                          : () => ref
                                .read(cureControllerProvider.notifier)
                                .cure(),
                      icon: const Icon(Icons.healing),
                      label: const Text('Cure'),
                    ),
                  ],
                ),
              // Out-of-energy hint: shown when Feed and/or Play is unaffordable
              // and the buttons are visible (not mid-interaction). In-character,
              // explanatory — deliberately not styled as an error.
              if (!isLoading && (!status.canFeed || !status.canPlay)) ...[
                const SizedBox(height: 12),
                Text(
                  'Too tired — energy is regenerating.',
                  key: const Key('energyHint'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              // RPC/network failure on any interaction — refusals are data,
              // rendered below.
              if (hasError) ...[
                const SizedBox(height: 16),
                Text(
                  'Something went wrong — please try again.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              // The in-character outcome of the most recent interaction, if any.
              if (lastInteraction != null && !isLoading) ...[
                const SizedBox(height: 16),
                _InteractionResponse(outcome: lastInteraction),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The 1×–8× time-acceleration slider plus its current-multiplier label. Bound
/// to [timeScaleProvider]; dragging it both re-fetches the creature (the
/// provider watches the scale) and re-paces [decayPollProvider].
class _SpeedControl extends ConsumerWidget {
  const _SpeedControl({required this.timeScale});

  final double timeScale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Speed: ${timeScale.toStringAsFixed(0)}×'),
        SizedBox(
          width: 280,
          child: Slider(
            key: const Key('timeScaleSlider'),
            min: minTimeScale,
            max: maxTimeScale,
            divisions: (maxTimeScale - minTimeScale).round(),
            value: timeScale,
            label: '${timeScale.toStringAsFixed(0)}×',
            onChanged: (value) =>
                ref.read(timeScaleProvider.notifier).set(value),
          ),
        ),
      ],
    );
  }
}

/// The continuous progress shown during a model round-trip, labelled for the
/// active interaction ("Feeding…" / "Playing…" / "Curing…").
class _InteractionIndicator extends StatelessWidget {
  const _InteractionIndicator({
    required this.label,
    required this.indicatorKey,
  });

  final String label;
  final Key indicatorKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(key: indicatorKey),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }
}

/// Renders the most-recent interaction's in-character `userResponse`. Three
/// treatments: an `exhausted` energy-gate backstop (FR-007) reads as a distinct,
/// tired flavor (its own [Key], a tertiary tint with a tired icon) — never an
/// error; an accepted interaction (every Play and Cure, an accepted Feed) reads
/// as the creature's happy reaction; a Feed *refusal* (`accepted == false`) is
/// styled distinctly — italic, muted — so a "no" never looks like an error.
class _InteractionResponse extends StatelessWidget {
  const _InteractionResponse({required this.outcome});

  final InteractionOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyLarge;

    // Exhausted backstop first: a distinct, in-character "too tired" treatment,
    // visually apart from both the happy and the refusal styles, and never the
    // error red.
    if (outcome.exhausted) {
      return Container(
        key: const Key('exhaustedResponse'),
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.battery_alert,
              color: theme.colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                outcome.userResponse,
                textAlign: TextAlign.center,
                style: base?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final style = outcome.accepted
        ? base
        : base?.copyWith(
            fontStyle: FontStyle.italic,
            color: theme.colorScheme.onSurfaceVariant,
          );

    return Container(
      key: const Key('interactionResponse'),
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: outcome.accepted
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        outcome.userResponse,
        textAlign: TextAlign.center,
        style: style,
      ),
    );
  }
}

/// One labelled stat line, e.g. `Energy  100`. Carries a per-stat `Key`
/// (`statRow-<label>`) so a patrol test can scope to a specific stat row and
/// assert its (dynamic) value changed — text finders alone can't distinguish
/// which stat a number belongs to.
class _StatRow extends StatelessWidget {
  _StatRow({required this.label, required this.value})
    : super(key: Key('statRow-$label'));

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
