import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamagotchi_flutter/creature/creature_provider.dart';
import 'package:tamagotchi_flutter/creature/decay_poll.dart';
import 'package:tamagotchi_flutter/creature/time_scale_provider.dart';

void main() {
  group('pollInterval', () {
    test('is one tick (10 min) of real time at 1×', () {
      expect(pollInterval(minTimeScale), const Duration(minutes: 10));
    });

    test('scales inversely with the slider (8× → 75s)', () {
      expect(pollInterval(maxTimeScale), const Duration(milliseconds: 75000));
    });

    test('a faster scale always polls more often', () {
      expect(pollInterval(8) < pollInterval(1), isTrue);
      expect(pollInterval(4) < pollInterval(2), isTrue);
    });
  });

  test('the poll invalidates creatureProvider once per interval', () {
    fakeAsync((async) {
      var builds = 0;
      final container = ProviderContainer(
        overrides: [
          // Count each (re)build; the override stands in for the real read so the
          // test needs no server.
          creatureProvider.overrideWith((ref) {
            builds++;
            return null;
          }),
        ],
      );

      // Activate the creature read and the poll timer.
      container.listen(creatureProvider, (_, _) {});
      container.listen(decayPollProvider, (_, _) {});
      async.flushMicrotasks();
      expect(builds, 1);

      // One interval at the default 1× (10 min) → exactly one refresh.
      async.elapse(pollInterval(minTimeScale));
      expect(builds, 2);

      async.elapse(pollInterval(minTimeScale));
      expect(builds, 3);

      // Cancel the periodic timer (via the provider's onDispose) before leaving
      // the fake zone.
      container.dispose();
    });
  });
}
