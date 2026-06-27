---
date: 2026-06-27T09:44:42+00:00
researcher: Karol Sotomski
git_commit: acc3bac2eb5cb51fc4d1fed15140437cf70fe807
branch: feat/read-creature-journal
repository: nabrudno (github.com/sotomski/tamagotchi)
topic: "Read creature journal (FR-011 / S-08) — full-stack read path"
tags: [research, codebase, journal, creature, serverpod-endpoint, riverpod, flutter, idor]
status: complete
last_updated: 2026-06-27
last_updated_by: Karol Sotomski
last_updated_note: "Added follow-up research for the write-path/prompt scope-delta surfaced by frame.md (hatch Day-one entry, full-refusal trace gap, cross-reference prompt seam)."
---

# Research: Read Creature Journal (FR-011 / S-08)

**Date**: 2026-06-27T09:44:42+00:00
**Researcher**: Karol Sotomski
**Git Commit**: acc3bac2eb5cb51fc4d1fed15140437cf70fe807
**Branch**: feat/read-creature-journal
**Repository**: nabrudno (github.com/sotomski/tamagotchi)

## Research Question

What does it take to build the **read creature journal** feature (FR-011 / roadmap slice S-08: "open the journal and read the full history of narrative entries")? Scope locked at intake: **full-stack read path** (server read endpoint + Flutter screen), **MVP-minimal** (no pagination design — full bounded fetch; pagination noted as an open question only).

## Summary

The journal **write** path is fully built. Every interaction (hatch / feed / play / cure) already persists a `JournalEntry` row inside a single DB transaction alongside the creature's stat update, so the four display fields FR-011 needs — `timestamp`, `event`, `statDelta`, `prose` — are already on disk and guaranteed coherent. **This slice is purely additive read**: one new Serverpod endpoint method that returns the creature's journal newest-first, and one new Flutter screen that lists the entries.

Key facts that shape the plan:

1. **No schema change / no migration.** The `journal_entry` table was deliberately defined "load-bearing" at the hatch slice with this read in mind (a `creatureId` index for last-N lookup, no vector column). Adding a read method only requires `serverpod generate`, not a migration. (Avoids the `serverpod run start` migration lesson entirely.)
2. **The strongest template already exists in the codebase**: the "last 10 journal entries for LLM context" query (`creature_endpoint.dart:262-272`). The read endpoint is that query with `limit` relaxed and scoping hardened.
3. **The central risk is IDOR (test-plan Risk #5).** Existing interaction endpoints scope by `ownerUuid` after a `requireLogin` gate — the read endpoint must copy that exact pattern, and the integration test must assert a **non-owner is denied**, not just that the owner succeeds.
4. **Frontend is a clean add**: a codegen `@riverpod Future<List<JournalEntry>>` provider mirroring `creatureProvider`, a new feature-folder screen rendering `AsyncValue.when`, a new `/journal` `GoRoute` (auto-protected by the existing auth redirect), and an AppBar entry point.

Two naming traps to carry forward:
- **"Pet" == enum `JournalEvent.play`.** PRD/roadmap say "Pet"; the shipped enum value is `play`. Map `play → "Pet"` in the **UI label layer** — do **not** rename the enum (Serverpod serializes enums byName; a rename breaks existing rows — see [[reference_serverpod_enum_byname_data_migration]]).
- **The `hatched` marker has empty prose.** The LLM-context query drops empty-prose entries; the journal *screen* should likely **keep** the "born" entry for the "feels like a story" criterion. This is a plan-time/UX decision, flagged below.

## Detailed Findings

### Backend — the journal data model

`JournalEntry` (`tamagotchi_server/lib/src/creature/journal_entry.spy.yaml:1-25`, table `journal_entry`):

| Field | Type | Notes |
|-------|------|-------|
| `id` | `UuidValue?` | PK, `random_v7` default |
| `creatureId` | `UuidValue` | scoping ref; non-unique index `journal_entry_creature_idx` |
| `ownerUuid` | `UuidValue` | owning auth user, stored directly for scoping (the IDOR-relevant column) |
| `timestamp` | `DateTime` | default `now` |
| `event` | `JournalEvent` | enum stored as **text byName**: `hatched, feed, play, cure` |
| `prose` | `String` | default `''`; empty for the `hatched` marker |
| `statDelta` | `StatDelta?` | nullable; serialized as a **JSON column** (non-table model) |

- `JournalEvent` enum: `tamagotchi_server/lib/src/creature/journal_event.spy.yaml`. Generated as `EnumSerialization.byName` (`generated/creature/journal_entry.dart:273-276`) — confirms the no-rename constraint.
- `StatDelta` (`stat_delta.spy.yaml`): non-persisted `SerializableModel`, fields `hungerDelta / energyDelta / loveDelta / illnessDelta` (all `int`), embedded as JSON on the entry.
- Table DDL: `tamagotchi_server/migrations/20260621115501267/definition.sql:71-82` (`event` is `text`, `statDelta` is `json`, index on `creatureId`).
- The four `JournalEntry` columns `timestamp / event / statDelta / prose` map 1:1 to the FR-011 display contract (`prd.md:53`). **No new model is strictly required** to satisfy the display contract — `List<JournalEntry>` is already serializable over the client.

### Backend — how entries are written today (read can trust the data)

All four writers follow the same `session.db.transaction(...)` pattern: `Creature.db.updateRow` + `JournalEntry.db.insertRow` in one transaction, with the LLM call done *before* the transaction so a fallback narrative still commits the stat+entry pair atomically.

- hatch: `creature_endpoint.dart:78-88` (marker entry, empty prose, null statDelta)
- feed: `creature_endpoint.dart:307-318`
- play: `creature_endpoint.dart:420-430`
- cure: `creature_endpoint.dart:541-550`

Consequence for the read feature: every row's `(prose, statDelta)` pairing is atomic with the stat change — the screen can render `statDelta` next to `prose` and trust they belong together (FR-009 "coherent pair").

### Backend — the endpoint/query pattern to mirror

`CreatureEndpoint` (`tamagotchi_server/lib/src/creature/creature_endpoint.dart`): `requireLogin => true` (`:19`); methods `hatch`, `myCreature`, `feed`, `play`, `cure`. Every method resolves the user and scopes by owner:

```dart
final ownerUuid = UuidValue.fromString(session.authenticated!.userIdentifier);
final creature = await Creature.db.findFirstRow(
  session,
  where: (t) => t.ownerUuid.equals(ownerUuid),
);
if (creature == null) { /* throw a no-creature error */ }
```
(auth accessor at `:29,130,214,344,464`; ownership scoping at `:37-40,217-220,347-350,467-470`.)

**Closest template for the read query** — the existing "last 10 entries for LLM context" (`creature_endpoint.dart:262-272`, duplicated at `:381-391` play, `:503-513` cure):

```dart
final recent = await JournalEntry.db.find(
  session,
  where: (t) => t.creatureId.equals(creature.id!),
  orderBy: (t) => t.timestamp,
  orderDescending: true,
  limit: 10,
);
```

The read endpoint = this query with three deltas:
1. **Scope by `ownerUuid`** (IDOR safety) — the `ownerUuid` column exists precisely for this; load the creature by `ownerUuid` first (as above), then query entries. Filtering entries by `creatureId` of an owner-verified creature is sufficient; adding `ownerUuid.equals(...)` is belt-and-suspenders.
2. **Relax `limit`** — full history (bounded default, e.g. a generous cap) for MVP; pagination deferred (see Open Questions).
3. **Keep `orderDescending: true`** for newest-first (roadmap §S-08 says "chronological order" — confirm direction at plan time; newest-first is the existing convention, roadmap text says chronological — a UX decision).
4. **Decide on the empty-prose `hatched` marker** — LLM window drops it; the screen likely keeps it.

Suggested signature (return the existing model directly — no new wrapper needed for MVP):
```dart
Future<List<JournalEntry>> readJournal(Session session);
```
`JournalEntry.db` exposes `find` / `findFirstRow` / `findById` (`generated/creature/journal_entry.dart:351-399`).

Auth in tests: `AuthenticationOverride.authenticationInfo(userUuid, <Scope>{})` via a `TestSessionBuilder.copyWith` helper (`test/creature/creature_endpoint_test.dart:10-16`).

### Backend — codegen

Adding a method (and, if any new model) requires `serverpod generate` run from `tamagotchi_server/`. Generated trees (never hand-edit, analyzer-excluded): `tamagotchi_server/lib/src/generated/` and `tamagotchi_client/lib/src/protocol/`. No migration expected (no `.spy.yaml` schema change).

### Frontend — routing

Router: `tamagotchi_flutter/lib/app/app_router.dart`. Routes today: `/` → `HomeScreen`, `/sign-in` → `SignInScreen`. Auth guard redirect (`:23-29`) sends unauthenticated users to `/sign-in` and watches `client.auth.authInfoListenable` (`:22`) so it re-evaluates live.

Add inside `routes` (`:30-39`):
```dart
GoRoute(path: '/journal', builder: (context, state) => const JournalScreen()),
```
Because it sits under the authenticated root, it is **auto-protected** — no extra guard. Navigate with `context.go('/journal')` (replace) or `context.push('/journal')` (stack + back button — likely preferred so the user returns to the creature).

### Frontend — screen pattern to mirror

Mirror `home_screen.dart:25-52` + `creature_view.dart`:
- `Scaffold` + `AppBar` + body driven by `AsyncValue.when(loading / error / data)` (`home_screen.dart:40-51`): spinner on loading; an error widget with a retry that calls `ref.invalidate(provider)`; data unpacked (here: empty list → empty-state copy, non-empty → `ListView`).
- Reusable bits in `creature_view.dart`: `_StatRow` (`:251-271`) for rendering per-stat deltas; the response box styling (`:212-244`) as a model for an entry's prose card.
- The app uses **no lists yet** — the journal screen introduces the first `ListView.builder`. Each entry as a `Card`: event label (map `play → "Pet"`), timestamp, `StatDelta` rows (reusing `_StatRow`), prose paragraph.
- **No `intl` dependency yet.** Options: hand-format `DateTime`, or add `intl` for `DateFormat`. Plan-time choice; hand-format is the smaller change.
- Theme: Material 3 (`app_widget.dart:13-18`), `useMaterial3: true`. Use `Theme.of(context)` text/color scheme as `creature_view.dart` does.

### Frontend — Riverpod provider + RPC wiring

- Client provider: `client_provider.dart:12-15` (`serverpodClientProvider`, `@Riverpod(keepAlive: true)`, overridden at app root in `main.dart:37-54`).
- Mirror `creature_provider.dart:15-22` for the journal provider (codegen `@riverpod`, `part '*.g.dart'`):
```dart
@Riverpod(keepAlive: true)
Future<List<JournalEntry>> journal(Ref ref) =>
    ref.read(serverpodClientProvider).creature.readJournal();
```
- Models imported from `package:tamagotchi_client/tamagotchi_client.dart` (`JournalEntry`, `JournalEvent`, `StatDelta`).
- Mutation/invalidation precedent: `feed_controller.dart:20-41` calls `ref.invalidate(creatureProvider)` after an interaction — if the journal screen can be open while an interaction happens, the same invalidation should extend to `journalProvider` (likely out of scope for MVP since interactions live on the creature screen).

### Frontend — navigation entry point

Add an AppBar action on the creature/home screen (`home_screen.dart:26-38`, next to the existing Log out button):
```dart
IconButton(
  icon: const Icon(Icons.menu_book),
  tooltip: 'View journal',
  onPressed: () => context.push('/journal'),
),
```

### Feature-folder placement (convention)

Group-by-feature (CLAUDE.md). Two reasonable homes — decide at plan time:
- under existing `tamagotchi_flutter/lib/creature/` (journal is a creature concern; matches how `creature_provider`/controllers cluster), or
- a new `tamagotchi_flutter/lib/journal/` dir.
Server code stays in the `creature/` feature dir (the method lands on `CreatureEndpoint`, or a new `JournalEndpoint` in `tamagotchi_server/lib/src/creature/` — endpoint-vs-new-class is a plan decision; reusing `CreatureEndpoint` is the smaller change and keeps the ownership pattern co-located).

## Code References

- `tamagotchi_server/lib/src/creature/journal_entry.spy.yaml:1-25` — journal model (the read payload)
- `tamagotchi_server/lib/src/creature/journal_event.spy.yaml` — `JournalEvent` enum (byName; do not rename)
- `tamagotchi_server/lib/src/creature/stat_delta.spy.yaml` — embedded JSON delta
- `tamagotchi_server/lib/src/creature/creature_endpoint.dart:19` — `requireLogin => true`
- `tamagotchi_server/lib/src/creature/creature_endpoint.dart:262-272` — **the read-query template** (last-N entries, newest-first)
- `tamagotchi_server/lib/src/creature/creature_endpoint.dart:37-40,217-220` — ownership scoping pattern (IDOR guard)
- `tamagotchi_server/lib/src/creature/creature_endpoint.dart:307-318` — feed journal insert (write side, for context)
- `tamagotchi_server/lib/src/generated/creature/journal_entry.dart:351-399` — `JournalEntry.db.find/findFirstRow/findById`
- `tamagotchi_server/test/creature/creature_endpoint_test.dart:10-16` — auth override test helper
- `tamagotchi_server/test/integration/feed_endpoint_test.dart` — `withServerpod` integration reference
- `tamagotchi_flutter/lib/app/app_router.dart:23-39` — routes + auth redirect (add `/journal` here)
- `tamagotchi_flutter/lib/home/home_screen.dart:40-51` — `AsyncValue.when` pattern + AppBar actions
- `tamagotchi_flutter/lib/creature/creature_provider.dart:15-22` — **the provider template**
- `tamagotchi_flutter/lib/creature/creature_view.dart:251-271` — `_StatRow` reusable for stat deltas
- `tamagotchi_flutter/lib/creature/feed_controller.dart:20-41` — mutation + invalidate precedent
- `tamagotchi_flutter/lib/app/client_provider.dart:12-15` — `serverpodClientProvider`

## Architecture Insights

- **Read is the cheap half of a deliberately front-loaded design.** The journal table, its `creatureId` index, and the "no vector column" decision were all made at the hatch slice *anticipating* this read (roadmap §S-08 risk: "small slice; entries already on disk; adds a list view"). The plan should resist scope creep — no new persistence, no migration.
- **Ownership is a per-query discipline, not a framework guarantee.** `requireLogin` only proves "logged in." Every interaction method re-derives `ownerUuid` and scopes the query; the read endpoint must do the same. There is **no DB-level FK** from `journal_entry` to `creature` (by design), so integrity is application-enforced — one more reason the ownership scoping must be explicit and tested.
- **Enum-byName + UI label mapping.** `play` is the storage truth; "Pet" is presentation. Keep the boundary clean (UI maps), never via schema rename.
- **The "story" criterion is a UX dial, not a data problem.** The data is already a clean timestamp + prose + delta stream. The secondary success criterion ("journal feels like a story", `prd.md:35`) is won by ordering, formatting, entry density, and whether the `hatched` marker shows — all at-edit-time tuning (roadmap §S-08 explicitly calls this out).

## Historical Context (from prior changes)

- `context/archive/2026-06-05-hatch-creature-and-view-stats/` (the real **S-02** hatch slice — *not* `2026-06-04-signed-in-empty-creature-view/`, which is the auth slice): introduced the `journal_entry` table as "load-bearing," schema = timestamp + prose + state-change, no vector column (ORQ-1 → last-10). `plan.md:78` explicitly **defers the journal reading screen to S-08**; the non-unique `creatureId` index was added to "support last-N lookup."
- `context/archive/2026-06-05-feed-with-personality-response/` (**S-03**): first journal writes; established the one-transaction atomic stat+entry pattern (`plan.md:56`) and the last-10 read query that is the read endpoint's template.
- `context/archive/2026-06-20-pet-with-personality-response/plan-brief.md:33` and `2026-06-20-cure-the-creature/`: mirror Feed; both explicitly mark the journal screen as **out of scope → S-08**. Confirms entries for `play`/`cure` are already on disk; no blockers for S-08.

## Test Priors (from `context/foundation/test-plan.md`)

- **Risk #5 — Ownership / IDOR** (`test-plan.md:47`, High/Medium): "one user can read … another user's creature or journal." Proof required (`:78`): a **non-owner's read is denied** — challenge "logged-in ⇒ authorized." Cheapest layer: **integration, two sessions, real DB** (Phase 3, `:92`). Anti-pattern: asserting only the owner's success.
- **Risk #3/#4** (atomicity, stub-vs-real): relevant context the read *displays*; covered by the write-side slices, but the read integration test should hit the **real endpoint through the generated client** (don't re-stub the client — the "mock lied" trap, `:78`).
- **Screen test layer**: async Riverpod surface tested via **provider overrides, never a real RPC** (`test-plan.md:119`) — see [[project_e2e_patrol_runmode_stub]] for the e2e boundary (patrol is local-only/deferred, not required for this slice). Loading = `Completer().future`; error = `Future.error`; data = list; plus empty-vs-populated flow.

## Lessons Applied (`context/foundation/lessons.md`)

1. **Migration via `serverpod run start`** — likely **N/A**: no schema change expected; only `serverpod generate`. If any model *is* touched, apply via `serverpod run start` (not `--apply-migrations`).
2. **Test async Riverpod with provider overrides** — directly governs the journal screen widget test (override `journalProvider` with canned `AsyncValue`s). Riverpod 3.x gotcha: `StateProvider` is in `package:flutter_riverpod/legacy.dart`; don't annotate `List<Override>`.
3. **Factory-seam injection** — N/A for a pure-DB read endpoint (no LLM/RNG). Only relevant if the read path touches the decay clock seam (it should not).
4. **enum-byName data migration** ([[reference_serverpod_enum_byname_data_migration]]) — a **constraint to respect**: do not rename `JournalEvent` values; map `play → "Pet"` in the UI.
5. **`dart format` before commit** — mechanical CI gate (`--set-exit-if-changed`) in both packages; run `dart format .` in `tamagotchi_server/` and `tamagotchi_flutter/` before each phase commit. `dart analyze` passing does not imply format-clean.

## Open Questions

1. **Pagination** (deferred by intake scope). MVP fetches full history with a bounded default cap. If a creature accumulates hundreds of entries, revisit — `JournalEntry.db.find` already supports `limit`/`offset`. Mark as a follow-up, not a blocker.
2. **Order direction.** Existing query is newest-first (`orderDescending: true`); roadmap §S-08 text says "chronological order." Confirm at plan time which the screen presents (newest-first list vs oldest→newest reading-as-a-story).
3. **Show the `hatched` marker?** It has empty prose. Keep it (the "born" entry adds to the story) or drop it (as the LLM window does)? UX decision for the plan.
4. **Endpoint home.** Add `readJournal` to `CreatureEndpoint` (smaller, ownership pattern co-located) vs a new `JournalEndpoint`. Recommend reusing `CreatureEndpoint` for MVP.
5. **Flutter feature folder.** `lib/creature/` (cluster with existing creature providers) vs new `lib/journal/`. Recommend `lib/creature/` to match the server-side `creature/` grouping.
6. **Out of scope (confirmed):** semantic search / long-term-memory architecture (PRD Open Q3/Q4, ORQ-1) — parked post-MVP; no vector column; this slice is last-N-agnostic full read.

## Related Research

- `context/archive/2026-06-05-hatch-creature-and-view-stats/research.md` — journal model origin
- `context/archive/2026-06-05-feed-with-personality-response/research.md` — atomic write + last-10 query
- `context/foundation/test-plan.md` §Risk Map / §6.3-6.4 — IDOR + integration test cookbook

---

## Follow-up Research 2026-06-27T11:50:00+00:00 — write-path/prompt scope-delta

`frame.md` reframed S-08 from read-only to **read + write + prompt** and locked
ordering decision **C+D** (newest-first, day-grouped, distinct "Day one" origin
entry). This addendum researches only the three newly-in-scope write/prompt
deltas the original (read-path) research did not cover. The read path above is
unchanged and remains the floor.

### A. Hatch "Day one" entry — canned constant beats generated prose

**Hatch is purely deterministic today — it makes NO LLM call.** `hatch`
(`creature_endpoint.dart:27-114`) rolls personality via local `Random()` (`:45`)
and does three inserts in one transaction (`:49-91`): creature, personality, and
the blank marker `JournalEntry(event: JournalEvent.hatched, prose: '',
statDelta: null)` (`:78-88`). It only imports `llm_service.dart` (`:6`) because
feed/play/cure (below) use it. There is **no hatch prompt branch**:
`buildInteractionMessages` (`creature_prompt.dart:13-23`) switches only on
`play`/`cure`, so `hatched` would fall through to the **feed** prompt (food /
tastiness / accept-refuse) — wrong for a birth.

Two paths to a real "Day one" entry:

- **Path 1 — generated prose (LLM): heavy, not recommended.** Requires a new
  prompt branch + constants, an awkwardly-shaped `InteractionRequest` (no
  interaction, no history → `accepted:true, tastiness:0, recentEntries:[]`), a
  new service/factory + `StubLlmService` branch, a degrade path (which needs the
  canned copy anyway), and **restructuring the hatch transaction** so the LLM
  call runs before it (today all three inserts share one transaction with no
  external call). Adds a Mistral round-trip + latency/cost to a currently-instant,
  once-per-creature flow. It is a strict superset of Path 2's work.
- **Path 2 — canned constant: cheap, recommended.** New
  `tamagotchi_server/lib/src/llm/hatch_copy.dart` (matches existing
  `feed_copy.dart`/`play_copy.dart`/`cure_copy.dart`) with a
  `const String dayOneJournalNarrative` (or a small pool). One-line endpoint edit
  (replace `prose: ''` at `:84`). **Keep `statDelta: null`** — a born entry
  records no stat change; the model comment (`journal_entry.spy.yaml:19`) and the
  test already say null is the hatched marker's value. No new prompt/service/stub,
  no transaction change, no latency.

**Test impact:** `creature_endpoint_test.dart:52` asserts `journal.single.prose
== ''` → must flip to the new copy (`isNotEmpty` / `equals(dayOneJournalNarrative)`).
Siblings stay valid: one entry (`:50`), `event == hatched` (`:51`),
`statDelta isNull` (`:53`, if null kept). Feed/play/cure integration tests filter
by event so the marker is invisible to their counts — unaffected.

### B. Full-refusal trace gap — canned prose + zero delta, matching picky-refusal

**A full refusal returns early at `creature_endpoint.dart:258`, BEFORE the
recent-entries fetch (`:262`), the LLM call (`:274`), and the transaction
(`:295`)** — so today it is instant: no LLM, no entry, no stat change (intentional
per the comment at `:249-251`). The **picky-refusal** path does NOT early-return —
it flows through the same tail as accept, calls the LLM (`:274`), and writes an
entry with a **zero `StatDelta`** (`:307-318`; comment `:314` "the entry still
records the refusal"); only the stat write (`:297`) is gated on `decision.accepted`.

Two options to give a full refusal a trace:

- **Option (a) — canned full-refusal journal prose + zero delta: recommended.**
  No journal constant exists for full refusal today — `feed_copy.dart` has only
  the **user-facing** `fullRefusalLines` pool (`:12-27`) and journal constants for
  degrade/accept/**picky** (`:37-58`). Author a new journal constant in
  `feed_copy.dart` and insert a `JournalEntry(event: JournalEvent.feed, prose:
  <canned>, statDelta: decision.delta)` in the `decision.full` block.
  `decision.delta` on the full path is **already `zeroDelta`** (`feed_service.dart:69-70`),
  so it's ready to pass. Keeps the path instant (no network), mirrors how
  `fullRefusalLine()` already pulls canned user copy, and preserves the documented
  "full = no LLM" property.
- **Option (b) — route full through the LLM (drop the early return): not
  recommended for MVP.** Most structurally consistent with picky (same tail), but
  adds a network call to an instant path AND the prompt **cannot express "full"** —
  it only branches on `accepted` true/false (`creature_prompt.dart:174`),
  `InteractionRequest` has no stuffed/full signal, so a full refusal would be
  prompted identically to a picky one unless a new field + prompt branch is added.

**statDelta = zero, not null** (null is reserved for the hatched marker).

**Test impact:** the change **inverts** `feed_endpoint_test.dart:141-165` (the
"full creature … writes no journal entry" test): its title, the `:163` `isEmpty`
→ `hasLength(1)` + prose/zero-delta assertions (mirror the picky test at
`:194-203`), and its **RNG/LLM setup** — it injects an empty scripted RNG
(`:145-146`) because the full path draws nothing; if canned prose is picked from a
pool via the rng, the empty script will throw, so widen it. If a constant is
added, `test/llm/feed_copy_test.dart` should gain non-empty/uniqueness coverage
(matches its existing pattern). The pure-gate unit test
(`feed_service_test.dart:110-130`) is unchanged (the gate still returns
`full:true`, zero delta; the new write is endpoint-side).

### C. Cross-reference prompt seam — small change, real constraints

**The recent-entries assembly is duplicated 3× with no shared helper** —
`creature_endpoint.dart:262-272` (feed), `:381-391` (play), `:503-513` (cure),
each identical: `JournalEntry.db.find(... orderBy timestamp, orderDescending:
true, limit: 10)` then `.map((e) => e.prose).where((p) => p.isNotEmpty).toList()`.
Confirmed: newest-first, drops empty-prose, limit 10. **Worth extracting a helper**
when touching this (DRY + one place to evolve the window).

**Prompt injection point:** the `"Your recent journal (newest first), for
continuity of voice:"` line appears 3× in the **USER** prompt (not system) —
`creature_prompt.dart:187` (feed), `:106` (play), `:159` (cure). This "continuity
of voice" framing is the exact seam to extend to invite backward callbacks
(e.g. "…and reference earlier moments when relevant"). The `$memory` block renders
`(no earlier entries yet)` when empty.

**Constraints the plan must respect:**

- **Window = 10, empty-prose excluded** (`llm_service.dart:54-56` doc:
  "up to the last 10 non-empty journal prose entries"). Callbacks reach back ~10
  interactions only.
- **Interaction between A and C:** today the empty hatched marker is filtered out,
  so the creature can't reference its birth. If Path 2 (A) gives the born entry
  prose, it **enters the memory window** for the first ~10 interactions — a nice
  synergy for "feels like a story" (the creature can recall being born) OR a reason
  to add an explicit `event != hatched` filter. **Decide deliberately**; the stale
  comments at `:261-262`/`:379-380`/`:501-502` ("the empty-prose hatched marker is
  dropped") become wrong either way.
- **Prose-only, no metadata.** `recentEntries` is `List<String>` of prose with no
  event type or timestamp. The model can attempt vague callbacks ("that time you
  refused dinner") from prose clues, but not "the second feed" or "three days ago."
  Adding event/timestamp metadata to the window is a possible enhancement but
  larger scope — prose-only is likely good enough for MVP.

**Test impact:** `creature_prompt_test.dart` (tests at `:87-132`, `:205-219`,
`:293-307`) asserts that prose entries *appear* and that empty renders a
placeholder — it does **not** assert the framing wording, so a reword won't break
them. Add a new assertion if you want to pin the callback instruction's presence.

### Follow-up Open Questions (for /10x-plan)

7. **Day-one prose: canned vs generated** — recommend canned (Path 2). Confirm.
8. **Full-refusal trace: canned vs LLM** — recommend canned + zero delta (Option a). Confirm.
9. **Hatched marker in the LLM memory window** — once it has prose, keep it in the window (creature can recall its birth) or filter it out (`event != hatched`)? Couples A↔C.
10. **Extract the duplicated recent-entries helper** — do it as part of the prompt-seam change, or leave the 3× duplication? (Recommend extract.)
11. **Callback richness** — accept prose-only vague callbacks for MVP, or invest in event/timestamp metadata in the window? (Recommend prose-only for MVP.)

### Follow-up Code References

- `tamagotchi_server/lib/src/creature/creature_endpoint.dart:27-114` — hatch (deterministic, no LLM), `:84` blank prose, `:78-88` marker insert
- `creature_endpoint.dart:249-258` — full-refusal early return (pre-LLM, pre-transaction); `:274` LLM call; `:295-318` transaction + insert; `:297` stat-write gate; `:314` picky zero-delta
- `creature_endpoint.dart:262-272 / :381-391 / :503-513` — the 3× duplicated recent-entries assembly
- `tamagotchi_server/lib/src/creature/feed_service.dart:62-70` — `zeroDelta`; full path already returns it
- `tamagotchi_server/lib/src/llm/creature_prompt.dart:13-23` — switch (no `hatched` branch); `:106/:159/:187` — "continuity of voice" seam
- `tamagotchi_server/lib/src/llm/llm_service.dart:54-56` — `recentEntries` doc (prose-only, ≤10, non-empty)
- `tamagotchi_server/lib/src/llm/feed_copy.dart:12-58` — user-facing `fullRefusalLines` vs journal constants (no full-refusal journal constant)
- Tests that change: `test/creature/creature_endpoint_test.dart:46-53` (hatch prose); `test/integration/feed_endpoint_test.dart:141-165` (full-refusal inverts); `test/llm/feed_copy_test.dart` (new constant); `test/llm/creature_prompt_test.dart` (optional callback assertion)
