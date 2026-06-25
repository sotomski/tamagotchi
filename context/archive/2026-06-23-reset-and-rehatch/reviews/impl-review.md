<!-- IMPL-REVIEW-REPORT -->
# Implementation Review: Reset and Re-hatch (FR-010 / S-09)

- **Plan**: context/changes/reset-and-rehatch/plan.md
- **Scope**: All 3 phases (complete)
- **Date**: 2026-06-25
- **Verdict**: APPROVED
- **Findings**: 0 critical, 1 warning, 2 observations (all triaged)

## Verdicts

| Dimension | Verdict |
|-----------|---------|
| Plan Adherence | PASS |
| Scope Discipline | PASS |
| Safety & Quality | WARNING (F1 — fixed) |
| Architecture | PASS |
| Pattern Consistency | PASS |
| Success Criteria | PASS (analyze spot-verified; test runs from commits + full suite re-run green) |

## Findings

### F1 — Reset RPC failure is never surfaced to the user

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Safety & Quality (Reliability)
- **Location**: tamagotchi_flutter/lib/home/home_screen.dart:34, 48-57 (+ reset_controller.dart:23-30)
- **Detail**: home_screen only read `resetControllerProvider).isLoading`, never `.hasError`/`ref.listen`. On a reset failure the dialog is already gone, the button silently re-enables, the creature is still present, and the user gets zero feedback — diverging from hatch_form (renders state.error) and creature_view (inline error banner). No reset-error test existed.
- **Fix**: Added `ref.listen(resetControllerProvider, ...)` in `HomeScreen.build` showing a `SnackBar` (key `resetErrorSnackBar`) on `AsyncError`, plus a widget test (`a failed reset surfaces an error and keeps the creature`) driving the real loading→error path via a `_FailingResetController` and asserting the SnackBar shows and the creature survives.
- **Decision**: FIXED (Fix now) — verified: analyze clean, 8/8 reset_flow tests pass, full suite 43/43 green.

### F2 — lastInteractionProvider invalidation is untested

- **Severity**: 🔍 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Pattern Consistency / test coverage
- **Location**: tamagotchi_flutter/lib/creature/reset_controller.dart:28
- **Detail**: `reset()` invalidates `lastInteractionProvider` (a touch beyond hatch_controller) so a stale Feed/Play line doesn't linger after reset. The doc comment claimed it; no test guarded it against regression.
- **Fix**: Added a `ProviderContainer` test (`reset clears the stale last-interaction outcome`) that runs the **real** `ResetController.reset()` through a `_StubResetClient` (overrides `Client.callServerEndpoint`), seeds `lastInteractionProvider`, resets, and asserts it returns to null.
- **Decision**: FIXED (Fix now) — verified green.

### F3 — Unplanned .claude/settings.json change in the diff range

- **Severity**: 🔍 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Scope Discipline
- **Location**: .claude/settings.json (commit c1a2704)
- **Detail**: The diff range includes a hooks-path fix (resolve the dart-format hook via `"$CLAUDE_PROJECT_DIR"`) landed as a separate commit between p1 and p2. Benign, unrelated to FR-010; flagged only so the out-of-feature change is acknowledged.
- **Fix**: None needed — informational.
- **Decision**: ACKNOWLEDGED (close, no action).

## What's solid

- Authorization is airtight: `reset` is owner-scoped via `ownerUuid.equals`, `requireLogin`, with a dedicated A-can't-delete-B test.
- Cascade enforced at the DB: migration drops/recreates both child FKs `ON DELETE CASCADE`.
- Delete is transactional and idempotent (zero-row delete = success).
- Destructive action gated by an explicit confirm dialog (barrier-dismiss and Cancel both return false).
- The `ref.watch` keep-alive subtlety (auto-dispose across the in-flight RPC) is handled and documented.
- All 9 planned items MATCH with extra test coverage; no drift, no scope creep.
