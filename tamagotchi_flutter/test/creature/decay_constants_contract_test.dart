import 'package:flutter_test/flutter_test.dart';
import 'package:tamagotchi_flutter/creature/decay_poll.dart';
import 'package:tamagotchi_flutter/creature/time_scale_provider.dart';

/// Cross-package contract guard. The client mirrors three decay constants that
/// are authoritatively owned by the server (`tamagotchi_server`'s
/// `decay_service.dart`: `MIN_TIME_SCALE`, `MAX_TIME_SCALE`, `TICK_MINUTES`).
/// Dart can't share code across the package boundary, so these values are
/// hand-copied — this test pins the agreed spec so an accidental client-only
/// edit fails loudly instead of silently drifting the slider range / poll
/// cadence away from the server's actual decay behavior. If the server changes
/// a value, update it here *and* in the client constants in the same change.
void main() {
  group('decay constants mirror the server spec', () {
    test('time-scale bounds are 1×–8×', () {
      expect(minTimeScale, 1.0);
      expect(maxTimeScale, 8.0);
    });

    test('one decay tick is 10 game-minutes', () {
      expect(tickMinutes, 10);
    });
  });
}
