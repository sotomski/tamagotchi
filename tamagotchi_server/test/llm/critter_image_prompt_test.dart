import 'package:serverpod/serverpod.dart';
import 'package:tamagotchi_server/src/generated/protocol.dart';
import 'package:tamagotchi_server/src/llm/critter_image_prompt.dart';
import 'package:test/test.dart';

/// A personality with per-axis overrides so a test can flip one disposition and
/// assert the resulting prompt text changes. Defaults sit above the 1.0 baseline
/// (the "warm / lively / hearty / hardy" branches of [critterVisualHints]).
CreaturePersonality _personality({
  double energyRegenMod = 1.2,
  double loveRegenMod = 1.3,
  double hungerDecayMod = 1.1,
  double illnessRegenMod = 1.4,
}) => CreaturePersonality(
  creatureId: UuidValue.fromString('00000000-0000-7000-8000-000000000000'),
  hungerDecayMod: hungerDecayMod,
  hungerRegenMod: 1.0,
  energyDecayMod: 1.0,
  energyRegenMod: energyRegenMod,
  loveRegenMod: loveRegenMod,
  illnessDecayMod: 1.0,
  illnessRegenMod: illnessRegenMod,
);

void main() {
  group('critterVisualHints', () {
    // Oracle = the plan's Phase 2 contract: distinct dispositions map to distinct
    // visual descriptors (the property the prompt variety leans on).
    test('opposite dispositions yield distinct hint strings', () {
      final lively = critterVisualHints(_personality(energyRegenMod: 1.4));
      final sleepy = critterVisualHints(_personality(energyRegenMod: 0.6));
      expect(lively, isNot(sleepy));
    });
  });

  group('buildCritterImagePrompt', () {
    test('asks for a pixel-art sprite on a pure solid-white background', () {
      final prompt = buildCritterImagePrompt(
        CritterImageRequest(
          personality: _personality(),
          name: 'Nibbles',
          seed: 7,
        ),
      );
      final lower = prompt.toLowerCase();

      expect(lower, contains('pixel'));
      // The pure-white background is load-bearing: the JPEG is stored/rendered
      // as-is, so the request must pin #FFFFFF explicitly.
      expect(prompt, contains('#FFFFFF'));
      expect(lower, contains('white'));
      // One creature only, filling the frame.
      expect(lower, anyOf(contains('one single'), contains('single')));
      expect(lower, contains('fills the square frame'.toLowerCase()));
    });

    test('weaves the name, the variety seed, and the personality hints', () {
      final prompt = buildCritterImagePrompt(
        CritterImageRequest(
          personality: _personality(loveRegenMod: 1.3),
          name: 'Wobblesworth',
          seed: 12345,
        ),
      );

      expect(prompt, contains('Wobblesworth'));
      expect(prompt, contains('12345'));
      // A personality hint substring is present (the sociability "warm" branch).
      expect(prompt.toLowerCase(), contains('warm'));
    });

    test('distinct personalities produce distinct prompt text', () {
      CritterImageRequest reqWith(double loveRegenMod) => CritterImageRequest(
        personality: _personality(loveRegenMod: loveRegenMod),
        name: 'Same',
        seed: 1,
      );

      final warm = buildCritterImagePrompt(reqWith(1.3));
      final shy = buildCritterImagePrompt(reqWith(0.6));
      expect(warm, isNot(shy));
    });
  });
}
