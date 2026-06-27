<!-- IMPL-REVIEW-REPORT -->
# Implementation Review: Read Creature Journal (S-08 / FR-011)

- **Plan**: context/changes/read-creature-journal/plan.md
- **Scope**: All 5 phases (full plan)
- **Date**: 2026-06-27
- **Verdict**: APPROVED
- **Findings**: 0 critical · 1 warning · 3 observations

## Summary

The implementation tracks the plan exceptionally tightly. No plan drift, no
scope creep, and every "What We're NOT Doing" guardrail is respected. The two
load-bearing risks — `readJournal` IDOR scoping and hatch's
LLM-before-transaction block-on-failure — are both implemented correctly.

Automated gates verified green at review time: server `dart analyze` clean,
`dart format --set-exit-if-changed` clean, 38 server unit tests (llm +
journal_memory) pass; flutter `dart analyze` clean, `dart format` clean, 47
creature widget tests (journal_view + creature_view + reset_flow) pass. The
DB-backed integration tests (IDOR, hatch block-on-failure, full-refusal) require
`SERVERPOD_PASSWORD_database` + the test container and were not re-run here; they
passed at their respective phase commits per the plan's Progress section.

## Verdicts

| Dimension | Verdict |
|-----------|---------|
| Plan Adherence | PASS |
| Scope Discipline | PASS |
| Safety & Quality | WARNING |
| Architecture | PASS |
| Pattern Consistency | PASS |
| Success Criteria | PASS |

## Findings

### F1 — Redundant pinned-birth query on the hot interaction path

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Safety & Quality (performance)
- **Location**: tamagotchi_server/lib/src/creature/journal_memory.dart:61-83
- **Detail**: `recentJournalMemory` runs two DB queries unconditionally — a `find`
  for the last N entries plus a separate `findFirstRow` for the pinned birth — and
  is called once per feed/play/cure. For any creature with ≤ N entries (the entire
  early life of every creature), the birth is already inside the recent window, and
  `assembleMemoryWindow` already dedups it via `!recent.any((e) => e.id == birth.id)`.
  So the birth query is pure overhead for young creatures.
- **Fix**: Only issue the birth query when `recent.length == memoryWindowSize` (window
  full ⇒ oldest birth may have aged out); otherwise the pinned birth is already in
  `recent`. Removes one query per interaction for all young creatures.
- **Decision**: SKIPPED — extra query is cheap and correctness is intact; not worth
  the change now.

### F2 — journalProvider re-fetches the full journal on every interaction

- **Severity**: 🔎 OBSERVATION
- **Impact**: 🏃 LOW
- **Dimension**: Safety & Quality (performance)
- **Location**: tamagotchi_flutter/lib/creature/journal_provider.dart + 5 controllers
- **Detail**: Every feed/play/cure/hatch/reset invalidates `journalProvider`, which
  re-pulls the whole list (up to the 500 cap) via a fresh `readJournal` RPC. Cost
  grows linearly with journal size. Acceptable for MVP — pagination is explicitly
  deferred (research Open Q1).
- **Decision**: ACKNOWLEDGED — MVP-acceptable; revisit with pagination follow-up.

### F3 — readJournal sort is not index-backed

- **Severity**: 🔎 OBSERVATION
- **Impact**: 🏃 LOW
- **Dimension**: Safety & Quality (performance)
- **Location**: tamagotchi_server/lib/src/creature/creature_endpoint.dart:631-638
- **Detail**: `orderBy timestamp` + `limit 500`, but the only index on `journal_entry`
  is on `creatureId` (journal_entry.spy.yaml:24) — so it's a filter + in-memory sort
  per call. Fine at MVP volumes; revisit if journals get large.
- **Decision**: ACKNOWLEDGED — MVP-acceptable.

### F4 — journal_view recomputes groupByDay on every build

- **Severity**: 🔎 OBSERVATION
- **Impact**: 🏃 LOW
- **Dimension**: Pattern Consistency
- **Location**: tamagotchi_flutter/lib/creature/journal_view.dart:131
- **Detail**: `now = DateTime.now()` and `groupByDay`/flatten run unmemoized on each
  build, including unrelated rebuilds. Negligible at the ≤500 cap.
- **Decision**: ACKNOWLEDGED — negligible.

## Notes

- Two non-deviations the drift pass surfaced and cleared: the flipped hatch-prose
  test lives in `test/creature/` (pre-existing location, plan gave no path); and
  Phase 5's "override clockFactory" coverage correctly sits in
  `journal_memory_test.dart` (the layer that owns the clock) rather than the
  intentionally pure `creature_prompt_test.dart` — intent fully met.
- Day-boundary handling is correct: server `relativeAge` compares UTC calendar days
  (feeds the LLM); client `groupByDay`/headers use local time (`.toLocal()` + local
  now) for the user's wall-clock "Today"/"Yesterday". Deliberate split, both sides
  internally consistent.
