# Frame Brief: Trait / Mood / Stats concepts and their relations (S-02)

> Framing step before /10x-plan. This document captures what is *actually*
> at issue, separated from what was initially assumed.

## Reported Observation

How should the creature's **traits**, **stats**, and **mood** — *and the
relations between them* — be modeled in S-02 (`hatch-creature-and-view-stats`,
"hatch + view only", no AI, static stats)?

## Initial Framing (preserved)

- **User's stated cause or approach**: trait/mood/stats are *one inseparable
  coupled system*; "their relations" must be designed together as one unit of
  S-02 work.
- **User's proposed direction**: work the trait/mood/stats concepts + their
  relations now, as part of planning S-02.
- **Pre-dispatch narrowing**: leading concern = **"the whole system at once"**
  (sees all three as inseparable); how-live-is-coupling-at-hatch = **"not sure,
  that's the question"**; does-mood-depend-on-traits = **"not sure yet"**. The
  user's uncertainty about the *coupling* is itself the signal this frame
  resolves.

## Dimension Map

The "trait/mood/stats relations" design question could originate at any of these:

1. **Trait internal model** — shape (2 bipolar axes vs 4 independent doubles) +
   range. Standalone concept, no cross-concept relation.
2. **Stat internal model** — ranges + hatch-time initial values. Standalone.
3. **Stats → Mood relation** — the mood derivation formula. *Must compute &
   render at hatch.*
4. **Traits → Stats relation** — (a) traits seed initial stats at hatch? (b)
   traits drive decay rates? *(4b is explicitly S-07.)*
5. **Traits → Mood relation** — does personality color mood? *(user's open Q.)*
6. **Traits → Response relation** — picky/introvert affect responses. *S-03+.*
7. **Persistence vs derivation boundary** — stored columns vs computed-on-read;
   what S-02 schema must not foreclose for S-03–S-09.  ← initial framing treats
   1–7 as one live system; this is the genuinely load-bearing S-02 dimension.

## Hypothesis Investigation

| Hypothesis | Evidence | Verdict |
| --- | --- | --- |
| **(3) Stats→Mood is the only relation that must be *live* at S-02** | FR-003 (`prd.md:66`) + `roadmap.md:109` require a derived mood displayed alongside the four static stats; mood is the one relation that must actually compute at hatch | **STRONG** |
| **(5) Mood depends on traits** | No source ties mood to traits; every source naming mood inputs says the four stats (`prd.md:66`, `roadmap.md:109`, `research.md:43,178`) | **NONE** (mood = stats-only) |
| **(4a) Traits seed initial stats at hatch** | Mentioned by *no source* — neither required nor forbidden; surfaces only as `research.md:177` "pick the hatched starting values" (a design choice independent of traits) | **NONE / UNSPECIFIED** |
| **(4b/6) Trait↔stat coupling is live at S-02 (initial framing)** | Coupling is real but owned downstream: trait→response S-03 (`prd.md:82`, FR-009), trait→Feed-mod S-03 (`prd.md:72`), trait→Pet-mod S-04 (`prd.md:74`), trait→decay S-07 (`prd.md:68`); explicitly deferred `research.md:51-57` | **NONE at S-02** |
| **(7) The load-bearing S-02 decision is the persistence/derivation boundary** | `roadmap.md:117` "fixes the data model for creature + journal"; mood derived-on-read (not stored) keeps it consistent through S-07 decay; persist continuous traits so S-03/07 *read* them with no migration (`research.md:156-158,178`) | **STRONG** |

## Narrowing Signals

Decisive findings that collapsed the hypothesis space:

- The primary success criterion — "two creatures with opposite traits, **given
  an identical sequence of care**, end measurably different" (`prd.md:32`) — is
  a property of the **care sequence**, not hatch state. At hatch, two creatures
  differ only in trait rolls; stats are identical baseline (`roadmap.md:109`
  "Stats are mechanical at this point").
- The determinism guardrail (`prd.md:39`) constrains the function
  `(traits, care) → (stats, mood)` — which S-03/S-07 implement. Its only demand
  on S-02 is that hatch seeding and mood-from-stats be *pure*, **not** that
  traits flow into stats at hatch.
- An independent codebase read (no hypothesis named) independently recommended
  mood **derived-on-read**, traits **persisted continuous**, owner-as-scalar —
  matching the deferral structure rather than the coupled-engine framing.

## Cross-System Convention

This class of decision — "lay down a schema now that later slices extend" — is
handled in-repo by **persist the inputs, derive the views, defer the behavior**:
auth stores `authUserId` as a bare scalar and scopes in app code
(`migration.sql:245`); `research.md:51-57` already drew the explicit S-02
deferral boundary. The leading hypothesis (persist inert traits + derive mood on
read) matches this convention; the coupled-engine framing cuts against it by
pulling S-03/S-04/S-07 logic across that boundary.

## Reframed (or Confirmed) Problem Statement

> **The actual problem to plan around is**: lay down a *forward-compatible
> persisted trait model* and a *deterministic, stats-only, derived-on-read
> mood* for the hatch+view cut — **not** design a live trait↔stat↔mood engine.
> At S-02 the only relation that exists is **Stats→Mood**; the trait relations
> are *interface obligations* (persist the values so later slices read them),
> not implementations.

The user's instinct — "it's one inseparable system" — is true of the *product
over its full lifecycle*, but at the S-02 cut the system decomposes cleanly:
(1) traits are rolled and stored, **inert**; (2) the four stats are seeded by a
design choice **independent of traits**; (3) only **Stats→Mood** must actually
compute. Addressing this — rather than the coupled-engine framing — keeps S-02
inside its deferral boundary and prevents pulling S-03/S-04/S-07 logic forward.

## Confidence

- **HIGH** — strong, uncontradicted evidence across PRD/roadmap/research; an
  independent read landed on the same structure; matches in-repo convention; the
  two open couplings the user was unsure about were both resolved against the
  sources.

One genuinely-open item remains for /10x-plan (not a framing gap): the **mood
formula itself**. Its *input set* is settled (the four stats), but the function
is specified by no source — `research.md:178` flags it as the biggest oracle gap
and a **stop-and-ask** candidate if the rule isn't obvious at plan time.

## What Changes for /10x-plan

Plan S-02 as three near-independent tracks, not a coupled engine: **(a)** a
persisted continuous-trait model (shape/range = open plan decision; inert at
hatch); **(b)** stat ranges + hatch initial values (independent of traits);
**(c)** the one live relation — a pure, deterministic, **stats-only**,
**derived-on-read** mood function (formula is the key decision; stop-and-ask if
unobvious) — plus the journal *schema* defined-but-unwritten. Treat any
trait→stat seeding at hatch as an explicitly *optional* flourish (no source
requires it) — adding it introduces a coupling/determinism surface S-02 doesn't
otherwise owe.

## References

- Source files: `context/foundation/prd.md:32,39,60,66,68,72,74,82,94-96,116`;
  `context/foundation/roadmap.md:20,109,117,120-131,170-182`;
  `context/changes/hatch-creature-and-view-stats/research.md:36,43,46-57,156-158,176-179`;
  `tamagotchi_server/migrations/20260521163433251/migration.sql:245`
- Related research: `context/changes/hatch-creature-and-view-stats/research.md`
- Investigation: 3 parallel sub-agents (hatch-time coupling evidence;
  trait-coupling slice ownership; independent S-02 data-model read)
