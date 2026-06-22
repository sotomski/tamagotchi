import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'time_scale_provider.g.dart';

/// Bounds of the client time-acceleration slider, mirroring the server's
/// `MIN_TIME_SCALE` / `MAX_TIME_SCALE` (`decay_service.dart`). 1× is real time;
/// 8× compresses both how fast the server decays stats and how often the client
/// refreshes.
const double minTimeScale = 1.0;
const double maxTimeScale = 8.0;

/// The current 1×–8× time-acceleration the user has dialed in. Held app-wide
/// (`keepAlive`) so the value survives view rebuilds: every creature read and
/// interaction passes it to the server, and [decayPoll] derives its refresh
/// cadence from it. Always clamped to [minTimeScale]–[maxTimeScale].
@Riverpod(keepAlive: true)
class TimeScale extends _$TimeScale {
  @override
  double build() => minTimeScale;

  /// Sets the slider value, clamped to the supported range.
  void set(double value) {
    state = value.clamp(minTimeScale, maxTimeScale);
  }
}
