import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tamagotchi_client/tamagotchi_client.dart';

import '../app/client_provider.dart';
import 'creature_provider.dart';
import 'last_interaction.dart';
import 'time_scale_provider.dart';

part 'play_controller.g.dart';

/// Drives the Play button: idle → loading → result. Mirrors [FeedController] but
/// playing is deterministic — there is no refusal, so the outcome always reads
/// as an accepted interaction.
///
/// The initial state is `AsyncData(null)` — no play attempted yet. A successful
/// play invalidates [creatureProvider] (the stat rows re-read love↑/energy↓) and
/// writes the shared [lastInteractionProvider] with `accepted: true` so the
/// response renders in the shared area. RPC/network failures land in
/// `AsyncError` via [AsyncValue.guard].
@riverpod
class PlayController extends _$PlayController {
  @override
  FutureOr<PlayResult?> build() => null;

  /// Plays with the creature once, then refreshes [creatureProvider] and
  /// publishes the outcome to the shared response seam.
  Future<void> play() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final timeScale = ref.read(timeScaleProvider);
      final result = await ref
          .read(serverpodClientProvider)
          .creature
          .play(timeScale: timeScale);
      ref.invalidate(creatureProvider);
      ref
          .read(lastInteractionProvider.notifier)
          .set(
            userResponse: result.userResponse,
            // Play never refuses; an exhausted backstop is the only non-accepted
            // outcome, so accepted is the inverse of exhausted.
            accepted: !result.exhausted,
            exhausted: result.exhausted,
          );
      return result;
    });
  }
}
