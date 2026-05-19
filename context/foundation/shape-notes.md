---
project: "AI-Tamagotchi"
context_type: greenfield
created: 2026-05-19
updated: 2026-05-19  # finalized
checkpoint:
  current_phase: 8
  phases_completed: [1, 2, 3, 4, 5, 6, 7]
  gray_areas_resolved:
    - topic: "pain category"
      decision: "missing capability — no virtual pet ships AI-driven personality today"
    - topic: "insight"
      decision: "two-part: (1) nobody targets adults who want genuine emotional engagement, (2) a structured journal gives the creature real continuity that generic AI memory can't"
    - topic: "primary persona scope"
      decision: "hobbyist niche — virtual-pet enthusiasts and AI-curious tinkerers"
    - topic: "auth strategy"
      decision: "login (email + password or OAuth); flat user model, all users equal"
    - topic: "MVP proof moment"
      decision: "first AI response after hatching — must immediately reflect the creature's unique personality"
    - topic: "timeline"
      decision: "3 weeks after-hours; user confirms realistic"
    - topic: "interaction model (Socrates revision)"
      decision: "Feed/Play/Sleep replaced with Feed/Pet/Cure. Every action costs energy. Personality modifiers on each. Energy gate with pre-written exhausted responses (no AI call). Cure always available."
    - topic: "journal + AI (Socrates revision)"
      decision: "single AI call per interaction generates both user-facing response AND journal prose. Journal is narrative, not raw log."
    - topic: "stat decay (Socrates revision)"
      decision: "real-time decay with floor — stats never drop below minimum threshold. Energy regenerates in real time."
    - topic: "rate limiting (Socrates revision)"
      decision: "moved from FR to NFR — rate limiting is infrastructure, not a user-facing capability"
    - topic: "product type"
      decision: "web-app"
    - topic: "target scale"
      decision: "small (handful of users); domain rule scale-invariant, AI cost is the concern"
    - topic: "timeline"
      decision: "3 weeks after-hours; hard deadline 2026-06-30"
    - topic: "advanced memory"
      decision: "door left open — not a non-goal, captured as open question"
  frs_drafted: 11
  quality_check_status: accepted
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

The insight is two-part. First, virtual pet makers optimize for kids and casual play — nobody has aimed this at adults who want genuine emotional engagement with a unique creature. Second, most AI chat products are stateless or use generic memory. A structured journal — a first-class record of every interaction and state change — gives the creature real continuity. That is the missing piece that makes personality sticky rather than amnesiac.

## User & Persona

### Primary persona

A hobbyist in the virtual-pet-enthusiast or AI-curious-tinkerer space. Someone who grew up with Tamagotchi or Neopets, found them hollow, and wants a creature that feels genuinely alive — not a clickable stat dashboard. They care about the creature's personality emerging over time and would notice (and value) that two creatures respond differently to the same care.

## Success Criteria

### Primary
- Character is recognizable: in a blind test, a user correctly identifies the creature's dominant trait from its AI responses alone in at least 80% of cases.
- Character genuinely affects gameplay: two creatures with opposite traits, given an identical sequence of care, end with measurably different stats and mood.

### Secondary
- Journal feels like a story: reading back the journal of a week of interactions feels like a coherent narrative about a specific creature, not a random log of events.

### Guardrails
- AI responses stay in-character: the creature never breaks character — no generic chatbot answers, no safety disclaimers leaking through, no personality drift within a session.
- Stats are deterministic given inputs: same personality traits + same care sequence = same stat and mood values. AI adds flavor to responses, not randomness to core mechanics.

## User Stories

### US-01: User hatches a creature and gets a personality-driven response

- **Given** a logged-in user with no creature
- **When** they hatch a new creature and Feed it for the first time
- **Then** they receive an AI-generated response that reflects the creature's unique personality traits, and the journal gains a narrative prose entry describing the interaction

#### Acceptance Criteria
- Creature personality traits are visibly randomized (not all creatures are the same)
- AI response references at least one personality trait's influence (e.g., a picky creature complains about the food; a gluttonous creature is delighted)
- A single AI call produces both the user-facing response and the journal entry prose
- Journal entry includes: timestamp, interaction type, stat changes, and narrative prose

## Functional Requirements

### Account & Creature Lifecycle
- FR-001: User can register an account and log in. Priority: must-have
  > Socrates: No counter-argument; stands as written. Auth is necessary for persistent creatures and the journal.
- FR-002: User can hatch a new creature with randomized personality traits (continuous values). Priority: must-have
  > Socrates: Counter-argument considered: "full randomization risks unplayable trait combos (e.g., all-max or all-min)." Resolution: kept as-is for MVP; risk acknowledged — may need trait constraints or reroll if testing reveals degenerate combos.
- FR-010: User can reset their creature (deletes all creature data and journal; allows hatching a new one). Priority: must-have
  > Socrates: No counter-argument; stands as written. Reset is needed since there is one creature per account.

### Stats & Mood
- FR-003: User can view creature's current stats (hunger, energy, love, illness) and derived mood. Priority: must-have
  > Socrates: Counter-argument considered: "visible stats reduce the creature to a dashboard — exactly the problem this product solves." Resolution: kept for MVP; AI responses are the personality layer, stats are the mechanical layer. Risk recorded for v2 UX refinement (expressive display instead of raw numbers).
- FR-008: Stats change in real time at personality-driven rates (including while the user is away); stats never drop below a minimum floor. Energy regenerates in real time. Priority: must-have
  > Socrates: Counter-argument considered: "real-time decay creates guilt, not engagement — coming back to a starving creature feels punishing." Resolution: revised — added a stat floor so the creature gets sad but never reaches an unrecoverable state. Guilt is capped.

### Interactions
- FR-004: User can Feed the creature (reduces hunger; costs energy; validated — can't feed a full creature; personality modifier — a picky creature won't always accept food). Priority: must-have
  > Socrates: Counter-argument considered: "cooldowns punish engaged users." Resolution: revised — replaced cooldown model with energy-cost model. Interactions are gated by energy, not timers. Engaged users can interact freely until energy runs out.
- FR-005: User can Pet the creature (increases love; costs energy; personality modifier — an introvert responds less to intense petting than an extravert). Priority: must-have
  > Socrates: Counter-argument considered: "Play is indistinct from Feed without richer interaction." Resolution: revised — Play replaced by Pet (love stat). Personality modifiers make each interaction feel distinct per creature.
- FR-006: User can Cure the creature (treats illness; always available regardless of energy level). Priority: must-have
  > Socrates: Counter-argument considered: "Sleep is passive — an absence, not an interaction." Resolution: revised — Sleep removed entirely; replaced by Cure (illness). Cure is always available, even at zero energy, making it the emergency interaction.
- FR-007: At empty energy, all interactions except Cure are blocked; the creature returns one of a few pre-written "exhausted" responses with no AI call. Priority: must-have
  > Socrates: Derived from the interaction model revision. Energy gate protects the AI endpoint and creates a natural pacing rhythm.

### AI Responses & Journal
- FR-009: A single AI call per interaction generates both the creature's user-facing response and a journal entry prose. The AI is fed: interaction details, current stats, character traits, and last N journal entries. Priority: must-have
  > Socrates: Counter-argument considered (from FR-007 old): "raw log isn't a journal — it's a database dump." Resolution: revised — journal entries are now narrative prose generated alongside the AI response in a single call. Also addresses latency concern (FR-008 old) by keeping it to one call, not two.
- FR-011: User can read the creature's journal (narrative prose entries generated alongside each AI response, plus state change records). Priority: must-have
  > Socrates: Counter-argument considered: "nobody reads logs in games." Resolution: revised — journal is now narrative, not raw data. Satisfies the "journal feels like a story" secondary success criterion.

## Business Logic

The creature reacts to every interaction based on its innate personality traits and its accumulated history of care, producing AI responses and stat changes that no other creature with different traits or a different history would produce.

The rule consumes four inputs: the creature's personality traits (randomized at hatching as continuous values), the current stat values (hunger, energy, love, illness), the type of interaction performed (Feed, Pet, or Cure), and the recent journal entries (last N narrative records). From these, it produces a personality-colored AI response to the user, a narrative journal entry, and modified stat values with personality-driven modifiers applied.

The user encounters this rule every time they interact. A picky creature that was recently overfed responds differently from a gluttonous creature seeing food for the first time. An introverted creature that has been petted five times in a row reacts differently from an extraverted one. The journal accumulates, so the creature's tenth response carries the weight of the nine before it.

## Non-Functional Requirements

- A user perceives the creature's response within 5 seconds of triggering an interaction, with continuous visible progress (streaming or animation) during the wait.
- The energy-cost mechanic is the primary interaction throttle; explicit rate limiting exists only as a safety net against bugs or abuse, not as a user-facing constraint.

## Access Control

Login via email + password or OAuth. Flat user model — all accounts are equal, no admin role, no special permissions. Each user owns their creature(s) and can only see and interact with their own.

## Non-Goals

- No social features: no Bluesky integration, no park, no creature matchmaking, no creature-to-creature interaction. This is a single-creature, single-user experience. Rationale: social features require multi-creature infrastructure that doesn't exist yet.
- No visual evolution or permadeath: the creature does not visually change over time, cannot die, and has no long-term progression systems beyond personality and journal. Rationale: long-term mechanics require months of play data to tune; MVP proves personality, not progression.
- No mobile apps: Flutter Web only. No native iOS or Android builds. Rationale: web covers the hobbyist audience; native builds are post-validation.
- No speech synthesis: no ElevenLabs integration, no creature voice. Rationale: audio adds a full production pipeline (voice design, latency, streaming) that doesn't prove the personality hypothesis.
- No multiple creatures per account: one creature at a time, with reset to start over. Rationale: multiple creatures dilute emotional investment and complicate the UI.

## Open Questions

1. **Trait constraint guardrails** — Should randomization have constraints to prevent degenerate combos (all-max, all-min)? Owner: user. Acknowledged risk from Socrates round; no constraint for MVP, but may need tuning.
2. **Stat display design** — Raw numbers vs. expressive display (mood icons, text descriptions). Kept as raw numbers for MVP; risk that this feels like a dashboard. Owner: user. Resolution: v2.
3. **Advanced memory (RAG / vector DB)** — Door deliberately left open. Current design uses last N journal entries; semantic search over full history may be explored during implementation if time allows. Owner: user.
4. **What is N in "last N journal entries"?** — The AI context window for generating responses. Not yet decided. Owner: user. Depends on token budget and model context limits.
5. **AI cost at scale** — Domain rule doesn't change at 100x users, but AI API cost scales linearly. Not a concern at MVP scale (handful of users), but needs watching. Owner: user.

## Quality cross-check

All 6 greenfield elements present. Status: accepted.

- Access Control: present
- Business Logic (one-sentence rule): present
- Project artifacts: present
- Timeline-cost acknowledged: present (3 weeks ≤ 3)
- Non-Goals: present (5 entries)
- Preserved behavior: n/a (greenfield)

## Forward: tech-stack

User-volunteered stack preferences (not part of PRD — for downstream tech-stack-selector):
- AI model: Mistral (for generating creature responses)
- Frontend: Flutter Web
- Integration aspirations (post-MVP): Bluesky, ElevenLabs speech synthesis
- Scale note: domain rule is scale-invariant; AI cost is the scaling concern
