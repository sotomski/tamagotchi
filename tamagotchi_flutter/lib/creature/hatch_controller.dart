import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../app/client_provider.dart';
import 'creature_provider.dart';

part 'hatch_controller.g.dart';

/// Drives the Hatch button: idle → loading → result. On success it invalidates
/// [creatureProvider] so the freshly hatched creature replaces the empty state.
///
/// Failures (notably `CreatureHatchError`) are captured into the `AsyncError`
/// state via [AsyncValue.guard] for the form to render inline.
@riverpod
class HatchController extends _$HatchController {
  @override
  FutureOr<void> build() {}

  /// Hatches a creature named [name], then refreshes [creatureProvider].
  Future<void> hatch(String name) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(serverpodClientProvider).creature.hatch(name);
      ref.invalidate(creatureProvider);
    });
  }
}
