// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'decay_poll.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A self-managing poll that invalidates [creatureProvider] every
/// [pollInterval] so live decay becomes visible without a user action.
///
/// Watches [timeScaleProvider]: moving the slider rebuilds this provider, which
/// cancels the old timer (via [Ref.onDispose]) and starts one at the new
/// cadence. Auto-dispose — the timer stops when nothing watches it (the creature
/// view is gone). The existing invalidate-after-interaction behavior is
/// unchanged; this only adds a periodic refresh on top.

@ProviderFor(decayPoll)
final decayPollProvider = DecayPollProvider._();

/// A self-managing poll that invalidates [creatureProvider] every
/// [pollInterval] so live decay becomes visible without a user action.
///
/// Watches [timeScaleProvider]: moving the slider rebuilds this provider, which
/// cancels the old timer (via [Ref.onDispose]) and starts one at the new
/// cadence. Auto-dispose — the timer stops when nothing watches it (the creature
/// view is gone). The existing invalidate-after-interaction behavior is
/// unchanged; this only adds a periodic refresh on top.

final class DecayPollProvider extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// A self-managing poll that invalidates [creatureProvider] every
  /// [pollInterval] so live decay becomes visible without a user action.
  ///
  /// Watches [timeScaleProvider]: moving the slider rebuilds this provider, which
  /// cancels the old timer (via [Ref.onDispose]) and starts one at the new
  /// cadence. Auto-dispose — the timer stops when nothing watches it (the creature
  /// view is gone). The existing invalidate-after-interaction behavior is
  /// unchanged; this only adds a periodic refresh on top.
  DecayPollProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'decayPollProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$decayPollHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return decayPoll(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$decayPollHash() => r'd0375bd678e87224e677f22978c1353454ffb486';
