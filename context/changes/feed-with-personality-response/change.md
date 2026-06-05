---
change_id: feed-with-personality-response
title: Feed the creature once and get a personality-driven response + journal entry (NORTH STAR)
status: implemented
created: 2026-06-05
updated: 2026-06-05
archived_at: null
---

## Notes

S-03 from `context/foundation/roadmap.md` — the **north star** slice: the smallest
end-to-end slice that, if it ships and works, proves the product's core hypothesis
(AI-driven personality + a structured journal makes a virtual pet feel uniquely alive).

Outcome: user Feeds the creature; receives a personality-shaped, in-character AI
response; the journal gains a narrative prose entry produced in the same call; stats
update per FR-004's energy-cost + personality-modifier rules.

- PRD refs: US-01, FR-004, FR-009, FR-011
- Prerequisites: S-02 (`hatch-creature-and-view-stats`, implemented). **F-02
  (`llm-client-prompt-surface`) is FOLDED INTO this slice (decided 2026-06-05)** — this
  change builds the server-side LLM client + prompt surface itself, behind an
  `LlmService` interface so the deterministic layer is testable against a stub.

### Decisions (2026-06-05)
- **LLM provider = Mistral AI**, model `mistral-small-2603` (Mistral Small 4). REST
  `POST https://api.mistral.ai/v1/chat/completions`, `Authorization: Bearer`, secret
  `mistralApiKey`, dev run-mode stub. Structured output via
  `response_format:{type:"json_schema"}`. See `research.md` §B + follow-up.
- **Pickiness is RANDOM** — "not accepting food HAS TO BE RANDOM based on an appropriate
  creature's trait and hunger." Adds a `picky` trait to `CreaturePersonality`, rolled at
  hatch; accept/reject is `P(reject)=f(picky,hunger)` against a (seedable) RNG. PRD
  guardrail amended to record this scoped exception. Reproducible under a seeded
  `Random` for tests.
- **F-02 folded in** (see Prerequisites above).

- Unknowns: streaming vs single-block response — NFR-1 wants "continuous visible
  progress during the wait"; decide stream-tokens vs loading animation at `/10x-plan`
  time. Pickiness probability curve + `picky` trait range — decided-random; exact form
  at `/10x-plan` time.
- Risk: the riskiest assumption (that AI responses feel uniquely in-character given the
  chosen prompt + model + memory window) is tested here. Folding F-02 in widens the
  slice (LLM wiring + Feed + random gate); mitigated by the `LlmService` interface +
  seeded-RNG seam. Mitigation: scope to one interaction (Feed) only; defer Pet / Cure /
  empty-energy to follow-on slices so the prompt + response shape can iterate without
  coupling.
