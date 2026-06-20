import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tamagotchi_client/tamagotchi_client.dart';

import '../app/client_provider.dart';
import 'creature_provider.dart';
import 'last_interaction.dart';

part 'feed_controller.g.dart';

/// Drives the Feed button: idle → loading → result. Unlike [HatchController],
/// it *keeps* the returned [FeedResult] so the view can render the in-character
/// `userResponse` (and style accepted vs refused differently).
///
/// The initial state is `AsyncData(null)` — no feed attempted yet. A successful
/// feed invalidates [creatureProvider] so the four stat rows re-read the post-
/// feed creature. RPC/network failures land in `AsyncError` via
/// [AsyncValue.guard]; a *refusal* is not an error — it rides
/// `FeedResult.accepted == false` as ordinary data.
@riverpod
class FeedController extends _$FeedController {
  @override
  FutureOr<FeedResult?> build() => null;

  /// Feeds the creature once, then refreshes [creatureProvider].
  Future<void> feed() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await ref.read(serverpodClientProvider).creature.feed();
      ref.invalidate(creatureProvider);
      ref
          .read(lastInteractionProvider.notifier)
          .set(userResponse: result.userResponse, accepted: result.accepted);
      return result;
    });
  }
}
