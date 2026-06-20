/// Non-LLM copy for the Pet interaction: the LLM-failure degrade fallback and
/// the deterministic strings the stub returns in key-less environments. There is
/// no full-refusal pool — Pet never refuses (`prd.md:39`, deterministic).
///
/// Keep these in-character and pet-flavoured (no food, no tastiness); they are
/// user-facing.
library;

/// User-facing line substituted when the model call fails, so the pet's stat
/// change still lands with a coherent (if generic) response. In-character, no
/// chatbot/disclaimer language.
const String degradeUserResponse =
    'Mmm, that was nice. I am feeling a little quiet and dreamy right now, '
    'but I felt every bit of that.';

/// Journal narrative substituted on the same LLM-failure path, so the stat
/// change never lands without a matching journal entry.
const String degradeJournalNarrative =
    'Was petted and went soft and warm all over — the details are already '
    'blurring into a contented haze, but it felt like being cared for.';

/// Deterministic response the stub returns for a pet interaction. Distinct from
/// the feed stub strings (and the pet degrade string) so integration tests can
/// tell the pet path apart.
const String stubUserResponse =
    'Ahh, right there — that is the good spot. Do that again, please, friend.';

/// Stub journal narrative for a pet interaction.
const String stubJournalNarrative =
    'Leaned into a long, lovely petting and hummed with quiet delight, feeling '
    'thoroughly adored.';
