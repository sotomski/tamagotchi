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

/// In-character lines for a creature too tired to eat — picked via the shared
/// `Random` on the empty-energy gate path (FR-007: `energy < feedEnergyCost`).
/// No model call on that path. Food + tiredness flavour, 10-20 entries, all
/// non-empty, and deliberately distinct from [fullRefusalLines] so the two
/// refusals (too tired vs. too full) read differently.
const List<String> feedExhaustedLines = [
  'I am too sleepy to chew. Waking the jaw takes energy I simply do not have.',
  "No food, please — I'd doze off mid-bite and snore right into the bowl.",
  'My fork-lifting muscles have gone on strike until I have had a nap.',
  "Can't eat now. Even my appetite is yawning.",
  "I'm running on empty, friend — far too drowsy to so much as nibble.",
  'Food sounds lovely, but my eyelids weigh more than the snack does.',
  "Too tired to eat. Ask again once I've recharged my little batteries.",
  "I'd love a bite, but I'm one blink away from a very long nap.",
  'My energy is at the bottom of the jar. Dinner waits for my second wind.',
  "Zzz... oh, food? Sorry, I'm far too exhausted to lift a single crumb.",
  "I'm all out of pep. Eating can resume after I have rested my weary self.",
  "No thank you — chewing is a workout and I've nothing left in the tank.",
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
