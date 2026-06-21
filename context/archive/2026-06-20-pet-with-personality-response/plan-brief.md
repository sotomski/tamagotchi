# Pet the creature and receive a personality-driven response + journal entry — Plan Brief

> Full plan: `context/changes/pet-with-personality-response/plan.md`

## What & Why

Roadmap slice **S-04** (PRD **FR-005**): a user pets their creature and gets a personality-shaped, in-character AI response paired with a journal entry; love rises and energy falls. It extends the north-star AI loop (S-03 Feed) to a second interaction, proving the hypothesis that *personality makes each interaction feel distinct* — here via the introvert↔extravert axis.

## Starting Point

S-03 (Feed, PR #9, merged) shipped the whole reusable surface: the `LlmService` + Mistral + key-presence selection seam, `InteractionRequest` (already typed for Pet), `JournalEvent.pet`, the one-transaction stat+journal write, the `feedServiceFactory` injection seam, and the Flutter controller/view patterns. `CreaturePersonality` carries two independent love mods (`loveDecayMod`, `loveRegenMod`); `loveDecayMod` is currently inert.

## Desired End State

A signed-in user sees **Feed** and **Pet** buttons. Pet shows a "Petting…" animation, then within ~5s an in-character response coloured by the creature's sociability; love rises (extravert more), energy falls (introvert more), both clamped; one coherent `pet` journal entry lands. A fully-loved creature is still petted (no gate). Feed and Pet share one response area. `loveRegenMod` is the single introvert↔extravert dial; `loveDecayMod` is gone.

## Key Decisions Made

| Decision | Choice | Why (1 sentence) | Source |
| --- | --- | --- | --- |
| Determinism | No random gate for Pet | `prd.md:39` mandates Pet/Cure are fully deterministic — no accept/refuse, no RNG. | PRD |
| Personality axis | Derive from `loveRegenMod` | Reuses S-03's "derive, don't add a field" precedent; `loveRegenMod` is the natural sociability dial. | Plan |
| Axis coherence | **Remove** `loveDecayMod` | Two independent love rolls can't be one axis; subtraction (not a new field) makes `loveRegenMod` the sole love dial. | Plan (user) |
| Love / energy math | `loveGain=round(15·E)` (≈8–22); `energyCost=round(4·(2−E))` (≈6→2) | Extravert gains more love; introvert tires more — both monotonic in `E=loveRegenMod`. | Plan (user) |
| Max-love (love=100) | Always pet, no gate | Petting a beloved creature is always valid; love clamps to 0 delta, energy still costs, entry + response still produced. | Plan (user) |
| Interaction UI | Two buttons, one shared response area | Clean, uncluttered, scales to Cure (S-05); a `lastInteractionProvider` tracks most-recent. | Plan (user) |
| Test coverage | Mirror S-03: unit + integration + widget | Matches the shipped, CI-green template; e2e stays its own slice. | Plan (user) |

## Scope

**In scope:** the `pet` endpoint + `PetResult` + `CreaturePetError`; deterministic pet math + `PetService` seam; pet branches of the prompt builder + stub + new `pet_copy.dart`; removal of `loveDecayMod` (+ migration); Flutter `PetController` + shared two-interaction UI; unit/integration/widget tests.

**Out of scope:** the `energy==0` gate (S-06); love decay over time (S-07); any change to the LLM client/selection/secret wiring; a new `extraversion` field; token streaming; patrol e2e; the journal screen (S-08).

## Architecture / Approach

Bottom-up, mirroring S-03. **Phase 1** unifies the personality axis (remove `loveDecayMod`, regenerate, migrate). **Phase 2** adds pure pet math (`loveGain`/`energyCost` from `loveRegenMod`) + the `PetService` degrade wrapper + pet prompt/stub/copy branches, with unit tests. **Phase 3** composes the `pet` endpoint (deterministic delta → LLM-with-degrade → one transaction → `PetResult`), regenerates the client, integration-tests it. **Phase 4** wires `PetController` + a shared `lastInteractionProvider` and the Feed+Pet UI, widget-tested. The LLM is the only impure collaborator, injected through one production-default `petServiceFactory` seam; no randomness seam (Pet is deterministic).

## Phases at a Glance

| Phase | What it delivers | Key risk |
| --- | --- | --- |
| 1. Unify love axis | `loveRegenMod` as sole love dial; `loveDecayMod` removed + migration | A missed reference / migration mis-apply (mitigated: bounded 5-file + 4-test grep, `serverpod run start`) |
| 2. Pet math + LLM surface | Pure pet math, `PetService`, pet prompt/stub/copy, unit tests | Pet prompt branch reading distinct-enough from Feed (mitigated: prompt content test) |
| 3. Pet endpoint + tests | `pet()`, `PetResult`, `CreaturePetError`, integration tests | Endpoint composition drift from `feed()` (mitigated: direct mirror) |
| 4. Flutter + widget tests | `PetController`, shared response area, two buttons | Two-controller coordination for "most recent" (mitigated: `lastInteractionProvider`) |

**Prerequisites:** S-03 shipped (met). Local Postgres sidecar + a dev `mistralApiKey` for manual verification.
**Estimated effort:** ~2–3 sessions across 4 phases; smaller than S-03 (no LLM wiring, no RNG, deterministic).

## Open Risks & Assumptions

- Removing `loveDecayMod` is correct only because it is inert today; S-07 must derive love decay from `loveRegenMod` to keep one coherent axis (noted forward).
- The love/energy magnitudes (base 15 / 4) are tunable feel-values; play-testing may adjust them.
- The shared-response coordination assumes only one interaction is in flight at a time (true for tap-driven buttons).

## Success Criteria (Summary)

- Pet produces a personality-distinct, in-character response + a coherent `pet` journal entry within ~5s.
- An extravert measurably gains more love (and spends less energy) per pet than an introvert.
- Feed and Pet coexist cleanly with one shared response area; full suite (unit + integration + widget) green; `loveDecayMod` fully removed.
