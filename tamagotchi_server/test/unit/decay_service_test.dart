import 'package:serverpod/serverpod.dart';
import 'package:tamagotchi_server/src/creature/decay_service.dart';
import 'package:tamagotchi_server/src/generated/protocol.dart';
import 'package:test/test.dart';

const _ownerUuid = '00000000-0000-0000-0000-000000000001';
const _creatureId = '00000000-0000-0000-0000-000000000002';

/// A fixed UTC reference instant so every elapsed window is exact and the math
/// is reproducible (the pure fn takes `now` directly — no clock seam here).
final _now = DateTime.utc(2026, 6, 21, 12);

/// A creature whose `lastDecayedAt` sits [minutesAgo] before [_now]; the volatile
/// stats are caller-chosen, the rest are placeholders the decay math never reads.
Creature _creature({
  required int minutesAgo,
  int hunger = 0,
  int energy = 50,
  int love = 50,
  int illness = 30,
}) => Creature(
  id: UuidValue.fromString(_creatureId),
  ownerUuid: UuidValue.fromString(_ownerUuid),
  name: 'Testy',
  hunger: hunger,
  energy: energy,
  love: love,
  illness: illness,
  hatchedAt: _now.subtract(Duration(minutes: minutesAgo)),
  lastDecayedAt: _now.subtract(Duration(minutes: minutesAgo)),
);

/// A personality with the three mods decay reads (`hungerDecayMod`,
/// `energyRegenMod`, `loveRegenMod`); the other four are inert here.
CreaturePersonality _personality({
  double hungerDecayMod = 1.0,
  double energyRegenMod = 1.0,
  double loveRegenMod = 1.0,
}) => CreaturePersonality(
  creatureId: UuidValue.fromString(_creatureId),
  hungerDecayMod: hungerDecayMod,
  hungerRegenMod: 1.0,
  energyDecayMod: 1.0,
  energyRegenMod: energyRegenMod,
  loveRegenMod: loveRegenMod,
  illnessDecayMod: 1.0,
  illnessRegenMod: 1.0,
);

void main() {
  group('decayCreature', () {
    test('zero elapsed leaves stats and anchor untouched, changed=false', () {
      final c = _creature(minutesAgo: 0);
      final r = decayCreature(
        creature: c,
        personality: _personality(),
        now: _now,
        timeScale: 1.0,
      );
      expect(r.changed, isFalse);
      expect(identical(r.creature, c), isTrue);
    });

    test('sub-tick elapsed (<10 game-min) is a no-op, anchor untouched', () {
      // 5 real-min × 1× = 5 game-min < TICK_MINUTES (10) ⇒ 0 ticks.
      final c = _creature(minutesAgo: 5);
      final r = decayCreature(
        creature: c,
        personality: _personality(),
        now: _now,
        timeScale: 1.0,
      );
      expect(r.changed, isFalse);
      expect(r.creature.lastDecayedAt, c.lastDecayedAt);
    });

    test('N whole ticks apply exact baseline deltas; illness never moves', () {
      // 60 game-min ⇒ 6 ticks. hunger +6×2=12, energy +6×1=6, love −6×1=6.
      final r = decayCreature(
        creature: _creature(
          minutesAgo: 60,
          hunger: 0,
          energy: 50,
          love: 50,
          illness: 30,
        ),
        personality: _personality(),
        now: _now,
        timeScale: 1.0,
      );
      expect(r.changed, isTrue);
      expect(r.creature.hunger, 12);
      expect(r.creature.energy, 56);
      expect(r.creature.love, 44);
      expect(r.creature.illness, 30);
    });

    test(
      'anchor advances only by the whole ticks consumed, leaving remainder',
      () {
        // 25 game-min ⇒ 2 ticks = 20 min consumed; 5-min remainder stays.
        final c = _creature(minutesAgo: 25);
        final r = decayCreature(
          creature: c,
          personality: _personality(),
          now: _now,
          timeScale: 1.0,
        );
        expect(r.changed, isTrue);
        expect(
          r.creature.lastDecayedAt,
          c.lastDecayedAt.add(const Duration(minutes: 20)),
        );
        // Remainder preserved: the new anchor is 5 minutes shy of `now`.
        expect(
          r.creature.lastDecayedAt,
          _now.subtract(const Duration(minutes: 5)),
        );
      },
    );

    test(
      'love is floored at LOVE_FLOOR (20) and never raised from below it',
      () {
        // 60 game-min ⇒ 6 ticks ⇒ love −6. From 22 → floored at 20 (not 16).
        final floored = decayCreature(
          creature: _creature(minutesAgo: 60, love: 22),
          personality: _personality(),
          now: _now,
          timeScale: 1.0,
        );
        expect(floored.creature.love, 20);

        // Already below the floor: decay must not lift it up to 20.
        final below = decayCreature(
          creature: _creature(minutesAgo: 60, love: 10),
          personality: _personality(),
          now: _now,
          timeScale: 1.0,
        );
        expect(below.creature.love, 10);
      },
    );

    test('energy regen is capped at 100', () {
      // 60 game-min ⇒ 6 ticks ⇒ energy +6. From 98 → capped at 100 (not 104).
      final r = decayCreature(
        creature: _creature(minutesAgo: 60, energy: 98),
        personality: _personality(),
        now: _now,
        timeScale: 1.0,
      );
      expect(r.creature.energy, 100);
    });

    test('timeScale multiplies the effective elapsed time (more ticks)', () {
      // 5 real-min × 8× = 40 game-min ⇒ 4 ticks ⇒ hunger +4×2=8.
      final r = decayCreature(
        creature: _creature(minutesAgo: 5, hunger: 0),
        personality: _personality(),
        now: _now,
        timeScale: 8.0,
      );
      expect(r.changed, isTrue);
      expect(r.creature.hunger, 8);
    });

    test('personality mods scale the per-tick magnitude', () {
      // 6 ticks. hungerDecayMod 1.5 ⇒ hunger +round(6×2×1.5)=18, vs 12 at 1.0.
      final fast = decayCreature(
        creature: _creature(minutesAgo: 60, hunger: 0),
        personality: _personality(hungerDecayMod: 1.5),
        now: _now,
        timeScale: 1.0,
      );
      expect(fast.creature.hunger, 18);
      expect(fast.creature.hunger, greaterThan(12));
    });

    test('identical inputs produce identical outputs (determinism)', () {
      Creature run() => decayCreature(
        creature: _creature(minutesAgo: 60),
        personality: _personality(),
        now: _now,
        timeScale: 1.0,
      ).creature;
      final a = run();
      final b = run();
      expect(a.hunger, b.hunger);
      expect(a.energy, b.energy);
      expect(a.love, b.love);
      expect(a.illness, b.illness);
      expect(a.lastDecayedAt, b.lastDecayedAt);
    });
  });

  group('clampTimeScale', () {
    test('passes through an in-range scale unchanged', () {
      expect(clampTimeScale(3.5), 3.5);
    });
    test('clamps below MIN_TIME_SCALE up to 1.0', () {
      expect(clampTimeScale(0.2), 1.0);
    });
    test('clamps above MAX_TIME_SCALE down to 8.0', () {
      expect(clampTimeScale(99.0), 8.0);
    });
  });
}
