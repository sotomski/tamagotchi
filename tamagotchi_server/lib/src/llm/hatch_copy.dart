/// Non-LLM copy for the Hatch (birth) interaction: the deterministic strings the
/// [StubLlmService] returns in key-less environments (test run mode, CI, dev
/// without a Mistral key).
///
/// Unlike feed/play/cure there is **no degrade fallback** here — hatch blocks on
/// LLM failure rather than degrading to canned prose (plan: "No canned hatch
/// fallback"). So this file holds stub constants only.
///
/// Keep these in-character and birth-flavoured (first awakening, a new little
/// life) — they are user-facing.
library;

/// Deterministic user-facing reaction the stub returns for a birth. Distinct from
/// the feed/play/cure stub strings so integration tests can tell the hatch path
/// apart.
const String stubUserResponse =
    'Oh! Hello, world. Hello, you. I think I have only just begun, and already '
    'I am delighted to meet you.';

/// Stub journal narrative for a birth — the creature's first diary entry, in its
/// own voice, written as past-tense narration like every other entry.
const String stubJournalNarrative =
    'I opened my eyes for the very first time today and found a whole world '
    'waiting. Everything was new and a little dazzling, but a friend was there '
    'to greet me, and so my very first feeling was one of being welcome.';
