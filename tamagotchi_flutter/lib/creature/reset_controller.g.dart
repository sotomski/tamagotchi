// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reset_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives the Reset action: idle → loading → result. On success it deletes the
/// user's creature server-side (cascading to its journal + personality) and
/// invalidates [creatureProvider] so the empty-state [HatchForm] takes over.
///
/// [lastInteractionProvider] is invalidated too, so a stale Feed/Play response
/// from the deleted creature can't linger into the next one. Failures are
/// captured into the `AsyncError` state via [AsyncValue.guard]. Mirrors
/// [HatchController]; the result type is `void` (reset returns nothing).

@ProviderFor(ResetController)
final resetControllerProvider = ResetControllerProvider._();

/// Drives the Reset action: idle → loading → result. On success it deletes the
/// user's creature server-side (cascading to its journal + personality) and
/// invalidates [creatureProvider] so the empty-state [HatchForm] takes over.
///
/// [lastInteractionProvider] is invalidated too, so a stale Feed/Play response
/// from the deleted creature can't linger into the next one. Failures are
/// captured into the `AsyncError` state via [AsyncValue.guard]. Mirrors
/// [HatchController]; the result type is `void` (reset returns nothing).
final class ResetControllerProvider
    extends $AsyncNotifierProvider<ResetController, void> {
  /// Drives the Reset action: idle → loading → result. On success it deletes the
  /// user's creature server-side (cascading to its journal + personality) and
  /// invalidates [creatureProvider] so the empty-state [HatchForm] takes over.
  ///
  /// [lastInteractionProvider] is invalidated too, so a stale Feed/Play response
  /// from the deleted creature can't linger into the next one. Failures are
  /// captured into the `AsyncError` state via [AsyncValue.guard]. Mirrors
  /// [HatchController]; the result type is `void` (reset returns nothing).
  ResetControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'resetControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$resetControllerHash();

  @$internal
  @override
  ResetController create() => ResetController();
}

String _$resetControllerHash() => r'7032d202c9666cc2e3c7ab16b7cc354cd6eba97f';

/// Drives the Reset action: idle → loading → result. On success it deletes the
/// user's creature server-side (cascading to its journal + personality) and
/// invalidates [creatureProvider] so the empty-state [HatchForm] takes over.
///
/// [lastInteractionProvider] is invalidated too, so a stale Feed/Play response
/// from the deleted creature can't linger into the next one. Failures are
/// captured into the `AsyncError` state via [AsyncValue.guard]. Mirrors
/// [HatchController]; the result type is `void` (reset returns nothing).

abstract class _$ResetController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
