# Frame Brief: Read Creature Journal (S-08 / FR-011)

> Framing step before /10x-plan. This document captures what is *actually*
> at issue, separated from what was initially assumed.

## Reported Observation

S-08 / FR-011: "User can read the creature's journal" — open a screen and read
the full history of narrative entries. Entries are already produced and
persisted today by every hatch/feed/play/cure interaction (FR-009). The slice's
job is to surface them. The PRD's secondary success criterion this slice is
meant to validate: **"Journal feels like a story: reading back a week of journal
entries feels like a coherent narrative about a specific creature, not a random
log of events"** (`prd.md:35`).

## Initial Framing (preserved)

- **Working framing (from roadmap + research.md)**: "Small read slice. The
  entries already exist on disk; this just adds a read endpoint and a ListView
  that lists them." (`roadmap.md:195`: "small slice… adds a list view";
  `research.md` summary: "purely additive read".)
- **Proposed direction**: `readJournal` on `CreatureEndpoint` + `@riverpod`
  provider + `/journal` screen rendering the entries, newest-first by inherited
  convention.
- **Pre-dispatch narrowing (Step 1.5)**: leading concern = **the story
  experience** (not just plumbing); reading order = **newest-first feed**;
  hatch marker = **its own explicit call**.

## Dimension Map

Where the "feels like a story" outcome could break:

1. **Ordering** — newest-first feed vs oldest-first/chronological diary ← owner's stated position: newest-first
2. **Entry content/voice** — does the prose itself read as narrative, or as stubs/canned/repeated text?
3. **Edge-case entries** — blank hatch marker, silent full-refusal gap, "+0" non-events, degrade fallbacks
4. **Read plumbing + ownership** — endpoint correctness/IDOR ← the "small slice" framing (research: STRONG/solved)

## Hypothesis Investigation

| Hypothesis | Evidence | Verdict |
| --- | --- | --- |
| **#1 Ordering is a real, unresolved tension** | Newest-first is only an LLM-recency optimization (`creature_endpoint.dart:260-267`), never a display decision; no prior slice decided display order (searched `git log --all` + all archive/change md); PRD/roadmap say "chronological… feels like a story" (`roadmap.md:188`, `prd.md:35`) — direct conflict with owner's newest-first. Entries are self-contained per-moment (`creature_prompt.dart:49-50`), so newest-first is *tolerable* but reverses causality and buries the "born" opener. | **STRONG** |
| **#2 Individual entry content isn't uniformly narrative** | 3 constant LLM-degrade strings repeat verbatim on every failure (`feed_copy.dart:37`, `play_copy.dart:18`, `cure_copy.dart:20`); refusal lines drawn from a canned pool (`feed_copy.dart:12-27`); voice flips between vivid LLM prose and generic fallback. | **STRONG** |
| **#3 Edge entries read as "broken log lines"** | Hatch marker is `prose:''`, `statDelta:null` → blank first entry (`creature_endpoint.dart:78-88`); a **full** feed refusal returns early and writes **no entry at all** → silent gap (`creature_endpoint.dart:252-258`); picky-refusal + no-op-cure write all-zero `statDelta` → "+0 +0 +0" (`feed_service.dart:88`, `cure_service.dart:32`). | **STRONG** |
| **#4 It's just a read-plumbing slice** | Read query template exists (`creature_endpoint.dart:262-272`); ownership pattern established; one endpoint + provider + screen. Real, but it is the *floor*, not the *risk*. | TRUE-but-not-the-point |

## Narrowing Signals

Decisive inputs that fixed the scope:

- Owner: **S-08 owns the reading experience** — ordering, formatting, and how/whether to surface blank/zero/repeated entries are part of *this* slice (not deferred upstream).
- Owner: the **full-refusal-writes-no-entry gap is in scope** for S-08 — a performed interaction that leaves no trace belongs in this slice's problem statement. (Implication: the slice is **no longer read-only** — closing this gap means touching the feed write path, `creature_endpoint.dart:252-258`.)
- Owner: **newest-first** is the pictured reading order — but this collides with the "feels like a story" criterion the owner also chose as the leading concern. That collision is the central decision the plan must resolve, not inherit.
- Owner: **hatch marker** treatment is an explicit decision, not an afterthought.

## Cross-System Convention

A "creature's life journal" judged on *narrative coherence* conventionally reads
oldest→forward (diary), with a birth/opener as chapter one and cause→effect
(got sick → cured) preserved. Newest-first is the *activity-log* reading pattern
— precisely the "random log of events" the PRD contrasts "story" against
(`prd.md:35`). The data is self-contained per entry, so newest-first won't read
as gibberish — but self-containment makes it *tolerable*, not *story-like*. The
convention and the literal FR-011/roadmap wording both cut toward chronological;
the owner's newest-first preference is a legitimate counter-position, so this is
a genuine tradeoff for the plan to decide deliberately — not a default to inherit.

## Reframed Problem Statement

> **The actual problem to plan around is**: S-08 is a *curation-and-presentation*
> problem, not a read-plumbing problem. The journal entries on disk are real but
> are **not a clean narrative** — they contain a blank opener, a silent gap where
> a full refusal happened, "nothing happened" zero-delta rows, and verbatim-repeated
> fallback prose. The slice's job (and its success criterion) is to turn that raw,
> uneven stream into something that reads as **one creature's coherent story** —
> which requires deciding ordering, entry formatting/curation, edge-entry
> treatment, AND closing the full-refusal trace gap (a write-path change).

The "list the rows" framing is exactly what fails: a faithful renderer reproduces
a broken log and misses the criterion S-08 exists to validate. The read endpoint
+ provider + screen are still needed (the floor), but they are not where the risk
or the value lives.

## Confidence

**HIGH** — strong evidence on all three experiential dimensions (ordering,
content, edge entries), matches PRD/roadmap wording and journal convention, and
decisive owner scope signals (owns the experience; refusal gap in scope). The
only deliberately-unresolved item is the ordering tradeoff, which is a product
decision for /10x-plan, not an evidence gap.

## Resolved During Framing

- **Ordering — DECIDED: C+D.** Reverse-chronological (newest-first) **grouped by day** with day headers, AND the hatch/"born" entry given a distinct "Day one" origin treatment so the opener isn't buried at the bottom. Honors the owner's feed instinct (job 1: "what just happened") while day-scaffolding + a visible origin supply the temporal structure that clears the "feels like a story" criterion (job 2). Self-contained entries (`creature_prompt.dart:49-50`) mean newest-first never reads as gibberish. Pure chronological (B) and a toggle (E) were considered and set aside.
- **Cross-references — IN SCOPE (write-path/content).** Journal entries should be able to **mention earlier events/entries when relevant** (narrative threads, not just consistent voice). The last-10 window is already sent to the LLM (`llm_service.dart:54-56`), but the prompt only asks for *"continuity of voice"* (`creature_prompt.dart:106,159,187`) — so this needs a **prompt change** to invite backward callbacks. Compatible with C+D: references are always backward-in-time → they point *down* the feed, which reads naturally. Caveat: the window excludes empty-prose entries, so the creature cannot reference its own hatching as-is.

## What Changes for /10x-plan

The plan is **not** "add a read endpoint + ListView." It is "make the journal
read as a coherent story." Decisions still open (frame surfaces; plan resolves):

1. **Edge-entry curation** — blank hatch marker, "+0" non-events, repeated degrade fallbacks: surface, relabel, or suppress — at the read layer. (The hatch marker also needs real "Day one" content per the C+D origin-entry decision.)
2. **Full-refusal trace gap** — in scope; closing it means a **write-path** change (`creature_endpoint.dart:252-258`), so this slice is no longer read-only. (Arguable tension with FR-009 "each interaction produces a journal entry.")
3. **Cross-reference prompt change** — implement the backward-callback instruction above; decide how far to push it without overfitting the model to the 10-entry window.
4. **Plumbing floor** — read endpoint + ownership/IDOR + `@riverpod` provider + `/journal` screen, per `research.md` (already STRONG-scoped); carry it forward, don't re-litigate.

Net: this slice now spans **read + write + prompt**, not read-only.

## References

- Source: `tamagotchi_server/lib/src/creature/creature_endpoint.dart:78-88` (hatch marker), `:252-258` (full-refusal early return, no entry), `:260-272` (last-N query / newest-first convention), `:307-318`/`:420-430`/`:541-551` (write sites)
- Source: `tamagotchi_server/lib/src/llm/creature_prompt.dart:49-50` (entry contract), `feed_copy.dart:37`, `play_copy.dart:18`, `cure_copy.dart:20` (repeated degrade strings); `feed_service.dart:88`, `cure_service.dart:32` (zero-delta edge cases)
- Spec: `context/foundation/prd.md:35,84`; `context/foundation/roadmap.md:188,195`
- Related research: `context/changes/read-creature-journal/research.md` (esp. Open Questions :102, :215-216)
- Investigation tasks: #4 (entry content & edge cases), #5 (ordering tension & priors)
