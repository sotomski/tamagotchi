/// Non-LLM copy for the Play interaction: the LLM-failure degrade fallback and
/// the deterministic strings the stub returns in key-less environments. There is
/// no full-refusal pool — playing never refuses (`prd.md:39`, deterministic).
///
/// Keep these in-character and play-flavoured (games, toys, romping — no food,
/// no tastiness) and family-friendly; they are user-facing.
library;

/// In-character lines for a creature too tired to play — picked via the
/// [PlayService] `Random` on the empty-energy gate path (FR-007:
/// `energy < playEnergyCost`). No model call on that path. Play + tiredness
/// flavour (games, romping, naps — no food), 10-20 entries, all non-empty.
const List<String> playExhaustedLines = [
  "I'd play, but my legs have filed for early retirement. Maybe after a nap?",
  "Too pooped to romp, friend. Let's frolic once I've topped up my energy.",
  "My bounce is broken — I'm running on fumes. Rain check on the games?",
  'I want to play so badly, but I can barely keep my eyes open right now.',
  "No energy for zoomies today. I'm saving what little I have for breathing.",
  'Games sound wonderful, but I am one yawn from collapsing in a happy heap.',
  "I'm too tired to chase anything but a dream. Wake me when I've recharged.",
  'My get-up-and-go got up and left. Let us play after I rest my little self.',
  "Can't play now — I've spent all my wiggles and need to refuel first.",
  "I'd tumble over before the first toss. Too sleepy for fun, sorry friend.",
  "The tank's empty, pal. Let me nap and I'll be a whirlwind again soon.",
  'Too drowsy to play. Even my tail is too tired to wag.',
];

/// User-facing line substituted when the model call fails, so the play session's
/// stat change still lands with a coherent (if generic) response. In-character,
/// no chatbot/disclaimer language.
const String degradeUserResponse =
    'That was so much fun! I am a little dizzy and happy now, but I loved every '
    'second of playing with you.';

/// Journal narrative substituted on the same LLM-failure path, so the stat
/// change never lands without a matching journal entry.
const String degradeJournalNarrative =
    'We played together and I bounced around with delight — the details are '
    'already blurring into a cheerful haze, but it felt wonderful to have my '
    'friend join the fun.';

/// Deterministic response the stub returns for a play interaction. Distinct from
/// the feed stub strings (and the play degrade string) so integration tests can
/// tell the play path apart.
const String stubUserResponse =
    'Again, again! That was the best game ever. Can we play some more, friend?';

/// Stub journal narrative for a play interaction.
const String stubJournalNarrative =
    'Romped through a long, joyful game and squeaked with delight, feeling '
    'thoroughly happy and full of beans.';
