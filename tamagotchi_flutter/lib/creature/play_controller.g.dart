// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'play_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives the Play button: idle → loading → result. Mirrors [FeedController] but
/// playing is deterministic — there is no refusal, so the outcome always reads
/// as an accepted interaction.
///
/// The initial state is `AsyncData(null)` — no play attempted yet. A successful
/// play invalidates [creatureProvider] (the stat rows re-read love↑/energy↓) and
/// writes the shared [lastInteractionProvider] with `accepted: true` so the
/// response renders in the shared area. RPC/network failures land in
/// `AsyncError` via [AsyncValue.guard].

@ProviderFor(PlayController)
final playControllerProvider = PlayControllerProvider._();

/// Drives the Play button: idle → loading → result. Mirrors [FeedController] but
/// playing is deterministic — there is no refusal, so the outcome always reads
/// as an accepted interaction.
///
/// The initial state is `AsyncData(null)` — no play attempted yet. A successful
/// play invalidates [creatureProvider] (the stat rows re-read love↑/energy↓) and
/// writes the shared [lastInteractionProvider] with `accepted: true` so the
/// response renders in the shared area. RPC/network failures land in
/// `AsyncError` via [AsyncValue.guard].
final class PlayControllerProvider
    extends $AsyncNotifierProvider<PlayController, PlayResult?> {
  /// Drives the Play button: idle → loading → result. Mirrors [FeedController] but
  /// playing is deterministic — there is no refusal, so the outcome always reads
  /// as an accepted interaction.
  ///
  /// The initial state is `AsyncData(null)` — no play attempted yet. A successful
  /// play invalidates [creatureProvider] (the stat rows re-read love↑/energy↓) and
  /// writes the shared [lastInteractionProvider] with `accepted: true` so the
  /// response renders in the shared area. RPC/network failures land in
  /// `AsyncError` via [AsyncValue.guard].
  PlayControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playControllerHash();

  @$internal
  @override
  PlayController create() => PlayController();
}

String _$playControllerHash() => r'c4836b38775f83230fe42d7526e7bae170641b4b';

/// Drives the Play button: idle → loading → result. Mirrors [FeedController] but
/// playing is deterministic — there is no refusal, so the outcome always reads
/// as an accepted interaction.
///
/// The initial state is `AsyncData(null)` — no play attempted yet. A successful
/// play invalidates [creatureProvider] (the stat rows re-read love↑/energy↓) and
/// writes the shared [lastInteractionProvider] with `accepted: true` so the
/// response renders in the shared area. RPC/network failures land in
/// `AsyncError` via [AsyncValue.guard].

abstract class _$PlayController extends $AsyncNotifier<PlayResult?> {
  FutureOr<PlayResult?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<PlayResult?>, PlayResult?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PlayResult?>, PlayResult?>,
              AsyncValue<PlayResult?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
