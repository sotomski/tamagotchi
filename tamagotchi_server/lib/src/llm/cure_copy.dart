/// Non-LLM copy for the Cure interaction: the LLM-failure degrade fallback and
/// the deterministic strings the stub returns in key-less environments. There is
/// no full-refusal pool — curing never refuses (`prd.md:39`, deterministic) and
/// is always available regardless of energy (FR-006).
///
/// Keep these in-character and recovery-flavoured (feeling better, relief,
/// soothed aches — no food, no tastiness, no games) and family-friendly; they
/// are user-facing.
library;

/// User-facing line substituted when the model call fails, so the cure's stat
/// change still lands with a coherent (if generic) response. In-character, no
/// chatbot/disclaimer language.
const String degradeUserResponse =
    'Oh, that feels so much better — the achy fog is lifting and I can breathe '
    'easy again. Thank you for taking care of me, friend.';

/// Journal narrative substituted on the same LLM-failure path, so the stat
/// change never lands without a matching journal entry.
const String degradeJournalNarrative =
    'I was feeling poorly, but my friend tended to me and slowly the sickness '
    'loosened its grip — the details blur into a grateful warmth, yet I '
    'remember feeling cared for and on the mend.';

/// Deterministic response the stub returns for a cure interaction. Distinct from
/// the feed and play stub strings (and the cure degrade string) so integration
/// tests can tell the cure path apart.
const String stubUserResponse =
    'Phew — the shivers are fading and my tummy has settled. I feel brighter '
    'already, all thanks to you!';

/// Stub journal narrative for a cure interaction.
const String stubJournalNarrative =
    'Rested as the medicine did its quiet work; the heavy, feverish ache eased '
    'away and I drifted into a calmer, healthier sort of comfort.';
