// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'creature_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The signed-in user's creature with its derived mood, or `null` if they have
/// not hatched yet. The project's first async-data provider — consumed via
/// `AsyncValue.when`, refreshed by invalidation after a successful hatch.
///
/// Watches [timeScaleProvider] so every read carries the current 1×–8× slider
/// value: the server decays proportionally, and moving the slider re-fetches.

@ProviderFor(creature)
final creatureProvider = CreatureProvider._();

/// The signed-in user's creature with its derived mood, or `null` if they have
/// not hatched yet. The project's first async-data provider — consumed via
/// `AsyncValue.when`, refreshed by invalidation after a successful hatch.
///
/// Watches [timeScaleProvider] so every read carries the current 1×–8× slider
/// value: the server decays proportionally, and moving the slider re-fetches.

final class CreatureProvider
    extends
        $FunctionalProvider<
          AsyncValue<CreatureStatus?>,
          CreatureStatus?,
          FutureOr<CreatureStatus?>
        >
    with $FutureModifier<CreatureStatus?>, $FutureProvider<CreatureStatus?> {
  /// The signed-in user's creature with its derived mood, or `null` if they have
  /// not hatched yet. The project's first async-data provider — consumed via
  /// `AsyncValue.when`, refreshed by invalidation after a successful hatch.
  ///
  /// Watches [timeScaleProvider] so every read carries the current 1×–8× slider
  /// value: the server decays proportionally, and moving the slider re-fetches.
  CreatureProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'creatureProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$creatureHash();

  @$internal
  @override
  $FutureProviderElement<CreatureStatus?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CreatureStatus?> create(Ref ref) {
    return creature(ref);
  }
}

String _$creatureHash() => r'4b1ff2a6ac4b115d380418fa49feb91d886a2080';
