# Read Creature Journal (S-08 / FR-011) — Implementation Plan

## Overview

Surface the creature's journal as a screen the owner can read — but the real work
is making it **read as one creature's coherent story**, not a raw log. Per the
frame brief, the entries on disk are uneven: a blank hatch opener, a silent gap
where a full feed-refusal wrote no entry, "+0 +0 +0" zero-delta non-events, and
verbatim-repeated degrade prose. This slice spans **read + write + prompt + UI**:

- **Read:** a `readJournal` endpoint (IDOR-scoped) + a journal view embedded on the
  home screen (reshaped from a standalone `/journal` screen — see Phase 2).
- **Presentation:** newest-first, **day-grouped**, with a distinct **"Day one"**
  origin card; zero-delta entries **relabeled/softened** (kept, not suppressed).
- **Write:** a real **LLM-generated birth entry** (replacing the blank marker),
  and closing the **full-refusal trace gap** by routing it through the LLM.
- **Prompt:** a richer **structured memory window** (event + relative age + prose)
  with the birth entry **pinned permanently**, rewording the seam to invite
  backward narrative callbacks.

## Current State Analysis

The journal **write** path is built: every interaction persists a `JournalEntry`
in one transaction with the stat update, so `timestamp / event / statDelta / prose`
are on disk and coherent (`research.md` §"how entries are written"). What's missing
and uneven:

- **No read endpoint / no screen.** The closest template is the last-10 LLM-context
  query (`creature_endpoint.dart:262-272`).
- **Blank hatch opener.** Hatch is deterministic (no LLM); it writes
  `JournalEntry(event: hatched, prose: '', statDelta: null)`
  (`creature_endpoint.dart:78-88`). All three hatch inserts share one transaction
  with no external call (`:49-91`).
- **Silent full-refusal gap.** A full feed-refusal early-returns at
  `creature_endpoint.dart:258` *before* the LLM call (`:274`) and transaction
  (`:295`) → no entry at all. The **picky** path does not early-return; it writes a
  **zero-delta** feed entry (`:307-318`).
- **Flat prose-only memory window.** `recentEntries` is `List<String>`, newest-first,
  empty-prose dropped, limit 10 — assembled **identically 3×**
  (`creature_endpoint.dart:262-272 / :381-391 / :503-513`) and rendered in the USER
  prompt under "Your recent journal (newest first), for continuity of voice:"
  (`creature_prompt.dart:106/159/187`).

Key seams confirmed by research:
- **`InteractionRequest`** is a plain server-internal Dart class
  (`llm_service.dart:15-57`) — **not** a `.spy.yaml` model. Adding fields (`name`,
  refusal severity, structured `recentEntries`) needs **no codegen/migration**.
- **`llmServiceFor(session)`** (`llm_service.dart:77-88`) selects `MistralLlmService`
  when `mistralApiKey` is present, else `StubLlmService` — so dev/test/e2e (no key)
  are deterministic; only real-key production can fail.
- **`StubLlmService`** (`stub_llm_service.dart:19-45`) switches on `interactionType`.
- **`clockFactory(session)`** (`decay_service.dart:112-119`) is the test-overridable
  clock seam; feed/play/cure already call it (`creature_endpoint.dart:241/371/492`).
- **`CreatureHatchError` / `CreatureHatchErrorReason`** already model hatch failures
  (`creature_endpoint.dart:33-50`) — extend with a reason for "narrative unavailable".
- Creature has `name: String`; personality is 7 `double` modifiers
  (`creature.spy.yaml:12`, `creature_personality.spy.yaml`).

## Desired End State

The owner sees, on the home screen beside the creature, a newest-first, day-grouped history that opens
(at the bottom / earliest) with a personalized **"Day one"** birth card naming the
creature and its character, where every performed interaction — including full
refusals and zero-delta moments — leaves a softened, in-voice trace, and where the
creature's narration references earlier moments ("yesterday you refused dinner";
recalling its own birth). Verify: the integration suite denies a non-owner's read;
hatch writes real birth prose (not `''`); a full refusal writes one zero-delta entry;
the memory window carries event + relative age and pins the birth entry; the screen
renders day groups, the origin card, softened zero-delta entries, and the "Pet" label.

### Key Discoveries

- `InteractionRequest` is non-serialized → field additions are free (`llm_service.dart:15-57`).
- `llmServiceFor` is key-gated, so "block hatch on LLM failure" only bites real-key prod; stub always succeeds (`llm_service.dart:77-88`).
- Full-refusal already has a zero `StatDelta` ready on its path (`feed_service.dart:69-70`); only the early-return and missing entry are the gap.
- Pinning the birth entry requires it to *have* prose first → Phase 3 precedes Phase 5.
- `JournalEvent` is enum-byName — never rename; map `play → "Pet"` in the UI only ([[reference_serverpod_enum_byname_data_migration]]).
- No schema change anywhere → no migration; only `readJournal` triggers `serverpod generate`.

## What We're NOT Doing

- **No pagination** — full bounded fetch with a generous cap; `limit`/`offset` exist for a later follow-up (`research.md` Open Q1).
- **No semantic search / vector memory / long-term-memory architecture** — parked post-MVP (`research.md` Open Q6).
- **No new `JournalEndpoint`** — `readJournal` lands on `CreatureEndpoint`.
- **No new `lib/journal/` folder** — journal code joins `lib/creature/`.
- **No `intl` dependency** — hand-format day headers.
- **No canned hatch fallback** — hatch blocks on LLM failure (deliberate; no `hatched_copy.dart` degrade prose).
- **No enum rename** — `play` stays `play`.
- **No dedup of repeated degrade prose** — "relabel/soften, keep all" keeps every entry.

## Implementation Approach

Ship the visible journal early against existing data (Phases 1–2), then progressively
enrich the narrative on the write/prompt side (Phases 3–5). Each phase is independently
verifiable. The read path keeps the hatched marker (the screen needs the origin entry),
so Phase 2 renders a graceful origin card even before Phase 3 fills it with real prose.

## Critical Implementation Details

- **Phase ordering is load-bearing for pinning.** The birth entry can only be pinned
  into the memory window (Phase 5) once it has real prose (Phase 3). Keep 3 before 5.
- **Block-on-failure must leave no partial state.** Hatch's LLM call runs *before* the
  transaction (mirroring feed at `creature_endpoint.dart:274` vs `:295`); a failure
  throws `CreatureHatchError` and nothing is written. Personality is still rolled with
  `Random()` before the call — a thrown hatch simply discards it (no creature row).
- **Relative-age strings are computed server-side, not in the prompt builder.**
  `creature_prompt.dart` is pure (no `Session`). Compute each entry's human age via
  `clockFactory(session)()` in the endpoint-side helper and pass the rendered struct
  into `InteractionRequest`, so the prompt builder stays clock-free and the tests stay
  deterministic by overriding `clockFactory`.

---

## Phase 1: Read floor — `readJournal` endpoint + IDOR test

**Workflow**: `/10x-tdd` — the slice's central risk (IDOR) is a crisp behavioral spec.
Implement a naive *unscoped* `readJournal`, run `serverpod generate` (so the client method
compiles), write the non-owner-denied integration test (red: it leaks A's rows to B), then add
`ownerUuid` scoping to green. The codegen is a prerequisite step inside the cycle.

### Overview

Add the owner-scoped read endpoint that returns the full journal newest-first,
**including** the hatched marker. This is the plumbing floor; the central risk is IDOR.

### Changes Required

#### 1. Read endpoint method

**File**: `tamagotchi_server/lib/src/creature/creature_endpoint.dart`

**Intent**: Return the caller's journal entries newest-first for display. Resolve
`ownerUuid` from `session.authenticated!`, load the owner's creature (the existing
ownership pattern at `:37-40`), then query its entries — do **not** drop empty prose
(the screen needs the hatched origin entry).

**Contract**: `Future<List<JournalEntry>> readJournal(Session session)`. Query mirrors
`:262-272` (`orderBy: timestamp, orderDescending: true`) with the empty-prose filter
removed and `limit` raised to a generous bounded cap (e.g. a `const` like 500).
Belt-and-suspenders: also constrain by `ownerUuid.equals(...)`. No creature → return
`[]` (or reuse the existing no-creature error; pick the screen-friendly empty path).

#### 2. Codegen

**File**: generated trees (`tamagotchi_server/lib/src/generated/`, `tamagotchi_client/lib/src/protocol/`)

**Intent**: Expose `readJournal` on the generated client.

**Contract**: Run `serverpod generate` from `tamagotchi_server/`. No `.spy.yaml` change → no migration.

#### 3. IDOR integration test

**File**: `tamagotchi_server/test/integration/journal_endpoint_test.dart` (new)

**Intent**: Prove a **non-owner is denied** (the test-plan Risk #5 proof), not just that
the owner succeeds. Two authenticated sessions, real DB, real client — owner A hatches
and interacts; owner B's `readJournal` must not return A's entries.

**Contract**: `withServerpod` harness mirroring `test/integration/feed_endpoint_test.dart`;
`AuthenticationOverride.authenticationInfo(userUuid, {})` per session. Assert B sees none
of A's rows (empty or B's own only).

### Success Criteria

#### Automated Verification
- `serverpod generate` produces a clean client method (no analyzer errors): `cd tamagotchi_server && dart analyze`
- Integration test passes (non-owner denied): `cd tamagotchi_server && dart test test/integration/journal_endpoint_test.dart` (with `SERVERPOD_PASSWORD_database=<test pw>`)
- Format clean: `cd tamagotchi_server && dart format --set-exit-if-changed .`

#### Manual Verification
- Calling `readJournal` as the owner returns all entries including the hatched marker, newest-first.

**Implementation Note**: After automated verification passes, pause for manual confirmation before Phase 2.

---

## Phase 2: Journal screen — provider, route, day-grouped UI

**Workflow**: `/10x-implement` — UI-dominant (first `ListView`, route, AppBar) where widget
assertions are written *after* the tree exists, not test-first. Drive it with implement, but
write the **pure helpers test-first within the phase**: day-bucketing, day-header formatting,
and the origin/zero-delta/normal entry classifier.

### Overview

The first list UI in the app: the journal rendering the entries newest-first,
**grouped by day**, with a distinct **"Day one" origin card** and **softened** zero-delta
entries. Renders gracefully against today's data (blank marker) before Phase 3.

> **Reshape (post-manual-verification, 2026-06-27):** per owner feedback the journal
> is **embedded on the home screen as a 50/50 left-creature / right-journal split**
> (shown only once a creature exists), **not** a standalone `/journal` screen reached
> via an AppBar icon — both the route and the icon were dropped. The screen widget is
> therefore an embeddable `JournalView` (no `Scaffold`/`AppBar`), and the home's
> `CreatureView` was made responsive for its now-narrower half (button `Row`→`Wrap`,
> body wrapped in a `SingleChildScrollView`). Additionally, the feed/play/cure/hatch/
> reset controllers now **invalidate `journalProvider`** so an interaction's entry
> appears immediately (the journal was otherwise stale after a play).

### Changes Required

#### 1. Journal provider

**File**: `tamagotchi_flutter/lib/creature/journal_provider.dart` (new)

**Intent**: Async-load the journal over the generated client, mirroring `creatureProvider`.

**Contract**: codegen `@Riverpod(keepAlive: true) Future<List<JournalEntry>> journal(Ref ref)`
calling `ref.read(serverpodClientProvider).creature.readJournal()`; `part 'journal_provider.g.dart'`.

#### 2. Journal view (embeddable — reshaped from a standalone screen)

**File**: `tamagotchi_flutter/lib/creature/journal_view.dart` (new; **renamed** from the
originally-planned `journal_screen.dart` — it is now an embeddable `JournalView` with no
`Scaffold`/`AppBar`, carrying its own "Journal" header).

**Intent**: Render `AsyncValue.when` (loading spinner / error+retry via
`ref.invalidate(journalProvider)` / data). Data path: group entries by calendar day
(newest day first), render a day header per group, then each entry as a `Card`. Give the
`hatched` entry a distinct **"Day one"** origin card. Apply the **relabel/soften** rule
to zero-delta entries: render no "+0" stat chips and a muted "nothing changed" treatment;
non-zero deltas render as signed stat chips. Map `play → "Pet"` at the label layer (never
the enum). Empty list → empty-state copy.

**Contract**: `ListView.builder` over day-grouped sections; pure helpers (`journal_format.dart`)
for day-bucketing + hand-formatted day-header labels (e.g. "Today" / "Yesterday" / "June 25")
— no `intl` — plus a classifier for entry kind: origin (`hatched`) / zero-delta / normal.

#### 3. Home embed + freshness (reshaped — no route/AppBar entry)

**File**: `tamagotchi_flutter/lib/home/home_screen.dart` (+ `creature_view.dart`;
`feed/play/cure/hatch/reset_controller.dart`)

**Intent**: Embed the journal **on the home screen** as the right half of a 50/50
left-creature / right-journal split, shown only once a creature exists (empty state stays
the `HatchForm`). Keep the journal fresh after interactions. **No** `/journal` route and
**no** AppBar icon (both removed — superseded by the embed).

**Contract**: home `data` path → `Row(children: [Expanded(CreatureView), VerticalDivider,
Expanded(JournalView)])` when a creature is present. `CreatureView` made responsive for the
narrower half: button `Row`→`Wrap`, body wrapped in `SingleChildScrollView`. Each of the
feed/play/cure/hatch/reset controllers adds `ref.invalidate(journalProvider)` beside its
existing `invalidate(creatureProvider)` so a new entry shows immediately.

#### 4. Widget tests

**File**: `tamagotchi_flutter/test/creature/journal_view_test.dart` (new; **renamed** from
`journal_screen_test.dart`). Plus `journalProvider` overrides added to the existing
`creature_view_test.dart` and `reset_flow_test.dart` — now that the home embeds `JournalView`,
those present-creature pumps must stub the journal to `[]` ([[lessons]] "Test async Riverpod
surfaces with provider overrides").

**Intent**: Cover loading / error / empty / populated, and the three render branches
(origin card, softened zero-delta, normal-with-deltas), via provider overrides — never a
real RPC.

**Contract**: override `journalProvider` with canned `AsyncValue`s (loading → `Completer().future`
+ single `pump()`; error → `Future.error`; data → list literals incl. a `hatched` entry, a
zero-delta entry, and a normal one). Assert "Pet" label maps from `play`. Pump `JournalView`
wrapped in a `Scaffold` (it is no longer a screen of its own). Also includes pure-helper unit
tests (classifier / bucketing / header formatting).

### Success Criteria

#### Automated Verification
- Riverpod codegen builds: `cd tamagotchi_flutter && dart run build_runner build --delete-conflicting-outputs`
- Widget tests pass: `cd tamagotchi_flutter && flutter test test/creature/journal_screen_test.dart`
- Analyze + format clean: `cd tamagotchi_flutter && dart analyze && dart format --set-exit-if-changed .`

#### Manual Verification
- The home's right-half journal shows day headers, newest-first; the born entry renders as a distinct origin card.
- A zero-delta entry shows no "+0" chips; a normal entry shows its stat deltas.
- "Pet" appears for `play` entries; an interaction (e.g. Play) refreshes the journal in place — no navigation needed.

**Implementation Note**: After automated verification passes, pause for manual confirmation before Phase 3.

---

## Phase 3: LLM-generated birth entry

**Workflow**: `/10x-tdd` — the risk is the **block-on-failure contract**. Inject a throwing LLM
via the `llmServiceFor` factory seam and assert `CreatureHatchError` + **no creature row written**
(red), then wire the pre-transaction LLM call to green. The prompt prose + stub strings are built
within the cycle (not themselves test-driven).

### Overview

Replace the blank hatch marker with a personalized, LLM-generated birth narrative naming
the creature and describing its character. Hatch becomes an LLM round-trip that **blocks
on failure** (no canned fallback).

### Changes Required

#### 1. `name` on the interaction request

**File**: `tamagotchi_server/lib/src/llm/llm_service.dart`

**Intent**: The birth prompt needs the creature's name (the request carries personality
but not name today).

**Contract**: add `final String name;` to `InteractionRequest` (plain class — no codegen).
Populate it at existing call sites as a no-op for feed/play/cure (or default), required for hatch.

#### 2. Hatch prompt branch

**File**: `tamagotchi_server/lib/src/llm/creature_prompt.dart`

**Intent**: Add a `JournalEvent.hatched` branch to `buildInteractionMessages` (today it
falls through to the feed prompt — wrong for a birth). Author a system/user prompt that
introduces the creature by `name`, describes its character from the personality modifiers,
and produces a first-person birth `journalNarrative`.

**Contract**: extend the `switch` at `:13-23` with a `JournalEvent.hatched =>` case →
`(_hatchedSystemPrompt, _hatchedUserPrompt(req))`. The hatch `InteractionRequest` is shaped
`accepted: true, tastiness: 0, recentEntries: []` (no history at birth).

#### 3. Stub birth branch

**File**: `tamagotchi_server/lib/src/llm/stub_llm_service.dart` (+ new `tamagotchi_server/lib/src/llm/hatch_copy.dart` for stub strings only)

**Intent**: Keep dev/test/e2e deterministic — the stub returns a fixed birth narrative.

**Contract**: add an `interactionType == JournalEvent.hatched` branch before the feed
fallback returning `hatch.stubUserResponse / stubJournalNarrative`. `hatch_copy.dart` holds
**stub** constants only (no production degrade copy — hatch blocks instead of degrading).

#### 4. Hatch calls the LLM and blocks on failure

**File**: `tamagotchi_server/lib/src/creature/creature_endpoint.dart`

**Intent**: Run the LLM call *before* the hatch transaction; feed its narrative into the
journal insert (replacing `prose: ''` at `:84`); on LLM failure throw `CreatureHatchError`
so nothing is written. Keep `statDelta: null` (a birth records no stat change).

**Contract**: between personality roll (`:45`) and the transaction (`:49`), call
`llmServiceFor(session).generateInteraction(...)` for a `hatched` request; wrap so a thrown
LLM error becomes a new `CreatureHatchErrorReason` value (e.g. `narrativeUnavailable`) —
**no try-catch degrade**. Use the result's `journalNarrative` for the marker's `prose`.
Add the reason to the `CreatureHatchErrorReason` enum (`.spy.yaml`) → `serverpod generate`.

#### 5. Test inversion

**File**: `tamagotchi_server/test/creature/creature_endpoint_test.dart`, `tamagotchi_server/test/llm/` (+ stub/copy coverage)

**Intent**: The hatch prose is no longer empty.

**Contract**: flip `creature_endpoint_test.dart:52` (`journal.single.prose == ''`) to assert
non-empty / equals the stub narrative; siblings (one entry, `event == hatched`,
`statDelta isNull`) stay valid. Add a failing-LLM hatch test (inject a throwing LLM via the
factory seam → assert `CreatureHatchError` and **no creature row written**). Add stub/branch
coverage for the hatched path.

### Success Criteria

#### Automated Verification
- `serverpod generate` clean after the enum addition: `cd tamagotchi_server && dart analyze`
- Endpoint + LLM tests pass (incl. block-on-failure leaves no row): `cd tamagotchi_server && dart test test/creature/ test/llm/`
- Format clean: `cd tamagotchi_server && dart format --set-exit-if-changed .`

#### Manual Verification
- Hatching writes a real, name-aware birth narrative; the `/journal` origin card now shows it.
- With a real key and a forced LLM failure, hatch surfaces an error and creates no creature.

**Implementation Note**: After automated verification passes, pause for manual confirmation before Phase 4.

---

## Phase 4: Full-refusal trace through the LLM

**Workflow**: `/10x-tdd` — a literal **test inversion**. Flip `feed_endpoint_test.dart:141-165`
from `isEmpty` to `hasLength(1)` + zero-delta/prose assertions (red), then drop the early-return
and add the entry insert to green. The severity field + prompt branch support the green step.

### Overview

Close the silent gap: a full feed-refusal flows through the LLM (like picky) and writes a
**zero-delta** feed entry, narrated as fullness — distinguished from a picky refusal by an
explicit severity signal.

### Changes Required

#### 1. Refusal-severity signal

**File**: `tamagotchi_server/lib/src/llm/llm_service.dart`

**Intent**: Let the prompt distinguish a full refusal (stuffed) from a picky one (distaste);
today the prompt only branches on `accepted`.

**Contract**: add a refusal-severity field to `InteractionRequest` (plain class — no codegen),
e.g. an enum `full | picky | none`. Derive it at the endpoint from the existing feed decision
(`feed_service.dart` `decision.full` / picky / accepted).

#### 2. Feed prompt branch

**File**: `tamagotchi_server/lib/src/llm/creature_prompt.dart`

**Intent**: Narrate fullness vs distaste distinctly when refusing.

**Contract**: branch `_userPrompt`/`_systemPrompt` (feed) on the new severity so a full
refusal is prompted as "too full" rather than "dislikes this food".

#### 3. Drop the early-return; write the entry

**File**: `tamagotchi_server/lib/src/creature/creature_endpoint.dart`

**Intent**: Remove the full-refusal early-return at `:258` so the full path runs the same
tail as picky — LLM call → transaction → journal insert — but the **stat write stays gated**
on `decision.accepted` (no stat change for a refusal).

**Contract**: full path now reaches `:262-318`; insert a `JournalEntry(event: feed,
prose: reply.journalNarrative, statDelta: decision.delta)` where `decision.delta` is already
`zeroDelta` on the full path (`feed_service.dart:69-70`). `statDelta = zero, not null`
(null is reserved for the hatched marker).

#### 4. Stub full-refusal branch

**File**: `tamagotchi_server/lib/src/llm/stub_llm_service.dart`

**Intent**: Deterministic stub output for a full refusal.

**Contract**: extend the feed branch to return a full-refusal narrative when severity is `full`.

#### 5. Test inversion

**File**: `tamagotchi_server/test/integration/feed_endpoint_test.dart` (+ stub coverage)

**Intent**: The "full creature writes no journal entry" test now asserts the opposite.

**Contract**: invert `:141-165` — title, the `:163` `isEmpty` → `hasLength(1)` with
zero-delta + prose assertions (mirror the picky test `:194-203`), and widen the empty
scripted RNG (`:145-146`) since the full path now flows through the tail. The pure-gate
unit test (`feed_service_test.dart:110-130`) is unchanged.

### Success Criteria

#### Automated Verification
- Feed integration + LLM tests pass (full refusal writes one zero-delta entry): `cd tamagotchi_server && dart test test/integration/feed_endpoint_test.dart test/llm/`
- Analyze + format clean: `cd tamagotchi_server && dart analyze && dart format --set-exit-if-changed .`

#### Manual Verification
- Fully refusing food produces one journal entry (zero delta), narrated as fullness, visible in `/journal`.
- A picky refusal still narrates distaste; the two read differently.

**Implementation Note**: After automated verification passes, pause for manual confirmation before Phase 5.

---

## Phase 5: Narrative memory window — structured, clock-aware, pinned birth

**Workflow**: `/10x-tdd` — pure, deterministic logic ideal for red→green→refactor: the extracted
helper's **pinning + dedup** and **relative-age rendering** (with `clockFactory` overridden to a
fixed instant) are unit functions. Drive those test-first; the prompt reword is built within.

### Overview

Upgrade the LLM memory window from flat prose to **event + relative age + prose**, **pin the
birth entry permanently**, extract the 3× duplicated assembly into one helper, and reword the
seam to invite backward callbacks.

### Changes Required

#### 1. Extract the recent-entries helper

**File**: `tamagotchi_server/lib/src/creature/` (new helper, e.g. in `creature_service.dart` or a `journal_memory.dart`)

**Intent**: Collapse the identical assembly at `:262-272 / :381-391 / :503-513` into one
place to evolve the window.

**Contract**: one function taking `(session, creature)` returning the structured window used
by feed/play/cure. Replace all three call sites.

#### 2. Structured window with relative age + pinned birth

**File**: the helper + `tamagotchi_server/lib/src/llm/llm_service.dart`

**Intent**: Each window entry carries its `event`, a **relative human age** (computed from
`timestamp` via `clockFactory(session)()`), and prose. **Pin the hatched birth entry
permanently** so the creature can always recall its origin: window = pinned birth entry +
last N interactions (dedup if the birth is already within N).

**Contract**: change `InteractionRequest.recentEntries` from `List<String>` to a structured
list (e.g. `List<({JournalEvent event, String age, String prose})>` or a small named type —
plain Dart, no codegen). Age strings ("earlier today" / "yesterday" / "a while back") rendered
server-side from the clock seam. The birth entry is fetched/pinned separately from the last-N
query. Remove the now-wrong empty-prose-drop comments (`:261-262/:379-380/:501-502`).

#### 3. Reword the prompt seam for callbacks

**File**: `tamagotchi_server/lib/src/llm/creature_prompt.dart`

**Intent**: Render the structured window (event + age + prose) and extend the "continuity of
voice" line (`:106/159/187`) to invite referencing earlier moments when relevant.

**Contract**: update the memory rendering to include event + age per line; reword the seam
text to encourage backward callbacks. Empty window still renders the existing placeholder.

#### 4. Tests

**File**: `tamagotchi_server/test/llm/creature_prompt_test.dart`, helper unit test

**Intent**: Pin the new behavior.

**Contract**: assert the window renders event + age + prose and that the birth entry is
present even beyond the last-N window (override `clockFactory` for deterministic ages). Add a
helper unit test for pinning + dedup. Existing prose-presence/placeholder assertions
(`:87-132/:205-219/:293-307`) stay valid; add a callback-instruction assertion if pinning the wording.

### Success Criteria

#### Automated Verification
- LLM + helper tests pass (structured window, pinned birth, deterministic ages): `cd tamagotchi_server && dart test test/llm/`
- Full server suite green: `cd tamagotchi_server && dart test`
- Analyze + format clean: `cd tamagotchi_server && dart analyze && dart format --set-exit-if-changed .`

#### Manual Verification
- After several interactions, narration references earlier moments and can recall the birth.
- A creature with >10 interactions still references its origin (pinning works).

**Implementation Note**: After automated verification passes, pause for manual confirmation. Slice complete.

---

## Testing Strategy

### Unit Tests
- Day-bucketing + day-header formatting helper (Phase 2).
- Entry classifier: origin / zero-delta / normal (Phase 2).
- Recent-entries helper: pinning + dedup + relative-age rendering with overridden `clockFactory` (Phase 5).
- Stub branches: hatched (Phase 3), full-refusal (Phase 4).

### Integration Tests
- **IDOR**: non-owner `readJournal` denied (Phase 1) — two sessions, real DB.
- **Hatch block-on-failure**: throwing LLM → `CreatureHatchError`, no creature row (Phase 3).
- **Full-refusal trace**: inverted feed test — one zero-delta entry (Phase 4).

### Manual Testing Steps
1. Hatch a creature → `/journal` shows a personalized Day-one origin card.
2. Feed to full → one "too full" entry, no stat chips.
3. Make a picky refusal → distinct "distaste" entry.
4. Interact >10 times → narration references earlier moments and recalls birth.
5. Open `/journal` as a second user → see only your own entries.

## Performance Considerations

- Hatch gains an LLM round-trip (latency on the app's entry action) — accepted per the
  block-on-failure decision; only real-key prod is affected.
- Full bounded read fetch (cap ~500) is fine for MVP; pagination deferred.

## Migration Notes

No schema migration for models. Two `.spy.yaml`-adjacent codegen triggers: `readJournal`
(Phase 1) and the new `CreatureHatchErrorReason` value (Phase 3) — both `serverpod generate`,
no DB migration. Existing rows unaffected (the blank-marker rows simply render as origin cards
with no prose until overwritten by new hatches).

## References

- Frame brief: `context/changes/read-creature-journal/frame.md`
- Research: `context/changes/read-creature-journal/research.md` (esp. Follow-up §A/§B/§C, Open Qs 7–11)
- Read-query template: `tamagotchi_server/lib/src/creature/creature_endpoint.dart:262-272`
- Degrade pattern: `tamagotchi_server/lib/src/creature/feed_service.dart:133-151`
- Provider/screen templates: `tamagotchi_flutter/lib/creature/creature_provider.dart:15-22`, `home_screen.dart:40-51`, `creature_view.dart:251-271`
- Lessons: provider-override widget tests; `serverpod run start` for any migration; `dart format` before commit ([[lessons]])

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: Read floor — readJournal endpoint + IDOR test

#### Automated
- [x] 1.1 `serverpod generate` clean, analyzer passes — 2379693
- [x] 1.2 IDOR integration test passes (non-owner denied) — 2379693
- [x] 1.3 Format clean (`--set-exit-if-changed`) — 2379693

#### Manual
- [ ] 1.4 Owner `readJournal` returns all entries incl. hatched marker, newest-first

### Phase 2: Journal screen — provider, route, day-grouped UI

#### Automated
- [x] 2.1 Riverpod codegen builds — e4626c5
- [x] 2.2 Widget tests pass (loading/error/empty/populated + 3 render branches) — e4626c5
- [x] 2.3 Analyze + format clean — e4626c5

#### Manual
- [ ] 2.4 Home right-half journal: day headers newest-first; born entry renders as origin card
- [ ] 2.5 Zero-delta entry shows no "+0" chips; normal shows deltas
- [ ] 2.6 "Pet" label for `play`; an interaction refreshes the journal in place (left/right split)

### Phase 3: LLM-generated birth entry

#### Automated
- [ ] 3.1 `serverpod generate` clean after enum addition, analyzer passes
- [ ] 3.2 Endpoint + LLM tests pass incl. block-on-failure leaves no row
- [ ] 3.3 Format clean

#### Manual
- [ ] 3.4 Hatch writes name-aware birth narrative; origin card shows it
- [ ] 3.5 Forced real-key LLM failure → hatch errors, no creature created

### Phase 4: Full-refusal trace through the LLM

#### Automated
- [ ] 4.1 Feed integration + LLM tests pass (full refusal → one zero-delta entry)
- [ ] 4.2 Analyze + format clean

#### Manual
- [ ] 4.3 Full refusal → one zero-delta "too full" entry visible in journal
- [ ] 4.4 Picky refusal still narrates distaste; reads differently

### Phase 5: Narrative memory window — structured, clock-aware, pinned birth

#### Automated
- [ ] 5.1 LLM + helper tests pass (structured window, pinned birth, deterministic ages)
- [ ] 5.2 Full server suite green
- [ ] 5.3 Analyze + format clean

#### Manual
- [ ] 5.4 Narration references earlier moments and recalls birth
- [ ] 5.5 Creature with >10 interactions still recalls origin (pinning works)
