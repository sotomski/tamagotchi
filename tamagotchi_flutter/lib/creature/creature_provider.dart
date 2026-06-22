import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tamagotchi_client/tamagotchi_client.dart';

import '../app/client_provider.dart';
import 'time_scale_provider.dart';

part 'creature_provider.g.dart';

/// The signed-in user's creature with its derived mood, or `null` if they have
/// not hatched yet. The project's first async-data provider — consumed via
/// `AsyncValue.when`, refreshed by invalidation after a successful hatch.
///
/// Watches [timeScaleProvider] so every read carries the current 1×–8× slider
/// value: the server decays proportionally, and moving the slider re-fetches.
@Riverpod(keepAlive: true)
Future<CreatureStatus?> creature(Ref ref) {
  final timeScale = ref.watch(timeScaleProvider);
  return ref
      .read(serverpodClientProvider)
      .creature
      .myCreature(timeScale: timeScale);
}
