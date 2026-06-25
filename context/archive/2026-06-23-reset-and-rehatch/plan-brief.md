# Reset and Re-hatch (FR-010 / S-09) — Plan Brief

> Full plan: `context/changes/reset-and-rehatch/plan.md`

## What & Why

Let a signed-in user wipe their current creature and its entire journal, then
hatch a fresh one (FR-010). There's one creature per account, so reset is the
only way to start over — and the journal is the product's core narrative
artifact, so deleting it must be deliberate and clean.

## Starting Point

No delete path exists anywhere (`creature_endpoint.dart` even comments "no delete
path in this app"). A creature owns three tables — `creature`,
`creature_personality` (FK `ON DELETE NO ACTION`), and `journal_entry` (no FK at
all). The home screen already shows `HatchForm` whenever `creatureProvider`
returns null, so the re-hatch surface is already built.

## Desired End State

A user with a creature sees a **Reset** action in the AppBar. Tapping it opens a
confirmation dialog; confirming permanently deletes the creature + journal and
drops the user back onto the existing hatch form, where they can hatch a new
creature with freshly randomized personality. Cancel does nothing; reset with no
creature is a harmless no-op.

## Key Decisions Made

| Decision                  | Choice                                                              | Why (1 sentence)                                                                  | Source |
| ------------------------- | ------------------------------------------------------------------ | --------------------------------------------------------------------------------- | ------ |
| Flow shape                | Reset-only endpoint; re-hatch reuses existing `HatchForm`          | Zero new hatch logic; matches roadmap's "delete + re-trigger S-02's hatch path".  | Plan   |
| Deletion mechanism        | `onDelete=Cascade` on both child FKs; reset deletes only `creature`| DB enforces cleanup, reset() is one transactional delete.                         | Plan   |
| FK on `journal_entry`     | Add a real cascading FK (it has none today)                        | User explicitly wanted journal to get an FK like personality; fixes a missing constraint. | User   |
| `creature_personality` FK | Migrate from `NO ACTION` to `CASCADE`                              | Keeps both child FKs consistent under the cascade approach.                       | User   |
| Confirmation UX           | Material confirm dialog (Cancel / destructive Reset)               | Prevents accidental journal loss without heavy "type the name" friction.          | Plan   |
| Entry point               | AppBar action, shown only when a creature exists                   | Mirrors the existing log-out action; no new screen; out of the play area.         | Plan   |
| No-creature / race        | Idempotent no-op success                                           | Robust to double-taps and reset/hatch races; user always lands creatureless.      | Plan   |

## Scope

**In scope:** cascade FKs + migration; `reset()` endpoint; `ResetController`;
confirm dialog; conditional AppBar action; server integration test; widget test;
patrol e2e of the full loop.

**Out of scope:** combined reset+hatch endpoint; type-to-confirm; settings
screen; new error type for the empty case; production data-migration tooling.

## Architecture / Approach

Backend: switch both child FKs to `onDelete=Cascade`, regenerate, migrate, add an
idempotent transactional `reset()` that deletes the caller's single creature row
(DB cascades to journal + personality). Frontend: a `ResetController` mirroring
`HatchController` invalidates `creatureProvider`; the home screen's existing
`status == null ? HatchForm : CreatureView` switch handles re-hatch with no new
routing.

## Phases at a Glance

| Phase                                   | Workflow         | What it delivers                                  | Key risk                                                              |
| --------------------------------------- | ---------------- | ------------------------------------------------- | -------------------------------------------------------------------- |
| 1. Backend cascade + reset endpoint     | `/10x-tdd`       | `reset()` RPC + migration; journal/personality cascade | Adding the journal FK fails if orphaned journal rows exist in dev DB |
| 2. Frontend reset UI                    | `/10x-implement` | Controller + confirm dialog + AppBar action       | Stale `lastInteraction` lingering after reset; codegen wiring        |
| 3. E2E reset → re-hatch (patrol)        | `/10x-e2e`       | Browser test of the full loop                     | Test independence / cleanup of seeded accounts                       |

**Per-phase workflow rationale:** Phase 1 is TDD because the failing
`reset_endpoint_test.dart` is what proves the cascade migration cascades; Phase 2
is implement because it's UI wiring + Riverpod codegen, not red→green logic;
Phase 3 is the e2e sibling skill.

**Prerequisites:** S-02 (hatch + view) shipped — met. Sidecar Postgres up for
server tests (`docker compose up -d`); patrol harness for e2e.
**Estimated effort:** ~1–2 after-hours sessions across the 3 phases (small slice).

## Open Risks & Assumptions

- Adding the `journal_entry` FK assumes no orphaned journal rows in the dev DB;
  verify before applying the migration (delete orphans if any).
- Serverpod 3.4's default id-relation `onDelete` is `Cascade`, but the existing
  personality FK generated `NO ACTION` — so both models set `onDelete=Cascade`
  explicitly rather than trusting the default.
- Assumes `myCreature` continues to return `null` for "no creature" (it does
  today) — the contract the re-hatch fallback depends on.

## Success Criteria (Summary)

- A user can reset and re-hatch entirely through the UI, landing on a new
  creature with different personality/stats.
- After reset, zero creature/personality/journal rows remain for that owner.
- Reset is safe to double-tap and harmless when no creature exists.
