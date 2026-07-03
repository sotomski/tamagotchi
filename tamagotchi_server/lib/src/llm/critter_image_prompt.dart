import '../generated/protocol.dart';

/// The volatile, per-birth state handed to the image model to shape one critter.
/// Server-internal (never crosses the RPC boundary), so it is a plain Dart class
/// rather than a Serverpod model — the prompt builder and the
/// `CritterImageService` implementations are its only consumers. The narrative
/// analogue is `InteractionRequest` (`llm_service.dart`).
class CritterImageRequest {
  const CritterImageRequest({
    required this.personality,
    required this.name,
    required this.seed,
  });

  /// The creature's rolled decay/regen modifiers — its disposition, mapped to a
  /// few visual descriptors by [critterVisualHints] so two personalities draw
  /// two different critters.
  final CreaturePersonality personality;

  /// The creature's name, woven into the prompt for flavour.
  final String name;

  /// A per-birth variety seed (supplied by the endpoint's RNG seam) so identical
  /// personalities still produce distinct critters. Drives nothing but the
  /// prompt text — the model is told to make this critter unique.
  final int seed;
}

/// Translates the rolled personality modifiers into a short list of visual
/// descriptors the model can draw from. Pure and unit-testable.
///
/// Each modifier sits in `[0.5, 1.5)` around a 1.0 baseline; we read four
/// visually-meaningful axes (a stat's decay and regen collapse to one look, so
/// using all seven would be redundant) and split each at the baseline. Distinct
/// dispositions therefore yield distinct hint strings — the property the prompt
/// test and the manual spot-check (3.5) rely on.
List<String> critterVisualHints(CreaturePersonality p) {
  return [
    'energy: ${p.energyRegenMod >= 1.0 ? "lively and spiky, alert upright posture" : "sleepy and droopy, soft rounded edges"}',
    'sociability: ${p.loveRegenMod >= 1.0 ? "warm and friendly — round body, big expressive eyes, sunny orange/yellow tones" : "shy and reserved — angular body, small eyes, cool blue/grey tones"}',
    'appetite: ${p.hungerDecayMod >= 1.0 ? "hearty — a round, chunky, plump body" : "dainty — a lean, slender body"}',
    'constitution: ${p.illnessRegenMod >= 1.0 ? "hardy — a vivid, saturated, high-contrast palette" : "delicate — a pale, washed-out, muted palette"}',
  ];
}

/// Builds the single text prompt handed to `gemini-3.1-flash-lite-image` for one
/// birth. Pure and unit-testable — no [Session], no network; the narrative
/// analogue is `buildInteractionMessages` (`creature_prompt.dart`).
///
/// The visual *style* is fixed; the per-creature variation rides in on
/// [critterVisualHints] and the variety [CritterImageRequest.seed], so two
/// personalities — and two births of the same personality — draw two different
/// critters. The prompt test asserts that distinct dispositions yield distinct
/// text and that the pure-white background is requested.
///
/// Two constraints are load-bearing downstream and stated emphatically: the
/// **pure solid white (#FFFFFF) background** and the **single, tightly-cropped
/// creature that fills the frame**. The returned JPEG is stored and rendered
/// as-is — no chroma-key, no crop, no downscale — so anything the model leaves in
/// (shadows, ground, text, a second creature, dead margin) ships straight to the
/// app. Asking hard for a clean, framed sprite on white is the only lever we have.
String buildCritterImagePrompt(CritterImageRequest request) {
  final name = request.name;
  final seed = request.seed;
  final hints = critterVisualHints(request.personality).join('; ');

  return 'Retro 16-bit pixel-art sprite of ONE single cute original little '
      'monster creature named "$name". '
      'Chunky hard-edged pixels, a bold dark outline, and a small limited '
      'colour palette. '
      'The creature FILLS the square frame — its body nearly touches all four '
      'edges, tightly cropped and zoomed in, with only a thin uniform margin. '
      'Background: pure solid white (#FFFFFF), completely flat and empty. '
      'Exactly one creature. No shadow, no ground, no text, no letters, no '
      'border, no frame. '
      'Draw its character from these traits: $hints. '
      'Make this creature unique — variety seed $seed.';
}
