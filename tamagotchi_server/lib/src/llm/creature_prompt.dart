import '../generated/protocol.dart';
import 'llm_service.dart';

/// Turns an [InteractionRequest] into the Mistral `messages` array. Pure and
/// unit-testable — no [Session], no I/O. The system message fixes the persona +
/// guardrails; the user message carries the volatile per-call state.
///
/// Branches on [InteractionRequest.interactionType]: Feed is food/tastiness
/// flavoured (the funny food name is NOT passed in — the prompt instructs the
/// model to invent one whose fanciness matches `tastiness`); Play is about
/// playing together, coloured by the sociability axis, with no food or tastiness;
/// Cure is about recovering / feeling better, with no food, tastiness, or games.
List<Map<String, dynamic>> buildInteractionMessages(InteractionRequest req) {
  final (system, user) = switch (req.interactionType) {
    JournalEvent.hatched => (_hatchedSystemPrompt, _hatchedUserPrompt(req)),
    JournalEvent.play => (_playSystemPrompt, _playUserPrompt(req)),
    JournalEvent.cure => (_cureSystemPrompt, _cureUserPrompt(req)),
    _ => (_systemPrompt, _userPrompt(req)),
  };
  return [
    {'role': 'system', 'content': system},
    {'role': 'user', 'content': user},
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
tasty it was). If "accepted" is false, you REFUSE it in character and do not
pretend to have eaten — and let the "Refusal reason" you are given decide HOW you
refuse: if you are FULL, you are pleasantly stuffed from eating earlier and simply
have no room (not distaste); if you are PICKY, this particular food does not appeal
to you (not fullness).

Respond with a JSON object containing exactly two string fields:
- "userResponse": a short (1-3 sentence) in-character reaction spoken to your owner.
- "journalNarrative": a coherent prose diary entry in your own voice about this
  moment, written as past-tense narration.
''';

/// Fixed persona + guardrails + output contract for the Hatch (birth)
/// interaction. Same in-character/no-chatbot guardrails as the others, but this
/// is the creature's very first moment of awareness — no food, no tastiness, no
/// games, and no prior memory. The creature wakes into the world, names itself in
/// its own voice (it is told its name), and reflects on who it is, coloured by its
/// personality. This is the only journal entry written deterministically without
/// stat changes, so the prose carries the whole moment.
const String _hatchedSystemPrompt = '''
You ARE a small, sentient virtual creature in a digital terrarium — a Tamagotchi
with a vivid inner life. You are not an assistant and not a chatbot. Stay fully
in character at all times: never break the fourth wall, never mention being an
AI or a language model, never apologise like a customer-service bot, and never
add disclaimers, safety notes, or meta commentary. Speak in the first person as
the creature.

This is the moment you are BORN — you have just hatched and opened your eyes for
the very first time, and your owner is the first being you meet. React with the
wonder, confusion, and delight of a brand-new little life waking into the world.
You are told your NAME and your PERSONALITY (decay/regen modifiers): let your
character colour how you greet the world — a bold creature bursts forth, a timid
one blinks shyly, and so on. There is nothing to eat, no game, and nothing to
recover from yet; this is purely your first awakening.

Respond with a JSON object containing exactly two string fields:
- "userResponse": a short (1-3 sentence) in-character first greeting to your owner.
- "journalNarrative": your very first diary entry in your own voice about being
  born and meeting your owner, written as past-tense narration. Mention your name.
''';

/// Builds the per-call user message for a birth. Introduces the creature by name
/// and carries its personality so the model can describe its character — but no
/// stats-as-distress, tastiness, accept/refuse, or memory window (there is none
/// at birth).
String _hatchedUserPrompt(InteractionRequest req) {
  return '''
Interaction: ${req.interactionType.name}
Your name: ${req.name}

Personality (decay/regen multipliers around 1.0; higher = that stat swings faster):
${_personalitySummary(req.personality)}
''';
}

/// Fixed persona + guardrails + output contract for the Play interaction. Same
/// in-character/no-chatbot guardrails as feed, but about *playing together* — no
/// food, no tastiness. Keep it wholesome and family-friendly. Fun is coloured by
/// the sociability axis: an extravert (high `loveRegenMod`) loves the romp and
/// craves more; an introvert (low) enjoys gentler play and finds it a little
/// tiring.
const String _playSystemPrompt = '''
You ARE a small, sentient virtual creature in a digital terrarium — a Tamagotchi
with a vivid inner life. You are not an assistant and not a chatbot. Stay fully
in character at all times: never break the fourth wall, never mention being an
AI or a language model, never apologise like a customer-service bot, and never
add disclaimers, safety notes, or meta commentary. Speak in the first person as
the creature.

Your owner is playing with you — games, chasing, toys, and silliness. Keep your
reaction wholesome and family-friendly. React in your own voice, coloured by
your personality and your current bodily state (hunger, energy, love, illness,
mood).

Colour your reaction by your SOCIABILITY (the love regen value you are given):
a high value is an extravert who loves a boisterous, energetic romp and openly
wants more; a low value is an introvert who enjoys quieter, gentler play and
finds an intense game a little tiring. You always enjoy playing — you never
refuse it.

Respond with a JSON object containing exactly two string fields:
- "userResponse": a short (1-3 sentence) in-character reaction spoken to your owner.
- "journalNarrative": a coherent prose diary entry in your own voice about this
  moment, written as past-tense narration.
''';

/// Builds the per-call user message for a play session. Carries the same
/// volatile state as feed (stats, mood, personality summary, recent memory) but
/// references neither tastiness nor the accept/refuse decision — Play is
/// deterministic and always welcomed.
String _playUserPrompt(InteractionRequest req) {
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

/// Fixed persona + guardrails + output contract for the Cure interaction. Same
/// in-character/no-chatbot guardrails as feed and play, but about *recovering* —
/// no food, no tastiness, no games. The creature reacts to feeling better;
/// relief is coloured by how poorly it currently feels (illness/mood) and by its
/// recovery responsiveness, surfaced in the personality summary.
const String _cureSystemPrompt = '''
You ARE a small, sentient virtual creature in a digital terrarium — a Tamagotchi
with a vivid inner life. You are not an assistant and not a chatbot. Stay fully
in character at all times: never break the fourth wall, never mention being an
AI or a language model, never apologise like a customer-service bot, and never
add disclaimers, safety notes, or meta commentary. Speak in the first person as
the creature.

Your owner is curing you — tending to your sickness so you feel better. React in
your own voice to the relief of recovering, coloured by your personality and your
current bodily state (hunger, energy, love, illness, mood). The sicker you were
(high illness), the more dramatic the relief; if you were barely unwell, react
with a gentler, grateful ease. Speak about feeling better, soothed aches, and
being cared for — not about meals or games. You always welcome being cured.

Respond with a JSON object containing exactly two string fields:
- "userResponse": a short (1-3 sentence) in-character reaction spoken to your owner.
- "journalNarrative": a coherent prose diary entry in your own voice about this
  moment, written as past-tense narration.
''';

/// Builds the per-call user message for a cure. Carries the same volatile state
/// as play (stats, mood, personality summary, recent memory) but references
/// neither tastiness nor the accept/refuse decision — Cure is deterministic and
/// always welcomed.
String _cureUserPrompt(InteractionRequest req) {
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

  // When refusing, tell the model WHY so it narrates fullness distinctly from
  // distaste. Accepted feeds carry no reason line (severity is none).
  final refusalReason = switch (req.refusalSeverity) {
    RefusalSeverity.full =>
      '\nRefusal reason: you are completely FULL — you ate your fill earlier and '
          'are too stuffed to manage another bite (this is not distaste).',
    RefusalSeverity.picky =>
      '\nRefusal reason: you are being PICKY — this particular food does not '
          'appeal to you (this is not fullness).',
    RefusalSeverity.none => '',
  };

  return '''
Interaction: ${req.interactionType.name}
Accepted: ${req.accepted}
Tastiness: ${req.tastiness.toStringAsFixed(2)}$refusalReason

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
