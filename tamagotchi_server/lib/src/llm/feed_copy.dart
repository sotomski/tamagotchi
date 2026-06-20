/// Non-LLM copy pools for the Feed interaction: the canned "I'm stuffed" lines
/// (picked when an already-full creature refuses — no model call on that path),
/// the LLM-failure degrade fallback, and the deterministic strings the stub
/// returns in key-less environments.
///
/// Keep these in-character and food-flavoured; they are user-facing.
library;

/// Funny in-character lines for a creature that is already full (`hunger == 0`)
/// and refuses without consulting the model. One is picked via the shared
/// `Random` on the full-refusal path. 10-20 entries, all non-empty.
const List<String> fullRefusalLines = [
  'Burp. No vacancy. Try again when my belly has forgotten this moment.',
  'I am, at present, a perfect sphere. Adding food would ruin the geometry.',
  'Absolutely not. I can still taste breakfast, and breakfast was yesterday.',
  'My tummy has hung a tiny "CLOSED" sign. I do not make the rules.',
  'One more bite and I become a beanbag. A delicious, immobile beanbag.',
  'Full. Stuffed. Replete. Other fancy words for "please put that away."',
  'I would, but my stomach just unionised and they voted no.',
  'No thank you! I am saving room for a nap, not a snack.',
  'If I eat that I will simply roll away, and then who feeds me?',
  'Decline. My belly is a sold-out theatre tonight.',
  'I have reached maximum creature. Refueling not required.',
  'Hard pass — I am so full I can hear my own digestion applauding.',
  'Not a chance. I am running on a completely full tank, thank you.',
  'My appetite has clocked out for the day. See it tomorrow.',
];

/// User-facing line substituted when the model call fails, so a stat change
/// still lands with a coherent (if generic) response. In-character, no
/// chatbot/disclaimer language.
const String degradeUserResponse =
    'I gobbled it up, though I am feeling a little quiet and dreamy right now.';

/// Journal narrative substituted on the same LLM-failure path, so the
/// stat change never lands without a matching journal entry.
const String degradeJournalNarrative =
    'Ate a meal in a hazy, contented sort of mood — the details already '
    'slipping away like a half-remembered dream.';

/// Deterministic response the [StubLlmService] returns when the creature
/// accepted the food. Distinct from the refuse string so accept-vs-refuse paths
/// are assertable in tests.
const String stubAcceptUserResponse =
    'Nom nom! That hit the spot — thank you, friend.';

/// Stub journal narrative for an accepted feed.
const String stubAcceptJournalNarrative =
    'Happily devoured the meal and felt a little brighter for it.';

/// Deterministic response the [StubLlmService] returns when the creature
/// refused the food (picky-refusal path; full-refusal uses [fullRefusalLines]).
const String stubRefuseUserResponse =
    'Hmph. I sniffed it, judged it, and turned up my nose. Not today.';

/// Stub journal narrative for a (picky) refused feed.
const String stubRefuseJournalNarrative =
    'Turned down the offered food with a dramatic little huff and looked away.';
