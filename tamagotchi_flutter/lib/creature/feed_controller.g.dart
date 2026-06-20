// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives the Feed button: idle → loading → result. Unlike [HatchController],
/// it *keeps* the returned [FeedResult] so the view can render the in-character
/// `userResponse` (and style accepted vs refused differently).
///
/// The initial state is `AsyncData(null)` — no feed attempted yet. A successful
/// feed invalidates [creatureProvider] so the four stat rows re-read the post-
/// feed creature. RPC/network failures land in `AsyncError` via
/// [AsyncValue.guard]; a *refusal* is not an error — it rides
/// `FeedResult.accepted == false` as ordinary data.

@ProviderFor(FeedController)
final feedControllerProvider = FeedControllerProvider._();

/// Drives the Feed button: idle → loading → result. Unlike [HatchController],
/// it *keeps* the returned [FeedResult] so the view can render the in-character
/// `userResponse` (and style accepted vs refused differently).
///
/// The initial state is `AsyncData(null)` — no feed attempted yet. A successful
/// feed invalidates [creatureProvider] so the four stat rows re-read the post-
/// feed creature. RPC/network failures land in `AsyncError` via
/// [AsyncValue.guard]; a *refusal* is not an error — it rides
/// `FeedResult.accepted == false` as ordinary data.
final class FeedControllerProvider
    extends $AsyncNotifierProvider<FeedController, FeedResult?> {
  /// Drives the Feed button: idle → loading → result. Unlike [HatchController],
  /// it *keeps* the returned [FeedResult] so the view can render the in-character
  /// `userResponse` (and style accepted vs refused differently).
  ///
  /// The initial state is `AsyncData(null)` — no feed attempted yet. A successful
  /// feed invalidates [creatureProvider] so the four stat rows re-read the post-
  /// feed creature. RPC/network failures land in `AsyncError` via
  /// [AsyncValue.guard]; a *refusal* is not an error — it rides
  /// `FeedResult.accepted == false` as ordinary data.
  FeedControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'feedControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$feedControllerHash();

  @$internal
  @override
  FeedController create() => FeedController();
}

String _$feedControllerHash() => r'30ddee361f9d4e24b049b52cbc61fd54f769a199';

/// Drives the Feed button: idle → loading → result. Unlike [HatchController],
/// it *keeps* the returned [FeedResult] so the view can render the in-character
/// `userResponse` (and style accepted vs refused differently).
///
/// The initial state is `AsyncData(null)` — no feed attempted yet. A successful
/// feed invalidates [creatureProvider] so the four stat rows re-read the post-
/// feed creature. RPC/network failures land in `AsyncError` via
/// [AsyncValue.guard]; a *refusal* is not an error — it rides
/// `FeedResult.accepted == false` as ordinary data.

abstract class _$FeedController extends $AsyncNotifier<FeedResult?> {
  FutureOr<FeedResult?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<FeedResult?>, FeedResult?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<FeedResult?>, FeedResult?>,
              AsyncValue<FeedResult?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
