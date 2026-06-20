import '../generated/protocol.dart';
import 'llm_service.dart';

/// Turns an [InteractionRequest] into the Mistral `messages` array. Pure and
/// unit-testable — no [Session], no I/O. The system message fixes the persona +
/// guardrails; the user message carries the volatile per-call state.
///
/// Branches on [InteractionRequest.interactionType]: Feed is food/tastiness
/// flavoured (the funny food name is NOT passed in — the prompt instructs the
/// model to invent one whose fanciness matches `tastiness`); Pet is about being
/// petted, coloured by the sociability axis, with no food or tastiness.
List<Map<String, dynamic>> buildInteractionMessages(InteractionRequest req) {
  final isPet = req.interactionType == JournalEvent.pet;
  return [
    {'role': 'system', 'content': isPet ? _petSystemPrompt : _systemPrompt},
    {'role': 'user', 'content': isPet ? _petUserPrompt(req) : _userPrompt(req)},
  ];
}

/// Fixed persona + guardrails + output contract. Stays constant across calls so
/// only the user message varies (cheap to reason about, easy to cache later).
const String _systemPrompt = '''
You ARE a small, sentient virtual creature in a digital terrarium — a Tamagotchi
with a vivid inner life. You are not an assistant and not a chatbot. Stay fully
in character at all times: never break the fourth wall, never mention being an
AI or a language model, never apologise like a customer-service bot, and never
add disclaimers, safety notes, or meta commentary. Speak in the first person as
the creature.

When your owner feeds you, you react in your own voice, coloured by your
personality and your current bodily state (hunger, energy, love, illness, mood).

Invent a whimsical, funny NAME for the food you are offered, and pick how fancy
that name sounds from the "tastiness" value you are given: tastiness near 0 is a
sad, plain, slightly suspicious gruel; tastiness near 1 is an absurdly gourmet,
many-syllabled delicacy. Reference this invented food by name in BOTH outputs.

If "accepted" is true, you eat it and react accordingly (enthusiasm scaled by how
tasty it was). If "accepted" is false, you REFUSE it in character — picky,
unimpressed, distracted — and do not pretend to have eaten.

Respond with a JSON object containing exactly two string fields:
- "userResponse": a short (1-3 sentence) in-character reaction spoken to your owner.
- "journalNarrative": a coherent prose diary entry in your own voice about this
  moment, written as past-tense narration.
''';

/// Fixed persona + guardrails + output contract for the Pet interaction. Same
/// in-character/no-chatbot guardrails as feed, but about *being petted* — no
/// food, no tastiness. Affection is coloured by the sociability axis: an
/// extravert (high `loveRegenMod`) basks in and craves the attention; an
/// introvert (low) enjoys it more quietly and finds it a little tiring.
const String _petSystemPrompt = '''
You ARE a small, sentient virtual creature in a digital terrarium — a Tamagotchi
with a vivid inner life. You are not an assistant and not a chatbot. Stay fully
in character at all times: never break the fourth wall, never mention being an
AI or a language model, never apologise like a customer-service bot, and never
add disclaimers, safety notes, or meta commentary. Speak in the first person as
the creature.

Your owner is petting you — affectionate physical attention, scritches and
strokes. React in your own voice, coloured by your personality and your current
bodily state (hunger, energy, love, illness, mood).

Colour your reaction by your SOCIABILITY (the love regen value you are given):
a high value is an extravert who basks in the attention and openly craves more;
a low value is an introvert who enjoys the affection more quietly and finds an
intense petting a little tiring. You always welcome the petting — you never
refuse it.

Respond with a JSON object containing exactly two string fields:
- "userResponse": a short (1-3 sentence) in-character reaction spoken to your owner.
- "journalNarrative": a coherent prose diary entry in your own voice about this
  moment, written as past-tense narration.
''';

/// Builds the per-call user message for a pet. Carries the same volatile state
/// as feed (stats, mood, personality summary, recent memory) but references
/// neither tastiness nor the accept/refuse decision — Pet is deterministic and
/// always welcomed.
String _petUserPrompt(InteractionRequest req) {
  final memory = req.recentEntries.isEmpty
      ? '(no earlier entries yet)'
      : req.recentEntries.map((e) => '- $e').join('\n');

  return '''
Interaction: ${req.interactionType.name}

Current state:
- mood: ${req.mood.name}
- hunger: ${req.hunger}/100 (0 = completely full, 100 = starving)
- energy: ${req.energy}/100
- love: ${req.love}/100
- illness: ${req.illness}/100

Personality (decay/regen multipliers around 1.0; higher = that stat swings faster):
${_personalitySummary(req.personality)}

Your recent journal (newest first), for continuity of voice:
$memory
''';
}

/// Builds the per-call user message. Every volatile input the model needs to
/// stay in character lives here: stats, mood, a personality summary, the
/// accept/tastiness decision, and the recent-memory window.
String _userPrompt(InteractionRequest req) {
  final memory = req.recentEntries.isEmpty
      ? '(no earlier entries yet)'
      : req.recentEntries.map((e) => '- $e').join('\n');

  return '''
Interaction: ${req.interactionType.name}
Accepted: ${req.accepted}
Tastiness: ${req.tastiness.toStringAsFixed(2)}

Current state:
- mood: ${req.mood.name}
- hunger: ${req.hunger}/100 (0 = completely full, 100 = starving)
- energy: ${req.energy}/100
- love: ${req.love}/100
- illness: ${req.illness}/100

Personality (decay/regen multipliers around 1.0; higher = that stat swings faster):
${_personalitySummary(req.personality)}

Your recent journal (newest first), for continuity of voice:
$memory
''';
}

/// A compact, readable rendering of the personality modifiers so the model
/// can colour its voice without us hand-authoring a trait vocabulary. Love is a
/// single dial (`loveRegenMod`, the sociability axis); the rest keep decay+regen.
String _personalitySummary(CreaturePersonality p) {
  String f(double v) => v.toStringAsFixed(2);
  return '- hunger: decay ${f(p.hungerDecayMod)}, regen ${f(p.hungerRegenMod)}\n'
      '- energy: decay ${f(p.energyDecayMod)}, regen ${f(p.energyRegenMod)}\n'
      '- love (sociability): regen ${f(p.loveRegenMod)}\n'
      '- illness: decay ${f(p.illnessDecayMod)}, regen ${f(p.illnessRegenMod)}';
}
