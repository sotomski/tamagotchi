---
project: "AI-Tamagotchi"
version: 1
status: draft
created: 2026-05-19
context_type: greenfield
product_type: web-app
target_scale:
  users: small
  qps: low
  data_volume: small
timeline_budget:
  mvp_weeks: 3
  hard_deadline: 2026-06-30
  after_hours_only: true
---

## Vision & Problem Statement

Classic virtual pets respond from the same script and are indistinguishable from one another. Interaction reduces to clicking on stat bars — there is no sense of caring for a living creature with a character of its own. This is a missing capability: no virtual pet product today ships AI-driven personality that makes each creature genuinely unique.

The insight is two-part. First, virtual pet makers optimize for kids and casual play — nobody has aimed this at adults who want genuine emotional engagement with a unique creature. Second, most AI chat products are stateless or rely on generic memory. A structured journal — a first-class record of every interaction and state change — gives the creature real continuity. That is the missing piece that makes personality sticky rather than amnesiac.

## User & Persona

A hobbyist in the virtual-pet-enthusiast or AI-curious-tinkerer space. Someone who grew up with Tamagotchi or Neopets, found them hollow, and wants a creature that feels genuinely alive — not a clickable stat dashboard. They care about the creature's personality emerging over time and would notice (and value) that two creatures respond differently to the same care.

## Success Criteria

### Primary
- Character is recognizable: in a blind test, a user correctly identifies the creature's dominant personality trait from its responses alone in at least 80% of cases.
- Character genuinely affects gameplay: two creatures with opposite traits, given an identical sequence of care, end with measurably different stats and mood.

### Secondary
- Journal feels like a story: reading back a week of journal entries feels like a coherent narrative about a specific creature, not a random log of events.

### Guardrails
- AI responses stay in character: the creature never breaks character — no generic chatbot answers, no safety disclaimers leaking through, no personality drift within a session.
- Stats are deterministic given inputs, with one deliberate exception — the feed-acceptance gate: the same personality traits plus the same care sequence produce the same stat and mood values, *except* whether a given feed is accepted or refused, which is a random roll weighted by the creature's pickiness trait and current hunger (a hungrier creature is less likely to refuse). This randomness is confined to the accept/refuse decision; once a feed is accepted its stat magnitudes are fully deterministic, and Pet/Cure remain entirely deterministic. AI prose adds flavor, never stat randomness. (Rationale: FR-004's "a picky creature won't always accept food" requires genuine variability in the gate; the roll is reproducible under a seeded RNG for testing.)

## User Stories

### US-01: User hatches a creature and gets a personality-driven response

- **Given** a logged-in user with no creature
- **When** they hatch a new creature and Feed it for the first time
- **Then** they receive an AI-generated response that reflects the creature's unique personality traits, and the journal gains a narrative prose entry describing the interaction

#### Acceptance Criteria
- Creature personality traits are visibly randomized (not all creatures behave the same way).
- The creature's response references at least one personality trait's influence (e.g., a picky creature complains about the food; a gluttonous creature is delighted).
- The user-facing response and the journal entry are produced together as a coherent pair shaped by the same inputs.
- Each journal entry shows when the interaction happened, which interaction it was, how the stats changed, and a narrative prose paragraph.

## Functional Requirements

### Account & Creature Lifecycle
- FR-001: User can register an account and log in. Priority: must-have
  > Socratic: No counter-argument; stands as written. Auth is necessary for persistent creatures and the journal.
- FR-002: User can hatch a new creature with randomized personality traits (continuous values). Priority: must-have
  > Socratic: Counter-argument considered: "full randomization risks unplayable trait combos (e.g., all-max or all-min)." Resolution: kept as-is for MVP; risk acknowledged — may need trait constraints or reroll if testing reveals degenerate combos.
- FR-010: User can reset their creature, deleting all creature data and journal and allowing them to hatch a new one. Priority: must-have
  > Socratic: No counter-argument; stands as written. Reset is needed since there is one creature per account.

### Stats & Mood
- FR-003: User can view the creature's current stats (hunger, energy, love, illness) and derived mood. Priority: must-have
  > Socratic: Counter-argument considered: "visible stats reduce the creature to a dashboard — exactly the problem this product solves." Resolution: kept for MVP; AI responses are the personality layer, stats are the mechanical layer. Risk recorded for v2 UX refinement (expressive display instead of raw numbers).
- FR-008: Stats change in real time at personality-driven rates (including while the user is away), and never drop below a minimum floor. Energy regenerates in real time. Priority: must-have
  > Socratic: Counter-argument considered: "real-time decay creates guilt, not engagement — coming back to a starving creature feels punishing." Resolution: revised — added a stat floor so the creature gets sad but never reaches an unrecoverable state. Guilt is capped.

### Interactions
- FR-004: User can Feed the creature; feeding reduces hunger, costs energy, is rejected when the creature is already full, and is affected by a personality modifier (a picky creature won't always accept food). Priority: must-have
  > Socratic: Counter-argument considered: "cooldowns punish engaged users." Resolution: revised — replaced the cooldown model with an energy-cost model. Interactions are gated by energy, not timers. Engaged users can interact freely until energy runs out.
- FR-005: User can Pet the creature; petting increases love, costs energy, and is affected by a personality modifier (an introvert responds less to intense petting than an extravert). Priority: must-have
  > Socratic: Counter-argument considered: "Play is indistinct from Feed without richer interaction." Resolution: revised — Play replaced by Pet (love stat). Personality modifiers make each interaction feel distinct per creature.
- FR-006: User can Cure the creature; Cure treats illness and is always available regardless of energy level. Priority: must-have
  > Socratic: Counter-argument considered: "Sleep is passive — an absence, not an interaction." Resolution: revised — Sleep removed entirely; replaced by Cure (illness). Cure is always available, even at zero energy, making it the emergency interaction.
- FR-007: At empty energy, all interactions except Cure are blocked, and the creature returns one of a small set of pre-written "exhausted" responses. Priority: must-have
  > Socratic: Derived from the interaction model revision. The energy gate creates a natural pacing rhythm and bounds the cost of personality-generated responses.

### AI Responses & Journal
- FR-009: Each interaction produces both a creature response to the user and a journal entry, generated together as a coherent pair shaped by the same inputs: the interaction performed, the creature's current stats, its personality traits, and the most recent journal entries. Priority: must-have
  > Socratic: Counter-argument considered (from the prior journal FR): "raw log isn't a journal — it's a database dump." Resolution: revised — journal entries are now narrative prose produced alongside the creature response in a single coherent step. This also addresses the latency concern (response and journal arrive together rather than as two separate operations).
- FR-011: User can read the creature's journal, which contains the narrative prose entries produced alongside each interaction plus the state changes that occurred. Priority: must-have
  > Socratic: Counter-argument considered: "nobody reads logs in games." Resolution: revised — the journal is now narrative, not raw data. Satisfies the "journal feels like a story" secondary success criterion.

## Non-Functional Requirements

- A user perceives the creature's response within 5 seconds of triggering an interaction, with continuous visible progress during the wait.
- Within normal play, interaction frequency is bounded by the in-game energy mechanic; engaged users do not encounter additional access caps. An outer safety net protects against abusive or runaway usage but is invisible during legitimate play.

## Business Logic

The creature reacts to every interaction based on its innate personality traits and its accumulated history of care, producing AI responses and stat changes that no other creature with different traits or a different history would produce.

The rule consumes four inputs: the creature's personality traits (randomized at hatching as continuous values), the current stat values (hunger, energy, love, illness), the type of interaction performed (Feed, Pet, or Cure), and the recent journal entries (the last N narrative records). From these, it produces a personality-colored response to the user, a narrative journal entry, and modified stat values with personality-driven modifiers applied.

The user encounters this rule every time they interact. A picky creature that was recently overfed responds differently from a gluttonous creature seeing food for the first time. An introverted creature that has been petted five times in a row reacts differently from an extraverted one. The journal accumulates, so the creature's tenth response carries the weight of the nine before it.

## Access Control

Each user owns their own creature and journal and can only see and interact with their own. The account model is flat — all accounts are equal, with no admin role and no special permissions. Authenticated users reach the main game surface; unauthenticated visitors are routed to sign-up / sign-in.

Sign-in supports a single pathway: email + password. Users explicitly register an account (sign up), then sign in with those credentials. There is no third-party / OAuth sign-in.

## Non-Goals

- **No social features.** No social-network integration, no shared "park" space for creatures, no creature matchmaking, no creature-to-creature interaction. This is a single-creature, single-user experience. Rationale: social features require multi-creature infrastructure that doesn't exist yet, and dilute the personality hypothesis the MVP is trying to prove.
- **No visual evolution or permadeath.** The creature does not visually change over time, cannot die, and has no long-term progression systems beyond personality emergence and the journal. Rationale: long-term mechanics require months of play data to tune; MVP proves personality, not progression.
- **No native mobile apps.** The MVP ships as a web experience only — no native iOS or Android builds. Rationale: web covers the hobbyist audience for validation; native builds are post-validation.
- **No speech synthesis.** No creature voice, no audio output. Rationale: audio adds a full production pipeline (voice design, latency, streaming) that doesn't prove the personality hypothesis.
- **No multiple creatures per account.** One creature at a time, with Reset to start over. Rationale: multiple creatures dilute emotional investment and complicate the UI.

## Open Questions

1. **Trait constraint guardrails** — Should personality randomization have constraints to prevent degenerate combinations (all-max, all-min)? No constraint for MVP; risk acknowledged. May need tuning if play-testing surfaces unplayable creatures. Owner: user.
2. **Stat display design** — Raw numeric stats vs. expressive display (mood icons, text descriptions). Kept as raw numbers for MVP; risk that this feels like a dashboard, undercutting the core experience. Owner: user. Resolution target: v2.
3. **Long-term memory architecture** — Door deliberately left open. The current design uses the last N journal entries as recent context; semantic search over full journal history may be explored during implementation if time allows. Owner: user.
4. **What is N in "last N journal entries"?** — The size of the recent-history window the personality response is shaped by. Not yet decided; depends on cost and capability trade-offs of the chosen approach. Owner: user.
5. **Cost scaling** — The domain rule is scale-invariant, but the per-interaction cost of generating personality-colored responses scales linearly with usage. Not a concern at MVP scale (handful of users); needs watching as usage grows. Owner: user.
