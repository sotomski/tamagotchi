// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'time_scale_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The current 1×–8× time-acceleration the user has dialed in. Held app-wide
/// (`keepAlive`) so the value survives view rebuilds: every creature read and
/// interaction passes it to the server, and [decayPoll] derives its refresh
/// cadence from it. Always clamped to [minTimeScale]–[maxTimeScale].

@ProviderFor(TimeScale)
final timeScaleProvider = TimeScaleProvider._();

/// The current 1×–8× time-acceleration the user has dialed in. Held app-wide
/// (`keepAlive`) so the value survives view rebuilds: every creature read and
/// interaction passes it to the server, and [decayPoll] derives its refresh
/// cadence from it. Always clamped to [minTimeScale]–[maxTimeScale].
final class TimeScaleProvider extends $NotifierProvider<TimeScale, double> {
  /// The current 1×–8× time-acceleration the user has dialed in. Held app-wide
  /// (`keepAlive`) so the value survives view rebuilds: every creature read and
  /// interaction passes it to the server, and [decayPoll] derives its refresh
  /// cadence from it. Always clamped to [minTimeScale]–[maxTimeScale].
  TimeScaleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'timeScaleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$timeScaleHash();

  @$internal
  @override
  TimeScale create() => TimeScale();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }
}

String _$timeScaleHash() => r'6fbe6bd7966a9a081d3e07eebc7f0dc240204f9f';

/// The current 1×–8× time-acceleration the user has dialed in. Held app-wide
/// (`keepAlive`) so the value survives view rebuilds: every creature read and
/// interaction passes it to the server, and [decayPoll] derives its refresh
/// cadence from it. Always clamped to [minTimeScale]–[maxTimeScale].

abstract class _$TimeScale extends $Notifier<double> {
  double build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<double, double>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<double, double>,
              double,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
