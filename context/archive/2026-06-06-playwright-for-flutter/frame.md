# Frame Brief: Flutter web e2e — patrol + marionette to hit the M3L4 contract

> Framing step before /10x-plan. This document captures what is *actually*
> at issue, separated from what was initially assumed.

## Reported Observation

The next lesson in the 10xDevs curriculum (Lesson 4) is about Playwright e2e
tests. A `10x-e2e` skill is referenced as the scope-setter, but it does not
yet exist in `.claude/skills/`. The test-plan (§4 Stack) explicitly excludes
e2e: *"not planned for this rollout — energy-gated, single-user web app;
integration (real DB) is the top layer here."*

## Initial Framing (preserved)

- **User's stated cause or approach**: Following the curriculum sequence — Lesson 4 is about Playwright for e2e tests.
- **User's proposed direction**: Add Playwright e2e tests to the Flutter web app.
- **Pre-dispatch narrowing**: Purpose = curriculum exercise on this codebase (test-plan's e2e exclusion is NOT being revised). Target = whatever the `10x-e2e` skill prescribes.

## Dimension Map

Two separate questions here, and conflating them is the trap I fell into:
**(A) what TOOL drives a Flutter web app** and **(B) what QUALITY CONTRACT the
resulting tests must satisfy**. The lesson (M3L4) is the source of (B); it
*assumes* Playwright for (A) because the generic curriculum targets DOM web
apps. For a Flutter web (CanvasKit) app, (A) is answered differently.

The observation could originate at any of these dimensions:

1. **patrol** (the right TOOL for A) — purpose-built Flutter e2e framework; Dart finder API (`$(...)`, by key/semantic label); on web it spins up Chromium via an internal Playwright bridge, so you get the same browser automation without writing TypeScript or hand-piercing the `flt-glass-pane` shadow DOM. CI-ready (`--web-headless`). Authoring stays consistent with the existing Dart test suite. ← **leading hypothesis**
2. **marionette_flutter** (AI exploration assist for A) — drives a live debug Flutter app via VM Service through an MCP server (`tap`, `enter_text`, `scroll_to`, `screenshot`). Claude Code uses it to explore the running app and map interaction paths, then writes patrol tests from real observation — the Flutter-native analogue of the lesson's "Playwright CLI/planner explores the app" step.
3. **Raw Playwright CLI/MCP** (the lesson's default TOOL) — works on Flutter web ONLY via the `flt-semantics` ARIA layer: requires `ensureSemantics()` in `main.dart`, `Semantics` annotations on every interactive widget, and shadow-DOM piercing in every selector, all authored in TypeScript foreign to the Dart suite. High-friction for no gain when patrol wraps the same Chromium internally. REJECTED as the authoring surface.
4. **The M3L4 quality contract** (the answer to B — the *target*, not a tool) — risk-driven test selection from `test-plan.md`, a seed test that models good tests, an E2E rules file, the five anti-patterns review, VERIFY-by-deliberate-breaking, real internal boundaries + mocked external APIs, E2E in CI not per-edit. Tool-agnostic by the lesson's own optional task ("Another stack... the principles transfer, the syntax changes").
5. **Flutter MCP server / integration_test** — Flutter MCP exposes widget-tree introspection only (no tap/type, not a test runner). `integration_test` is in-process widget testing, a different layer. Neither is the e2e tool here.

## Hypothesis Investigation

| Hypothesis | Evidence | Verdict |
| --- | --- | --- |
| **patrol is the right TOOL** | v4.6.1, 698 likes, 332k DLs, leancode.co, Apache-2.0; Dart 3.8+ (Flutter 3.44 ships it — compatible); web mode auto-installs Node.js + Playwright/Chromium and bridges to it; Dart finder API matches the existing test suite; headless CI mode documented. Hides the CanvasKit shadow-DOM problem entirely. | **STRONG** |
| marionette as AI exploration assist | leancode.co (same team as patrol), v0.5.0; MCP server drives debug builds (`tap`/`enter_text`/`screenshot`); Flutter web listed as supported. Replaces the lesson's Playwright-CLI exploration step with a Flutter-native one. Dev-time only — no assertions/CI. | **STRONG (for its role)** |
| Raw Playwright is the right TOOL | On Flutter CanvasKit: needs `ensureSemantics()` + `Semantics` annotations + shadow-DOM piercing + TypeScript. patrol wraps the same Playwright/Chromium with none of that overhead. The lesson assumes Playwright only because it targets generic DOM apps; its own optional task sanctions swapping the stack. | REJECTED |
| The M3L4 contract is Playwright-specific | The lesson's optional task explicitly supports Cypress/WebdriverIO/Selenium and "No UI" API scenarios: *"rewrite the rules and test seed using the idioms of your tool. The principles transfer, the syntax changes."* The contract is the target; the tool is swappable. | The contract is the TARGET, tool-agnostic |
| Flutter MCP server / integration_test are the e2e tool | Flutter MCP = introspection only, no UI driving. integration_test = in-process, different layer. | NONE |

## Narrowing Signals

- User confirmed this is a **curriculum exercise** (pedagogical, not a test-plan amendment) — scope stays bounded.
- User confirmed **target is whatever the `10x-e2e` skill prescribes** — but that skill doesn't exist in `.claude/skills/`. As a `10x-*` skill it comes from the 10xDevs curriculum (committed directly, not fetched via `skills get`). Either it was not committed with the lesson materials, or it needs to be authored here as part of the lesson.
- Both patrol and marionette are published by **leancode.co** — they are complementary, same-team tools. User pushed back on the "marionette: ruled out" verdict (valid — see revised Cross-System Convention below).
- **Marionette + patrol workflow**: marionette (via MCP, connected to a debug Flutter build) can be used by Claude Code to explore the running app, screenshot widget states, and understand interaction paths — then author patrol tests from that observation. Patrol is the CI execution layer; marionette is the development-time exploration assist.

## Cross-System Convention

Flutter's own docs recommend `integration_test` or a framework built on it (such as patrol) for Flutter app testing. Raw Playwright is a web-first browser automation tool that works with Flutter web only via the semantic accessibility layer — it works, but it is not the path Flutter's ecosystem has converged on. Patrol is the ecosystem's answer to "I want browser-level e2e on Flutter web, written in Dart."

**Revised marionette verdict**: marionette is not a CI test runner (that verdict stands), but it IS a valid development-time exploration tool when Claude Code needs to understand a live Flutter app's widget tree before writing patrol tests. The marionette MCP server, connected to a debug build of the app, lets an AI agent navigate, screenshot, and map the UI — generating patrol test sketches from real observation rather than guesswork. This is an AI-native test-authoring workflow that pairs naturally with the lesson context.

## Lesson Contract → patrol/marionette Mapping (the "similar results" target)

The M3L4 lesson defines *what good E2E looks like*. We achieve the same
outcomes with Flutter-native tools instead of raw Playwright. The principles
transfer; the syntax changes (exactly as the lesson's optional task allows).

| M3L4 concept (Playwright) | patrol/marionette equivalent for this project |
| --- | --- |
| Agent sees app via accessibility tree (YAML snapshot, `getByRole`) | marionette drives the live widget tree via VM Service; patrol's finder API selects by **key / semantic label**, not by widget index |
| Playwright CLI / planner explores the app | **marionette MCP**: Claude Code navigates the debug build, screenshots, maps interaction paths — then writes the patrol test |
| `seed.spec.ts` (TypeScript) | a **seed patrol test in Dart** that models the conventions below |
| E2E rules: `getByRole` over CSS/XPath | prefer **semantic finders / `Key`s** over brittle widget-tree indices or `byType` |
| E2E rules: wait-for-state not `waitForTimeout` | `await tester.pumpAndSettle()` / wait-for-condition, never fixed delays |
| E2E rules: unique ids + cleanup | unique data per run (e.g. timestamped names) + reset/teardown — pairs with FR-010 creature Reset |
| `storageState` (login once, reuse `auth.json`) | log in once, reuse the **Serverpod session** across tests; the two dedicated auth scenarios stay independent |
| Mock external API at HTTP layer (OpenRouter) | mock **Mistral** at the HTTP layer; keep real auth + Serverpod + DB |
| Five anti-patterns review | same five, mapped to patrol: naive assertion, fragile selector (widget index vs semantic finder), shared state, fixed wait, no cleanup |
| VERIFY by deliberate breaking | break the risk behavior in server/client, confirm the patrol test goes red, revert without committing |
| E2E in CI not per-edit | `patrol test --device chrome --web-headless` in CI, alongside the existing pipeline |
| `/10x-e2e` skill (Playwright references) | **adapt the skill's `references/`** (seed pattern, rules, anti-patterns, prompt template) to patrol/Flutter idioms — the lesson's explicit "customize to your context / another stack" optional task |

## Reframed (or Confirmed) Problem Statement

> **The actual problem to plan around is**: Achieve the M3L4 E2E quality contract on this Flutter web app using **patrol** (the Dart-native test runner / CI execution layer) and **marionette** (the AI-agent exploration assist), and adapt the installed `/10x-e2e` skill's references from Playwright idioms to patrol/Flutter idioms — *not* by writing raw Playwright tests against the CanvasKit shadow DOM.

The initial framing ("add Playwright e2e") was **correct in intent, wrong in tool**. The lesson is the source of the *target* (risk-driven tests, seed + rules, anti-patterns, VERIFY-by-breaking, E2E-in-CI) — not a mandate to use Playwright on a stack where it fights the renderer. Raw Playwright on Flutter web needs `ensureSemantics()` + `Semantics` annotations + shadow-DOM piercing + TypeScript; patrol delivers the same browser automation in Dart, and marionette gives Claude Code a Flutter-native way to explore the app before authoring tests.

## Confidence

**HIGH** — patrol has strong evidence (mature pub.dev package, internal Playwright/Chromium bridge, Dart API, Flutter 3.44 compatible) and matches Flutter ecosystem convention. The lesson's own optional task confirms the contract is tool-agnostic. marionette is confirmed for the exploration role. Raw Playwright is rejected as the authoring surface with specific evidence (CanvasKit shadow-DOM friction). Flutter MCP / integration_test ruled out.

## What Changes for /10x-plan

Target tools: **patrol** (CI test runner, Dart) + **marionette** (AI exploration assist), achieving the **M3L4 quality contract** — NOT raw Playwright.

Open scope questions the plan must resolve (raised by the user, answered at frame level below in References / and to be detailed in the plan):

1. **Foundation doc updates** — `tech-stack.md` (add patrol + marionette to the test layer with `checked:` dates) and `test-plan.md` need revision: §4 Stack currently says `e2e: none` (line 123) — this flips to `e2e: patrol`; §3 gains an E2E rollout phase (or a note that the curriculum exercise hardens existing S-03 risks at the browser level); §6 gets a new cookbook subsection. The exclusion in §7 ("e2e: none") is superseded.
2. **How the patrol/marionette strategy is documented** — primarily by adapting the installed `/10x-e2e` skill's `references/` (seed pattern, rules, anti-patterns, prompt template) to patrol/Flutter idioms; secondarily a short note in `tech-stack.md` and the `test-plan.md` cookbook (§6).
3. **Devcontainer configuration** — patrol web mode needs Node.js + Playwright + a Chromium browser installed in the devcontainer; **headless** is the CI default. A **headed** browser is not needed for CI, but **screenshots are valuable** for marionette-driven exploration and as patrol failure evidence — so install Chromium with screenshot capability even though runs are headless. `patrol_cli` is a global Dart tool. Confirm scloud/devcontainer can run a headless browser (CPU/memory) before committing.

First plan step: install `10x-e2e` skill in the devcontainer (`! npx @przeprogramowani/10x-cli@latest get m3l4` — it currently lives only on the host volume, invisible to the devcontainer), read its `SKILL.md` + `references/`, then plan the patrol/marionette adaptation.

## References

- patrol: https://pub.dev/packages/patrol — v4.6.1, leancode.co, Apache-2.0 — **chosen TOOL** (CI test runner; internal Playwright/Chromium bridge for web)
- marionette_flutter: https://pub.dev/packages/marionette_flutter — v0.5.0, leancode.co — **chosen ASSIST** (AI-agent exploration via MCP on debug builds)
- Raw Playwright: https://playwright.dev/agent-cli/introduction — the lesson's default tool; REJECTED here (CanvasKit shadow-DOM friction); still the runtime *under* patrol's web bridge
- Flutter MCP server: https://docs.flutter.dev/ai/mcp-server — widget tree introspection, not a UI driver (not applicable)
- Flutter web accessibility: https://docs.flutter.dev/ui/accessibility/web-accessibility — `flt-semantics` layer, the reason raw Playwright is high-friction
- M3L4 lesson contract: risk-driven E2E, seed test, rules, five anti-patterns, VERIFY-by-breaking, E2E-in-CI (the tool-agnostic *target*)
- Installed skill (host only, not yet in devcontainer): `10x-e2e` — SKILL.md + 5 references (seed pattern, rules, anti-patterns, prompt template, browser-driven generation)
- Existing skill: `.claude/skills/flutter-add-integration-test/SKILL.md` (in-process, different layer)
- Test plan §4 Stack: `context/foundation/test-plan.md:123` ("e2e: none" → flips to patrol); §7 exclusion superseded
- CLAUDE.md lesson boundary: e2e = Lesson 4 (M3L4)
