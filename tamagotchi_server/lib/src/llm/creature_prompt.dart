import '../generated/protocol.dart';
import 'llm_service.dart';

/// Turns an [InteractionRequest] into the Mistral `messages` array. Pure and
/// unit-testable — no [Session], no I/O. The system message fixes the persona +
/// guardrails; the user message carries the volatile per-call state.
///
/// The funny food name is NOT passed in: the system prompt instructs the model
/// to invent one whose fanciness matches `tastiness` and reference it in both
/// outputs, so the name surfaces inside the prose rather than as a field.
List<Map<String, dynamic>> buildInteractionMessages(InteractionRequest req) {
  return [
    {'role': 'system', 'content': _systemPrompt},
    {'role': 'user', 'content': _userPrompt(req)},
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

/// A compact, readable rendering of the eight personality modifiers so the model
/// can colour its voice without us hand-authoring a trait vocabulary.
String _personalitySummary(CreaturePersonality p) {
  String f(double v) => v.toStringAsFixed(2);
  return '- hunger: decay ${f(p.hungerDecayMod)}, regen ${f(p.hungerRegenMod)}\n'
      '- energy: decay ${f(p.energyDecayMod)}, regen ${f(p.energyRegenMod)}\n'
      '- love: decay ${f(p.loveDecayMod)}, regen ${f(p.loveRegenMod)}\n'
      '- illness: decay ${f(p.illnessDecayMod)}, regen ${f(p.illnessRegenMod)}';
}
