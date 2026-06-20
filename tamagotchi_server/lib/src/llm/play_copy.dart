/// Non-LLM copy for the Play interaction: the LLM-failure degrade fallback and
/// the deterministic strings the stub returns in key-less environments. There is
/// no full-refusal pool — playing never refuses (`prd.md:39`, deterministic).
///
/// Keep these in-character and play-flavoured (games, toys, romping — no food,
/// no tastiness) and family-friendly; they are user-facing.
library;

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
