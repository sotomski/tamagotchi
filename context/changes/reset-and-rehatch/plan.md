# Reset and Re-hatch (FR-010 / S-09) Implementation Plan

## Overview

Let a signed-in user wipe their current creature — and its entire journal — and
hatch a fresh one. This implements **FR-010** (roadmap slice **S-09**). The
re-hatch half is free: the home screen already renders `HatchForm` whenever the
user has no creature, so a successful reset that returns the user to a
creatureless state drops them back onto the existing hatch flow automatically.

The work is three things:

1. A server `reset()` endpoint that deletes the user's creature. Two child FKs
   (`journal_entry`, `creature_personality`) are switched to
   `onDelete=Cascade`, so deleting the single creature row cascades to the
   journal and personality in the database.
2. A Flutter reset path: a confirmation dialog + an AppBar action, driven by a
   small `ResetController` that invalidates `creatureProvider`.
3. An end-to-end patrol test that drives the full reset → re-hatch loop in the
   browser.

## Current State Analysis

- **No delete path exists.** `creature_endpoint.dart` even comments "Row
  vanished mid-call (no delete path in this app)" (`creature_endpoint.dart:175`).
  All five existing methods (`hatch`, `myCreature`, `feed`, `play`, `cure`) only
  create or read.
- **Three tables hang off a creature**, none cascading today:
  - `creature` — keyed by `id`; `ownerUuid` is a bare scalar with a unique index
    `creature_owner_idx` (one creature per user).
  - `creature_personality` — `creatureId: UuidValue, relation(parent=creature)`;
    the generated FK is `ON DELETE NO ACTION`
    (`migrations/20260621115501267/definition.sql:558`). 1:1 via unique index.
  - `journal_entry` — `creatureId: UuidValue` with **no `relation()`**, so **no
    FK at all** (lookup index only). Many entries per creature.
- **Serverpod 3.4.8** (`tamagotchi_server/pubspec.yaml:12`). Per the 3.4 docs the
  default `onDelete` for an id-relation is `Cascade`, but the existing
  personality FK was generated as `NO ACTION` — so this plan sets
  `onDelete=Cascade` **explicitly** on both child models rather than relying on a
  version-dependent default.
- **The re-hatch surface is already built.** `HomeScreen.body` switches on
  `creatureProvider`: `status == null ? const HatchForm() : CreatureView(...)`
  (`home_screen.dart:49-50`). `HatchForm` carries its own name field + Hatch
  button and invalidates `creatureProvider` on success (`hatch_controller.dart:23`).
- **Controller pattern is established.** `HatchController`
  (`hatch_controller.dart`) is the exact shape to mirror: `@riverpod` class,
  `AsyncLoading()` → `AsyncValue.guard()` → `ref.invalidate(creatureProvider)`.
- **AppBar has one action today** — a "Log out" `TextButton.icon`
  (`home_screen.dart:32-37`). Reset joins it there.
- **Test surfaces:** server integration tests in
  `tamagotchi_server/test/integration/*_endpoint_test.dart`; Flutter widget tests
  in `tamagotchi_flutter/test/`; patrol e2e in
  `tamagotchi_flutter/integration_test/` (`E2E_RULES.md`, `helpers/auth.dart`,
  `feed_persistence_test.dart` as the closest model).

### Key Discoveries:

- Decay is computed on-read from `lastDecayedAt` + personality — **nothing else
  is persisted per creature**, so creature + personality + journal is the
  complete deletion set (`decay_service.dart`).
- Client RPC pattern: `ref.read(serverpodClientProvider).creature.<method>()`
  (`feed_controller.dart:30-32`). After codegen, `reset()` appears on
  `EndpointCreature` automatically.
- `myCreature` already returns `null` for "no creature"
  (`creature_endpoint.dart:125-199`) — the contract the reset relies on.

## Desired End State

A signed-in user with a creature sees a **Reset** action in the AppBar. Tapping
it opens a confirmation dialog warning that the creature and journal will be
permanently deleted. Confirming deletes everything server-side and returns the
user to the `HatchForm` empty state, where they can name and hatch a brand-new
creature with freshly randomized personality. Cancelling does nothing. Calling
reset when no creature exists is a silent no-op success.

Verified by: server integration test (`reset` deletes all three tables and is
idempotent), a Flutter widget test (dialog gates the call; confirm triggers
reset + invalidation), and a patrol e2e test driving hatch → reset → re-hatch.

## What We're NOT Doing

- **No combined reset-and-rehatch endpoint.** Reset only deletes; re-hatch goes
  through the existing `HatchForm`/`hatch()` path.
- **No "type the name to confirm" friction** — a standard confirm dialog only.
- **No settings screen** — the action lives in the existing AppBar.
- **No change to `creature_personality`'s 1:1 semantics or to `journal_entry`'s
  fields** beyond adding the cascade relation.
- **No new error type** for the no-creature case — reset is idempotent, not an
  error.
- **No production data migration tooling** — dev/MVP scale; the schema migration
  is the only migration.

## Implementation Approach

Backend first (Phase 1): the cascade relations + `reset()` endpoint are the load
-bearing change and unblock the client. Because both child FKs become
`onDelete=Cascade`, `reset()` is a single `Creature.db.deleteWhere(ownerUuid==…)`
inside a transaction — Postgres removes the journal and personality rows. The
endpoint is idempotent (zero rows deleted = success).

Then the Flutter reset path (Phase 2): a `ResetController` mirroring
`HatchController`, a confirmation dialog, and a conditional AppBar action. No new
routing — invalidating `creatureProvider` re-fetches `null` and the existing
`HomeScreen` switch falls back to `HatchForm`.

Finally an e2e pass (Phase 3) via the project's patrol harness, driving the
whole loop against the running app per `/10x-e2e` conventions.

## Critical Implementation Details

**Cascade direction & migration ordering.** The FK lives on the *child*
(`journal_entry.creatureId` → `creature.id`), so `onDelete=Cascade` means
"deleting the parent creature deletes the children." Adding an FK to
`journal_entry` (which currently has none) requires every existing
`journal_entry.creatureId` to reference a live `creature` row — an orphaned
journal row would make the migration's `ADD CONSTRAINT` fail. The dev DB should
be clean, but verify before applying (see Migration Notes).

**Reset must be transactional even though it's one delete.** Wrap the delete in
`session.db.transaction` so a mid-delete failure can't leave the
`creature_owner_idx` in a half state, and to keep the pattern consistent with
hatch's transactional three-row insert (`creature_endpoint.dart:48`).

## Phase 1: Backend — cascade FKs + reset endpoint

> **Workflow: `/10x-tdd reset-and-rehatch phase 1`.** The reset endpoint's
> cascade-delete + idempotency is a crisp test-first contract — writing
> `reset_endpoint_test.dart` red (assert journal + personality rows gone after
> reset) is what *proves* the `onDelete=Cascade` migration actually cascades
> before the phase is called done. The model-relation edits, `serverpod
> generate`, and `create-migration` are prerequisite scaffolding the run does so
> the test compiles, then drives the red→green loop on the endpoint.

### Overview

Make the two child FKs cascade on delete, add an idempotent `reset()` endpoint
that deletes the caller's creature, regenerate server + client code, and migrate
the schema.

### Changes Required:

#### 1. Journal entry: add a cascading FK relation

**File**: `tamagotchi_server/lib/src/creature/journal_entry.spy.yaml`

**Intent**: Give `journal_entry` a real foreign key to `creature` (it has none
today) so the DB enforces referential integrity and cascades deletes. Keep it a
many-to-one (no unique index), unlike personality's 1:1.

**Contract**: Change the `creatureId` field to declare the relation with an
explicit cascade:
```yaml
creatureId: UuidValue, relation(parent=creature, onUpdate=NoAction, onDelete=Cascade)
```
Leave the existing non-unique `journal_entry_creature_idx` as-is.

#### 2. Creature personality: switch its FK to cascade

**File**: `tamagotchi_server/lib/src/creature/creature_personality.spy.yaml`

**Intent**: Change the existing personality FK from `NO ACTION` to `Cascade` so
deleting the creature removes its personality row.

**Contract**: Update the `creatureId` relation to be explicit about the action:
```yaml
creatureId: UuidValue, relation(parent=creature, onUpdate=NoAction, onDelete=Cascade)
```
Keep the unique `creature_personality_creature_idx` (preserves 1:1).

#### 3. Reset endpoint method

**File**: `tamagotchi_server/lib/src/creature/creature_endpoint.dart`

**Intent**: Add a `reset(Session session)` method that deletes the authenticated
user's creature (cascading to journal + personality) and returns success.
Idempotent: deleting zero rows is still success. Transactional.

**Contract**: New public method on `CreatureEndpoint` (which has
`requireLogin = true`). Signature `Future<void> reset(Session session)`.
Resolve `ownerUuid` from `session.authenticated!.userIdentifier` (same as every
other method, e.g. `creature_endpoint.dart:30`). Inside
`session.db.transaction((tx) async { ... })`, call
`Creature.db.deleteWhere(session, where: (t) => t.ownerUuid.equals(ownerUuid), transaction: tx)`.
No pre-check, no throw on empty. Returning `void` keeps the client controller's
`AsyncValue<void>` shape consistent with `HatchController`.

#### 4. Regenerate server + client protocol

**File**: `tamagotchi_server/` (codegen output in `lib/src/generated/` and
`../tamagotchi_client/lib/src/protocol/`)

**Intent**: Surface the new `reset()` RPC on the generated `EndpointCreature`
client and pick up the model relation changes.

**Contract**: Run `serverpod generate` from `tamagotchi_server/`. After it runs,
`EndpointCreature` in `tamagotchi_client/lib/src/protocol/client.dart` gains
`Future<void> reset()`. Do not hand-edit generated files.

#### 5. Schema migration

**File**: `tamagotchi_server/migrations/<new-timestamp>/`

**Intent**: Capture the two FK changes (new FK on `journal_entry`, altered FK on
`creature_personality`) as a migration.

**Contract**: Run `serverpod create-migration` from `tamagotchi_server/`; it
diffs current models vs. last schema and emits a new migration adding the
`journal_entry` FK constraint and replacing the `creature_personality` FK with a
`ON DELETE CASCADE` variant. Apply with `dart bin/main.dart --apply-migrations`.
Never hand-edit an already-applied migration.

#### 6. Server integration test

**File**: `tamagotchi_server/test/integration/reset_endpoint_test.dart`

**Intent**: Prove reset deletes all three tables, leaves `myCreature` returning
null, is idempotent, and that a subsequent hatch succeeds.

**Contract**: Use the `withServerpod` harness (mirror
`feed_endpoint_test.dart`). Cases: (a) after `hatch` then `reset`, `myCreature`
returns null and `JournalEntry.db.find` / `CreaturePersonality.db.find` for that
creature return empty; (b) `reset` with no creature completes without throwing;
(c) `hatch` succeeds again after `reset` (no `alreadyHatched`).

### Success Criteria:

#### Automated Verification:

- [ ] `serverpod generate` completes cleanly and `reset()` appears in `tamagotchi_client/lib/src/protocol/client.dart`
- [ ] Migration created and applies cleanly: `dart bin/main.dart --apply-migrations`
- [ ] Server analyzer passes: `dart analyze` in `tamagotchi_server/`
- [ ] Reset integration test passes: `dart test test/integration/reset_endpoint_test.dart` (sidecar Postgres up via `docker compose up -d`)
- [ ] Existing endpoint integration tests still pass: `dart test test/integration/`

#### Manual Verification:

- [ ] Inspecting the DB after a reset shows zero `creature`, `creature_personality`, and `journal_entry` rows for that owner
- [ ] No orphaned journal/personality rows remain after delete

**Implementation Note**: After Phase 1 automated verification passes, pause for
human confirmation of the manual DB checks before starting Phase 2.

---

## Phase 2: Frontend — reset controller, confirmation dialog, AppBar action

> **Workflow: `/10x-implement reset-and-rehatch phase 2`.** UI assembly (confirm
> dialog, conditional AppBar action) plus Riverpod `build_runner` codegen —
> better built then verified with the widget test than driven red→green on a
> widget tree. (If preferred, the dialog-gating assertions — "confirm calls
> reset once, cancel doesn't" — can be written test-first.)

### Overview

Add the client reset path: a controller, a confirmation dialog, and an AppBar
action that only appears when a creature exists. Re-hatch reuses `HatchForm`.

### Changes Required:

#### 1. Reset controller

**File**: `tamagotchi_flutter/lib/creature/reset_controller.dart`

**Intent**: Drive the reset action through idle → loading → result, then
invalidate `creatureProvider` so the UI falls back to `HatchForm`. Mirror
`HatchController` exactly.

**Contract**: `@riverpod class ResetController extends _$ResetController` with
`FutureOr<void> build() {}` and `Future<void> reset()` that sets
`const AsyncLoading()`, then `AsyncValue.guard(() async { await
ref.read(serverpodClientProvider).creature.reset(); ref.invalidate(creatureProvider); })`.
Generates `reset_controller.g.dart` via build_runner. (Also invalidate
`lastInteractionProvider` if present so a stale interaction message doesn't
linger — confirm the provider name in `creature/` before wiring.)

#### 2. Confirmation dialog

**File**: `tamagotchi_flutter/lib/creature/reset_confirm_dialog.dart` (or inline
helper near the AppBar action)

**Intent**: Gate the destructive reset behind an explicit confirm. Material
`AlertDialog` warning the creature and journal will be permanently deleted, with
Cancel and a destructive-styled Reset button.

**Contract**: A `Future<bool> showResetConfirmDialog(BuildContext context)`
returning true only when the user taps the confirm button. Title + body text
state the loss is permanent. Buttons use accessible labels (role/text reachable
by `getByRole`/`getByText` for e2e): "Cancel" and "Reset". Confirm button styled
destructive (e.g. error color).

#### 3. AppBar reset action

**File**: `tamagotchi_flutter/lib/home/home_screen.dart`

**Intent**: Add a "Reset" action next to "Log out", shown **only when a creature
exists**, that runs the confirm dialog then calls the controller.

**Contract**: In `HomeScreen.build`, derive presence from the already-watched
`creatureProvider` (`creatureStatus.valueOrNull != null`). When present, add a
second `TextButton.icon` (label "Reset", a suitable icon) to `AppBar.actions`
whose `onPressed` awaits `showResetConfirmDialog`, and on true calls
`ref.read(resetControllerProvider.notifier).reset()`. Give it a `Key('resetButton')`
for tests. Keep the text-label pattern (the existing comment at
`home_screen.dart:29-31` explains why bare icons are avoided on web).

#### 4. Build runner

**File**: `tamagotchi_flutter/` (generated `*.g.dart`)

**Intent**: Generate the Riverpod code for `ResetController`.

**Contract**: Run `dart run build_runner build --delete-conflicting-outputs` in
`tamagotchi_flutter/`. Produces `reset_controller.g.dart`.

#### 5. Widget test

**File**: `tamagotchi_flutter/test/creature/reset_flow_test.dart` (or extend
`test/home/home_screen_test.dart`)

**Intent**: Verify the dialog gates the call and confirm triggers reset +
invalidation; verify the reset action is hidden when no creature exists.

**Contract**: Pump `HomeScreen` (or the relevant subtree) inside a
`ProviderScope` overriding `creatureProvider` with a stub creature and the
serverpod client with a fake whose `creature.reset()` records the call (follow
the `riverpod-testing` / `riverpod-overrides` skill and existing
`home_screen_test.dart`). Cases: (a) reset action absent when
`creatureProvider` is null; (b) tapping reset shows the dialog; (c) Cancel does
not call `reset()`; (d) confirm calls `reset()` exactly once.

### Success Criteria:

#### Automated Verification:

- [ ] build_runner completes; `reset_controller.g.dart` generated
- [ ] Flutter analyzer passes: `flutter analyze` in `tamagotchi_flutter/`
- [ ] Reset widget test passes: `flutter test test/creature/reset_flow_test.dart`
- [ ] Existing widget tests still pass: `flutter test`

#### Manual Verification:

- [ ] With a creature, "Reset" shows in the AppBar; with none, it does not
- [ ] Tapping Reset → Cancel leaves the creature untouched
- [ ] Tapping Reset → confirm returns to the HatchForm empty state
- [ ] Re-hatching after reset produces a creature with different stats/personality

**Implementation Note**: After Phase 2 automated verification passes, pause for
human confirmation of the manual UI checks before starting Phase 3.

---

## Phase 3: End-to-end reset → re-hatch loop (patrol)

> **Workflow: `/10x-e2e`.** Browser-level loop — the e2e sibling of
> `/10x-implement`/`/10x-tdd`; the skill owns risk → generate → review against
> the five anti-patterns → verify. (Not TDD/implement: this drives a real
> browser against the running app.)

### Overview

Drive the full loop in a browser against the running app, following the
project's patrol e2e conventions and `/10x-e2e` workflow.

### Changes Required:

#### 1. E2E test for the reset → re-hatch loop

**File**: `tamagotchi_flutter/integration_test/reset_rehatch_test.dart`

**Intent**: Verify a real user can hatch, reset (through the confirm dialog), and
re-hatch a new creature — the user-visible FR-010 loop end to end.

**Contract**: Follow `integration_test/E2E_RULES.md` and the structure of
`feed_persistence_test.dart`; reuse `helpers/auth.dart` for sign-in and the seed
pattern for a unique account (timestamp-suffixed, self-cleaning, standalone).
Locators by role/label/text (never CSS/XPath); wait on state (`toBeVisible`,
`waitForURL`), never `waitForTimeout`. Flow: sign in → hatch a named creature →
assert `CreatureView` visible → tap the AppBar Reset → confirm in the dialog →
assert the `HatchForm` empty state ("No creature yet…") is visible → hatch a new
creature → assert `CreatureView` visible again. Run through the `/10x-e2e` skill
(risk → generate → review against the five anti-patterns → verify).

### Success Criteria:

#### Automated Verification:

- [ ] E2E test passes against the running app via the project's patrol runner
- [ ] Test is independent and self-cleaning (unique account per run; passes on re-run and in parallel)

#### Manual Verification:

- [ ] The e2e run visibly completes the hatch → reset → re-hatch loop without manual intervention
- [ ] No leftover test creatures/accounts block subsequent runs

**Implementation Note**: Drive this phase through `/10x-e2e`, which owns the
generate → review → re-prompt → verify cycle.

---

## Testing Strategy

### Unit / Service Tests:

- No new pure service logic (reset is a single delete) — covered at the
  integration layer.

### Integration Tests:

- Server: `reset` deletes creature + personality + journal; idempotent on empty;
  hatch succeeds afterward (Phase 1).
- Flutter widget: dialog gating, conditional AppBar action, controller
  invalidation (Phase 2).

### End-to-End (patrol):

- Full hatch → reset → re-hatch loop in the browser (Phase 3).

### Manual Testing Steps:

1. Sign in, hatch a creature, interact a few times to create journal entries.
2. Tap Reset in the AppBar → Cancel → confirm creature unchanged.
3. Tap Reset → confirm → land on the hatch empty state.
4. Hatch again → verify a new creature with different personality/stats.
5. Inspect the DB to confirm no orphaned rows for the old creature.

## Performance Considerations

Negligible. Reset is one cascading delete on a single owner's small row set at
MVP scale.

## Migration Notes

- Adding the FK to `journal_entry` requires all existing `journal_entry.creatureId`
  values to reference live `creature` rows. Before applying, confirm the dev DB
  has no orphaned journal rows (a stray-row `ADD CONSTRAINT` failure is the one
  realistic migration risk). If found, delete orphans before migrating.
- Altering `creature_personality`'s FK from `NO ACTION` to `CASCADE` is a
  constraint swap; existing rows are unaffected.
- Apply with `dart bin/main.dart --apply-migrations` from `tamagotchi_server/`.

## References

- Roadmap slice: `context/foundation/roadmap.md` (S-09, lines 198-208)
- PRD: `context/foundation/prd.md` FR-010 (line 62)
- Hatch path to mirror: `tamagotchi_server/lib/src/creature/creature_endpoint.dart:27-114`
- Controller pattern: `tamagotchi_flutter/lib/creature/hatch_controller.dart`
- Home switch / empty state: `tamagotchi_flutter/lib/home/home_screen.dart:40-51`
- Existing FK (personality): `tamagotchi_server/migrations/20260621115501267/definition.sql:558`
- Referential actions syntax (Serverpod 3.4): `relation(parent=…, onUpdate=NoAction, onDelete=Cascade)`
- E2E conventions: `tamagotchi_flutter/integration_test/E2E_RULES.md`; `/10x-e2e` skill

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: Backend — cascade FKs + reset endpoint

#### Automated

- [ ] 1.1 `serverpod generate` completes cleanly and `reset()` appears in the generated client
- [ ] 1.2 Migration created and applies cleanly: `dart bin/main.dart --apply-migrations`
- [ ] 1.3 Server analyzer passes: `dart analyze`
- [ ] 1.4 Reset integration test passes: `dart test test/integration/reset_endpoint_test.dart`
- [ ] 1.5 Existing endpoint integration tests still pass: `dart test test/integration/`

#### Manual

- [ ] 1.6 DB shows zero creature/personality/journal rows for that owner after reset
- [ ] 1.7 No orphaned journal/personality rows remain after delete

### Phase 2: Frontend — reset controller, confirmation dialog, AppBar action

#### Automated

- [ ] 2.1 build_runner completes; `reset_controller.g.dart` generated
- [ ] 2.2 Flutter analyzer passes: `flutter analyze`
- [ ] 2.3 Reset widget test passes: `flutter test test/creature/reset_flow_test.dart`
- [ ] 2.4 Existing widget tests still pass: `flutter test`

#### Manual

- [ ] 2.5 Reset action shows only when a creature exists
- [ ] 2.6 Reset → Cancel leaves the creature untouched
- [ ] 2.7 Reset → confirm returns to the HatchForm empty state
- [ ] 2.8 Re-hatching after reset produces a different creature

### Phase 3: End-to-end reset → re-hatch loop (patrol)

#### Automated

- [ ] 3.1 E2E test passes against the running app via the patrol runner
- [ ] 3.2 Test is independent and self-cleaning (unique account; passes on re-run and in parallel)

#### Manual

- [ ] 3.3 E2E run visibly completes hatch → reset → re-hatch without intervention
- [ ] 3.4 No leftover test creatures/accounts block subsequent runs
