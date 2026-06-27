import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../app/client_provider.dart';
import 'creature_provider.dart';
import 'journal_provider.dart';
import 'last_interaction.dart';

part 'reset_controller.g.dart';

/// Drives the Reset action: idle → loading → result. On success it deletes the
/// user's creature server-side (cascading to its journal + personality) and
/// invalidates [creatureProvider] so the empty-state [HatchForm] takes over.
///
/// [lastInteractionProvider] is invalidated too, so a stale Feed/Play response
/// from the deleted creature can't linger into the next one. Failures are
/// captured into the `AsyncError` state via [AsyncValue.guard]. Mirrors
/// [HatchController]; the result type is `void` (reset returns nothing).
@riverpod
class ResetController extends _$ResetController {
  @override
  FutureOr<void> build() {}

  /// Deletes the user's creature, then refreshes [creatureProvider].
  Future<void> reset() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(serverpodClientProvider).creature.reset();
      ref.invalidate(creatureProvider);
      ref.invalidate(lastInteractionProvider);
      // The deleted creature's journal must not linger into the next one.
      ref.invalidate(journalProvider);
    });
  }
}
