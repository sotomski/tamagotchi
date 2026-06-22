// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cure_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives the Cure button: idle → loading → result. Mirrors [PlayController] —
/// curing is deterministic and always available (FR-006), so the outcome always
/// reads as an accepted interaction.
///
/// The initial state is `AsyncData(null)` — no cure attempted yet. A successful
/// cure invalidates [creatureProvider] (the stat rows re-read illness↓) and
/// writes the shared [lastInteractionProvider] with `accepted: true` so the
/// response renders in the shared area. RPC/network failures land in
/// `AsyncError` via [AsyncValue.guard].

@ProviderFor(CureController)
final cureControllerProvider = CureControllerProvider._();

/// Drives the Cure button: idle → loading → result. Mirrors [PlayController] —
/// curing is deterministic and always available (FR-006), so the outcome always
/// reads as an accepted interaction.
///
/// The initial state is `AsyncData(null)` — no cure attempted yet. A successful
/// cure invalidates [creatureProvider] (the stat rows re-read illness↓) and
/// writes the shared [lastInteractionProvider] with `accepted: true` so the
/// response renders in the shared area. RPC/network failures land in
/// `AsyncError` via [AsyncValue.guard].
final class CureControllerProvider
    extends $AsyncNotifierProvider<CureController, CureResult?> {
  /// Drives the Cure button: idle → loading → result. Mirrors [PlayController] —
  /// curing is deterministic and always available (FR-006), so the outcome always
  /// reads as an accepted interaction.
  ///
  /// The initial state is `AsyncData(null)` — no cure attempted yet. A successful
  /// cure invalidates [creatureProvider] (the stat rows re-read illness↓) and
  /// writes the shared [lastInteractionProvider] with `accepted: true` so the
  /// response renders in the shared area. RPC/network failures land in
  /// `AsyncError` via [AsyncValue.guard].
  CureControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cureControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cureControllerHash();

  @$internal
  @override
  CureController create() => CureController();
}

String _$cureControllerHash() => r'7c8c9159e6e2ac12c6d68e95eaa23c1a055e881a';

/// Drives the Cure button: idle → loading → result. Mirrors [PlayController] —
/// curing is deterministic and always available (FR-006), so the outcome always
/// reads as an accepted interaction.
///
/// The initial state is `AsyncData(null)` — no cure attempted yet. A successful
/// cure invalidates [creatureProvider] (the stat rows re-read illness↓) and
/// writes the shared [lastInteractionProvider] with `accepted: true` so the
/// response renders in the shared area. RPC/network failures land in
/// `AsyncError` via [AsyncValue.guard].

abstract class _$CureController extends $AsyncNotifier<CureResult?> {
  FutureOr<CureResult?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<CureResult?>, CureResult?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<CureResult?>, CureResult?>,
              AsyncValue<CureResult?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
