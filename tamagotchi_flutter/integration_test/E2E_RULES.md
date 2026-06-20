# Patrol E2E Rules (AI-Tamagotchi)

**Read this before generating or editing any patrol e2e test.** It is quality
lever #2 — the rules the agent applies so generated tests are stable by default.
Lever #1 is the worked example next to it: [`seed_test.dart`](seed_test.dart).
Together they are the patrol/Dart translation of the `10x-e2e` skill's
Playwright contract (`.claude/skills/10x-e2e/references/`); the skill's "Other
stacks" clause sanctions exactly this re-encoding. **The principles transfer;
only the syntax changes.**

Patrol drives the **Flutter widget tree**, not a DOM — there is no accessibility
tree, no `getByRole`, no CSS/XPath, no `ensureSemantics()`/ARIA. The finder is
`$`, and "user-facing locator" means **a `Key` or the visible text**.

## The rules block

```
# Patrol E2E Testing Rules

- Locate with a Key or visible text first:
    $(#feedButton)              // Symbol → Key('feedButton')
    $(Key('statRow-Hunger'))    // explicit Key (use when the key isn't a valid Dart symbol, e.g. has a '-')
    $('Feed')                   // visible text
  Never locate by widget Type or tree index — $(ElevatedButton),
  find.byType(...), nth-child-style ancestor chains. With no DOM, the
  widget-tree index IS the brittle selector.
- Each test is independently runnable — its own setup, action, assertion,
  cleanup. No shared state, no ordering assumptions between tests.
- Never wait on a fixed duration. No Future.delayed, no pump(Duration(...)),
  no manual timeouts. Wait for state:
    await $(#feedResponse).waitUntilVisible();   // finder auto-wait
    await $.pumpAndSettle();                      // settle animations/frames
- Assert the business outcome, not a decorative proxy. The control question:
  would this assertion fail if the test-plan risk materialized? If not, delete it.
- Use a unique identifier (timestamp suffix) for test data so re-runs and
  parallel runs never collide; clean up what you create (see "Cleanup").
- Reach the authenticated state once, deterministically — programmatic
  registration via client.emailIdp (the e2e fixed code '12345678') or the
  Phase 3 login-once helper. Don't re-drive sign-up by hand in every test.
- Keep real boundaries real (auth, routing, API, DB). Mock ONLY the server-side
  Mistral call, and only at the runmode seam — never in the browser (see
  "Real vs mocked").
- Name the test after the risk it protects, not test 1 / smoke / works.
```

## Governing rules (the reasoning)

- **Don't generate tests from scratch — start from a risk.** Pick a risk from
  `context/foundation/test-plan.md` that genuinely needs the browser: it crosses
  several boundaries (auth → routing → API → DB) or exists only in the rendered
  UI. If an isolated function (unit) or `withServerpod` (integration) can prove
  it, e2e is the wrong layer. Budget: **1 test per risk, 1–3 per phase.** Protect
  a named risk; never chase coverage.
- **The assertion must fail if the risk comes true.** A title/route check that
  stays green while the data is lost is decorative — assert the actual stat
  value, response, or journal entry.
- **Name the test after the risk:** `'feed mutations survive a page reload'`,
  not `'feed test'`.

## The five anti-patterns (patrol form)

Review every generated test against these. Each has the same root cause: the
model optimizes for "passes now," not "stable tomorrow." When you reject one,
**name it, say why it doesn't protect the risk, and give the replacement** —
never just "fix this test."

1. **Hallucinated assertion** — feeds the creature, reloads, then asserts the
   AppBar still says `'AI-Tamagotchi'`. Passes even if the stat change was lost.
   → Assert the business outcome: the post-feed stat value (`$(Key('statRow-Hunger'))`)
   and the journal/response are still present after the reload.
2. **Brittle selector** — `$(ElevatedButton)` / `find.byType(...)` / "the 3rd row
   in the Column." Breaks on any layout change with the user flow unchanged.
   → A `Key` or visible text: `$(#feedButton)`, `$('Feed')` — the same finders
   the seed uses.
3. **Shared state between tests** — test B assumes test A's user/creature exists.
   Patrol runs each `patrolTest` from a fresh browser; order isn't guaranteed.
   → Each test seeds its own uniquely-identified data and tears it down.
4. **Fixed wait instead of state** — `await Future.delayed(Duration(seconds: 3))`
   after tapping Feed. Green on a fast box, flaky in CI where the stub/API/DB
   round-trip is slower.
   → `await $(#feedResponse).waitUntilVisible();` or `await $.pumpAndSettle();` —
   they auto-retry until the condition holds.
5. **No cleanup** — creates a user/creature and never removes it; second run hits
   the one-creature-per-owner unique index.
   → Unique ids (timestamp) as the primary defense, **plus** teardown of what the
   test created (see below).

## Real vs mocked (the one boundary that matters here)

E2E ≠ zero mocking, but the line is specific to this app:

- **Real:** auth (stateless Serverpod JWT), routing (the auth gate), the API, and
  the **`tamagotchi_test` database**. That is where the cross-boundary integration
  risk lives — mocking it would defeat the test.
- **Mocked:** only the expensive, non-deterministic external call — **Mistral**.
  And it is **not** mocked in the browser. A patrol/`page.route()`-style intercept
  could never reach it: the Mistral call is **server-side**. Instead the **`e2e`
  runmode boots without `mistralApiKey`**, so `llmServiceFor` selects the
  deterministic `StubLlmService` (canned accept/refuse copy). Mock where the
  server actually calls out, not at the browser edge.

## Cleanup

There is **no creature-delete / reset endpoint**. So:

- **Primary defense — unique ids.** Derive every created identifier from
  `DateTime.now().microsecondsSinceEpoch` (unique email → unique user → unique
  creature). Re-runs and parallel runs never collide even with rows left behind.
- **Browser-session teardown** — sign out at the end (`$('Log out').tap()`) so
  the next test starts from a clean session.
- **Row-level teardown** — deleting the seeded user+creature rows from
  `tamagotchi_test` is the job of the Phase 3 `tamagotchi_server/tool/e2e_seed.dart`
  teardown (by unique id), run out-of-process. Don't try to delete rows from
  inside the browser test.

## Finder cheatsheet (Playwright → patrol)

| Playwright | patrol / Dart |
|---|---|
| `getByRole` / `getByLabel` / `getByText` | `$('Feed')` (text), `$(#feedButton)` / `$(Key('statRow-Hunger'))` (key) |
| `getByTestId` fallback | a dedicated `Key('…')` on the widget |
| CSS / XPath / DOM structure — banned | widget Type / tree index — banned (`$(ElevatedButton)`, `find.byType`) |
| `await expect(loc).toBeVisible()` | `await $('…').waitUntilVisible()` / `expect($('…'), findsOneWidget)` |
| `page.waitForTimeout()` — banned | `Future.delayed` / `pump(Duration)` — banned; use `pumpAndSettle()` |
| `page.reload()` | `$.native`/`tester` page reload (Phase 3/4) |
| `storageState` (login once) | programmatic `client.emailIdp` register, or the Phase 3 login-once helper |
| `page.route()` mock of an external API | boot `e2e` runmode without `mistralApiKey` → `StubLlmService` (server-side) |
| unique data + `afterEach` cleanup | timestamp-suffixed ids + sign-out + Phase 3 `e2e_seed.dart` teardown |
| `playwright test <spec>` | `patrol test --target integration_test/<file>.dart -d chrome --web-headless true --web-port 7357 --web-locale en-US` |

## Running

Sidecars (Postgres dev + test) are always up — **never `docker compose up`**.
Boot the API in the e2e identity, then run patrol:

```bash
# tamagotchi_server/ — boots --mode test with TAMAGOTCHI_E2E=true (stub LLM,
# fixed code, API pinned to :8080 against tamagotchi_test)
serverpod run e2e

# tamagotchi_flutter/
patrol test --target integration_test/<file>.dart \
  -d chrome --web-headless true --web-port 7357 --web-locale en-US
```

The Linux-web toolchain pins (Node 24.15.0, `--web-locale en-US`,
`CHROME_EXECUTABLE`) and the `--ipc=host --init` Chromium flags are baked into
the devcontainer; see `context/foundation/lessons.md` and the Phase 6 cookbook
for why each is load-bearing.

## Verify by deliberate break

A test that has never failed proves nothing. After it goes green, **break the
behavior it protects** (e.g. make the feed mutation non-persistent), confirm the
test goes **red**, then revert — never commit the break. A selector change a
healer can re-find is fine to route through review; a *behavior* change that the
test masks is the bug the e2e layer exists to catch.
