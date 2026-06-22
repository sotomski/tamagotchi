import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'creature_provider.dart';
import 'time_scale_provider.dart';

part 'decay_poll.g.dart';

/// One server decay tick in game-minutes — mirrors the server's `TICK_MINUTES`
/// (`decay_service.dart`). At 1× the client refreshes once per tick (10 min).
const int tickMinutes = 10;

/// The refresh cadence for a given [scale]: one tick of real time at 1×
/// (10 min), shrinking inversely with the slider (~75 s at 8×) so a faster
/// clock both decays and redraws more often.
Duration pollInterval(double scale) =>
    Duration(milliseconds: (tickMinutes * 60 * 1000 / scale).round());

/// A self-managing poll that invalidates [creatureProvider] every
/// [pollInterval] so live decay becomes visible without a user action.
///
/// Watches [timeScaleProvider]: moving the slider rebuilds this provider, which
/// cancels the old timer (via [Ref.onDispose]) and starts one at the new
/// cadence. Auto-dispose — the timer stops when nothing watches it (the creature
/// view is gone). The existing invalidate-after-interaction behavior is
/// unchanged; this only adds a periodic refresh on top.
@riverpod
void decayPoll(Ref ref) {
  final scale = ref.watch(timeScaleProvider);
  final timer = Timer.periodic(
    pollInterval(scale),
    (_) => ref.invalidate(creatureProvider),
  );
  ref.onDispose(timer.cancel);
}
