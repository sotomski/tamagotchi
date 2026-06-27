import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tamagotchi_client/tamagotchi_client.dart';

import '../app/client_provider.dart';
import 'creature_provider.dart';
import 'journal_provider.dart';
import 'last_interaction.dart';
import 'time_scale_provider.dart';

part 'cure_controller.g.dart';

/// Drives the Cure button: idle → loading → result. Mirrors [PlayController] —
/// curing is deterministic and always available (FR-006), so the outcome always
/// reads as an accepted interaction.
///
/// The initial state is `AsyncData(null)` — no cure attempted yet. A successful
/// cure invalidates [creatureProvider] (the stat rows re-read illness↓) and
/// writes the shared [lastInteractionProvider] with `accepted: true` so the
/// response renders in the shared area. RPC/network failures land in
/// `AsyncError` via [AsyncValue.guard].
@riverpod
class CureController extends _$CureController {
  @override
  FutureOr<CureResult?> build() => null;

  /// Cures the creature once, then refreshes [creatureProvider] and publishes
  /// the outcome to the shared response seam.
  Future<void> cure() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final timeScale = ref.read(timeScaleProvider);
      final result = await ref
          .read(serverpodClientProvider)
          .creature
          .cure(timeScale: timeScale);
      ref.invalidate(creatureProvider);
      // The interaction wrote a journal entry — refresh the embedded journal.
      ref.invalidate(journalProvider);
      ref
          .read(lastInteractionProvider.notifier)
          // Cure is always available (FR-006) and never energy-gated.
          .set(
            userResponse: result.userResponse,
            accepted: true,
            exhausted: false,
          );
      return result;
    });
  }
}
