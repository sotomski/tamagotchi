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
