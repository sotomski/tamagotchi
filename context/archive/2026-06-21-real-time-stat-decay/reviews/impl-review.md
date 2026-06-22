<!-- IMPL-REVIEW-REPORT -->
# Implementation Review: Real-Time Stat Decay & Energy Regen (FR-008 / S-07)

- **Plan**: context/changes/real-time-stat-decay/plan.md
- **Scope**: Phases 1–4 of 4 (full plan)
- **Date**: 2026-06-22
- **Verdict**: APPROVED
- **Findings**: 0 critical, 1 warning, 3 observations (all triaged & fixed)

## Verdicts

| Dimension | Verdict |
|-----------|---------|
| Plan Adherence | PASS |
| Scope Discipline | PASS |
| Safety & Quality | WARNING (F1, now fixed) |
| Architecture | PASS |
| Pattern Consistency | PASS |
| Success Criteria | PASS |

Success criteria re-run live during review (all green): server `dart analyze`,
`dart format --set-exit-if-changed`, decay unit tests (12), decay integration
tests (myCreature + feed/play/cure); flutter `analyze`, `format`, `flutter test`
(35). Plan drift: none — the two deviations (nullable `double? timeScale` at the
RPC boundary, `decayPoll` as auto-dispose) are deliberate, documented refinements.

Note: Agent-2's "anchor advances past `now`" concern was investigated and
dropped — `consumedRealMs` is bounded above by real elapsed ms (`floor()` on
ticks guarantees it, `round()` preserves the bound), so the anchor cannot pass
`now`. Not a finding.

## Findings

### F1 — myCreature now writes on the read path → lost-update race

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Safety & Quality (Data safety)
- **Location**: tamagotchi_server/lib/src/creature/creature_endpoint.dart:133-157
- **Detail**: `myCreature` was read-only before this change; it now does an
  unguarded read-modify-write (findFirstRow → decayCreature → updateRow) with no
  transaction/lock. Decay writes are idempotent (absolute values from the same
  base), so the hazard is a *lost update*: an overlapping poll can clobber a
  committed feed/play/cure with the pre-interaction decayed values. Low
  probability at single-user MVP scale, but the poll timer and an interaction tap
  are independent RPCs that can overlap.
- **Fix A ⭐ Recommended**: Gate the read-path write on the anchor (compare-and-swap).
  - Strength: Removes the lost-update class at the source; interaction txns
    already model atomic writes.
  - Tradeoff: Slightly more code on the hot poll path.
  - Confidence: MED — fix sound; exact form needed the Serverpod query API.
  - Blind spot: Whether Serverpod exposes a clean conditional update (it does —
    `LockMode.forUpdate`).
- **Decision**: FIXED via Fix A — lock-free fast path for the common no-tick
  poll; when a tick fires, the write happens inside a `session.db.transaction`
  that re-reads the row under `LockMode.forUpdate` and recomputes decay from the
  committed state, so an overlapping interaction's write can no longer be
  clobbered. Verified: `decay_endpoint_test.dart` passes (exercises both the
  locked write path and the lock-free no-op second read).

### F2 — Stale class-level doc comment on Creature

- **Severity**: ℹ️ OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Pattern Consistency
- **Location**: tamagotchi_server/lib/src/creature/creature.spy.yaml:1-2
- **Detail**: Class doc still read "Stats are fixed at the baseline at hatch
  (S-02 has no decay/regen)" — false now that decay is live.
- **Fix**: Rewrite lines 1-2 to note stats decay lazily on read from
  `lastDecayedAt`; re-run `serverpod generate` to propagate to generated trees.
- **Decision**: FIXED — comment updated and regenerated (server + client protocol).

### F3 — Public decayCreature divides by timeScale with no precondition guard

- **Severity**: ℹ️ OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Safety & Quality (Reliability)
- **Location**: tamagotchi_server/lib/src/creature/decay_service.dart:64-90
- **Detail**: Public fn divides by `timeScale`; a 0 → Infinity → `.round()`
  throws. Safe today (all callers clamp to ≥1.0) but unenforced for future callers.
- **Fix**: Add `assert(timeScale >= minTimeScale)` at the top of `decayCreature`.
- **Decision**: FIXED — assert added with an explanatory comment.

### F4 — timeScale / tick constants duplicated across the client/server boundary

- **Severity**: ℹ️ OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Architecture
- **Location**: tamagotchi_flutter/lib/creature/{time_scale_provider,decay_poll}.dart
  (mirror of decay_service.dart:21,39-40)
- **Detail**: `minTimeScale`/`maxTimeScale`/`tickMinutes` re-declared client-side
  (no cross-package Dart sharing); silent drift risk if the server retunes them.
- **Fix**: Add a test pinning the mirrored client values to the agreed spec.
- **Decision**: FIXED — added
  `tamagotchi_flutter/test/creature/decay_constants_contract_test.dart` asserting
  the three client constants match the server spec (1×/8×/10-min tick), with a
  comment that any server change must be synced here in the same change.
