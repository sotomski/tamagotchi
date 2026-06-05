// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hatch_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives the Hatch button: idle → loading → result. On success it invalidates
/// [creatureProvider] so the freshly hatched creature replaces the empty state.
///
/// Failures (notably `CreatureHatchError`) are captured into the `AsyncError`
/// state via [AsyncValue.guard] for the form to render inline.

@ProviderFor(HatchController)
final hatchControllerProvider = HatchControllerProvider._();

/// Drives the Hatch button: idle → loading → result. On success it invalidates
/// [creatureProvider] so the freshly hatched creature replaces the empty state.
///
/// Failures (notably `CreatureHatchError`) are captured into the `AsyncError`
/// state via [AsyncValue.guard] for the form to render inline.
final class HatchControllerProvider
    extends $AsyncNotifierProvider<HatchController, void> {
  /// Drives the Hatch button: idle → loading → result. On success it invalidates
  /// [creatureProvider] so the freshly hatched creature replaces the empty state.
  ///
  /// Failures (notably `CreatureHatchError`) are captured into the `AsyncError`
  /// state via [AsyncValue.guard] for the form to render inline.
  HatchControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hatchControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hatchControllerHash();

  @$internal
  @override
  HatchController create() => HatchController();
}

String _$hatchControllerHash() => r'3374b655cde4428cf1a2f3327acd56bb66fbb9aa';

/// Drives the Hatch button: idle → loading → result. On success it invalidates
/// [creatureProvider] so the freshly hatched creature replaces the empty state.
///
/// Failures (notably `CreatureHatchError`) are captured into the `AsyncError`
/// state via [AsyncValue.guard] for the form to render inline.

abstract class _$HatchController extends $AsyncNotifier<void> {
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
