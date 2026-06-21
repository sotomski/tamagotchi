<!-- IMPL-REVIEW-REPORT -->
# Implementation Review: Frontend state-mgmt + routing scaffold (F-01)

- **Plan**: context/changes/frontend-state-mgmt-routing-scaffold/plan.md
- **Scope**: Phases 1–2 of 2 (full plan)
- **Date**: 2026-05-30
- **Verdict**: NEEDS ATTENTION
- **Findings**: 0 critical, 2 warnings, 4 observations

## Verdicts

| Dimension | Verdict |
|-----------|---------|
| Plan Adherence | WARNING |
| Scope Discipline | WARNING |
| Safety & Quality | WARNING |
| Architecture | PASS |
| Pattern Consistency | PASS |
| Success Criteria | PASS |

Overall: **NEEDS ATTENTION** — application code is a clean, faithful match to the plan
(Changes Required items 3–12 all MATCH) and every automated criterion passes
(`flutter analyze` exit 0, `flutter test` pass, screens/ removed, greps clean — all re-verified
during this review). Two substantive warnings warrant a conscious decision: a quality gate that
does not actually run (F1) and scope creep into the server package (F2).

### Verified clean (no findings)

Group-by-feature layout (lib/app/ is a sanctioned cross-cutting shell dir); `@Riverpod(keepAlive: true)`
providers correct; GoRouter constructed once via provider; throwing providers reached only via root
overrides; `.g.dart` committed not gitignored; widget test boots with no override as designed;
`lib/screens/` fully removed; global `Client` + `'../main.dart'` imports gone; auth listener
add/remove uses the same method reference (no leak); post-frame `context.go` is `mounted`-guarded.

## Findings

### F1 — riverpod_lint quality gate is inert under CLI analysis (toolchain limitation)

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Safety & Quality
- **Location**: analysis_options.yaml:1-2 (workspace-root plugins block)
- **Detail**: riverpod_lint never actually lints the flutter package under `flutter analyze` /
  `dart analyze`, so the quality gate Phase 1 step 2 set out to establish does not function for CLI/CI.
  The "flutter analyze exits 0" success criterion passes but provides zero riverpod-specific coverage.

  **Root cause — corrected after investigation (NOT an implementer error):** riverpod_lint 3.x uses the
  native `analysis_server_plugin` mechanism (Dart 3.10+; this toolchain is Dart 3.12 / Flutter 3.44). In
  a pub workspace the analyzer accepts a `plugins:` block ONLY in the workspace-root analysis_options.yaml
  — declaring it in the member `tamagotchi_flutter/analysis_options.yaml` triggers `plugins_in_inner_options`
  and is ignored. The implementation placed it at the workspace root, i.e. the ONLY accepted location. But
  on this toolchain that root-level declaration does not propagate to member-package files during
  command-line analysis. Verified inert via a differential probe (avoid_ref_inside_state_dispose) across
  5 configs: member-level (rejected), root-level (ignored for members), root + riverpod_lint as root
  dev_dep (ignored), SDK constraint bumped to ^3.10.0 (ignored), and `include:` list/chain (plugins do
  not propagate through include). Corroborated by dart-lang/sdk#61481 (inner-options plugins silently
  ignored) and rrousselGit/riverpod#4646 (silent lint failures). My initial "move the block to the
  member file" suggestion was WRONG — the analyzer rejects that placement.

  Linked to F3: the plan originally specified riverpod_lint 2.x + custom_lint, which DOES enforce in
  workspaces (via a separate `dart run custom_lint` step). The sanctioned drift to the 3.x native
  mechanism modernized the wiring but, on this toolchain, traded away working CLI enforcement.
- **Fix A ⭐ Recommended**: Accept as a documented toolchain limitation.
  - Keep the root-level `plugins:` block (correct placement, forward-compatible, likely works in the IDE
    analysis server even though CLI doesn't). Add a comment noting CLI enforcement is currently
    non-functional in the pub workspace; do not treat `flutter analyze` as a riverpod-lint gate. Re-test
    after a toolchain bump.
  - Strength: Honest about reality; zero churn; the block already sits in the only accepted spot.
  - Tradeoff: No automated riverpod-rule enforcement in CI until the toolchain matures.
  - Confidence: HIGH — 5 controlled experiments + two corroborating upstream issues.
  - Blind spot: IDE (analysis-server) activation not verified in a real editor here.
- **Fix B**: Restore CLI enforcement via custom_lint (riverpod_lint 2.x).
  - Pin riverpod_lint to 2.x + add custom_lint, run `dart run custom_lint` as a separate CI/dev step.
  - Strength: Actually enforces riverpod rules in CI today; works in workspaces.
  - Tradeoff: Reverts the modern 3.x mechanism; adds a separate command; reintroduces the analyzer-version
    tension noted in rrousselGit/riverpod#4364.
  - Confidence: MEDIUM — custom_lint workspace support is established, but not re-verified in THIS repo.
  - Blind spot: Whether 2.x resolves cleanly against the rest of the upgraded Riverpod 3.x runtime here.
- **Decision**: FIXED via Fix A — accepted as a documented toolchain limitation; added an explanatory
  comment to analysis_options.yaml (block kept in its only valid location). Captured in
  project memory (project_riverpod_lint_inert_in_pub_workspace).

### F2 — Unplanned server build change: dropped --wasm renderer

- **Severity**: ⚠️ WARNING
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Scope Discipline
- **Location**: tamagotchi_server/pubspec.yaml (flutter_build command)
- **Detail**: The plan said no server changes and its "What We're NOT Doing" did not mention this. Commit
  1e3b492 edits the serverpod flutter_build command: removes `--wasm` from both windows/posix branches,
  adds `rm -rf web/app` to posix, and adds a 6-line comment documenting a dart2wasm runtime LinkError on
  the Flutter 3.44 / Dart 3.12 toolchain. It is well-documented and almost certainly REQUIRED for the web
  app to load — i.e. for manual criteria 2.7–2.9 to pass at all. But it crosses the plan's explicit
  package boundary during a frontend-only slice.
- **Fix A ⭐ Recommended**: Accept and document as a plan addendum.
  - Strength: The change is justified and load-bearing — the wasm build fails at runtime, so without it
    the manual browser verification could not have passed. Recording it updates the source of truth.
  - Tradeoff: A frontend slice now also owns a server-pubspec edit; sets a cross-package precedent.
  - Confidence: HIGH — the LinkError is reproducible-class and the comment captures the rationale.
  - Blind spot: Whether --wasm should be re-attempted is deferred to a future toolchain; no tracking issue.
- **Fix B**: Split the build-renderer fix into its own change.
  - Strength: Restores strict scope discipline for F-01.
  - Tradeoff: Leaves the web build broken (wasm runtime failure) in the interim; manual verification regresses.
  - Confidence: MEDIUM — depends on whether anyone rebuilds web before the follow-up lands.
  - Blind spot: None significant.
- **Decision**: FIXED via Fix A — accepted; documented as a "Post-implementation Deviations" addendum
  in plan.md.

### F3 — Dependency/lint stack diverged from the written contract

- **Severity**: 🟢 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Plan Adherence
- **Location**: tamagotchi_flutter/pubspec.yaml
- **Detail**: Plan was written against Riverpod ~2.6.0 + custom_lint. Actual: flutter_riverpod ^3.3.0,
  riverpod_annotation ^4.0.0, riverpod_generator ^4.0.0, riverpod_lint ^3.1.0, go_router ^17.0.0;
  custom_lint correctly DROPPED (3.x uses the native analyzer plugin mechanism — confirmed absent from
  the lockfile). The plan explicitly delegated exact versions to the implementer, so this is sanctioned
  drift and the mechanism change is the correct modern call. Recorded because it changes codegen output
  shape ($-prefixed 3.x form) and is the root cause of F1's wiring subtlety.
- **Fix**: None needed — note the version baseline in the plan/change for future slices that pin against it.
- **Decision**: FIXED via addendum — resolved dependency baseline recorded in plan.md "Post-implementation
  Deviations".

### F4 — Unplanned usePathUrlStrategy() + flutter_web_plugins

- **Severity**: 🟢 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Scope Discipline
- **Location**: tamagotchi_flutter/lib/main.dart:17 (+ import :3)
- **Detail**: main() calls usePathUrlStrategy() (with flutter_web_plugins added to deps) — not in the
  plan's contract ("no other top-level declarations"; this is a statement inside main(), so not a strict
  violation). Justified: clean path-based URLs for go_router deep links, in-spirit for a routing scaffold.
  Benign.
- **Fix**: None — keep; optionally note it in the plan as an intentional routing addition.
- **Decision**: FIXED via addendum — documented as an intentional routing addition in plan.md
  "Post-implementation Deviations".

### F5 — Auth callbacks use context without a context.mounted guard

- **Severity**: 🟢 OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Safety & Quality
- **Location**: tamagotchi_flutter/lib/auth/sign_in_screen.dart:62-71
- **Detail**: onAuthenticated: () => context.go('/') and the onError ScaffoldMessenger.of(context) fire
  from async auth callbacks with no context.mounted check. The post-frame path (line ~52) IS correctly
  guarded with `if (mounted)`. The window here is tiny (SignInWidget owns these callbacks while mounted),
  so not a live bug, but worth a guard for symmetry.
- **Fix**: Add a `context.mounted` check before context.go / ScaffoldMessenger in both callbacks.
- **Decision**: FIXED — guarded both onAuthenticated and onError with `context.mounted` in
  sign_in_screen.dart.

### F6 — Fire-and-forget client.auth.initialize() — S-01 precondition

- **Severity**: 🟢 OBSERVATION
- **Impact**: 🔎 MEDIUM — real tradeoff; pause to reason through it
- **Dimension**: Safety & Quality
- **Location**: tamagotchi_flutter/lib/main.dart:29
- **Detail**: client.auth.initialize() returns Future<bool> (restore + validate) and is not awaited before
  runApp(). At first paint authInfo == null, so a returning signed-in user briefly appears unauthenticated
  until restore() fires authInfoListenable. Harmless in F-01 — there is no route guard (documented scope),
  sign_in_screen subscribes to the listenable and self-corrects, and this matches the original starter. The
  trap is S-01: an auth redirect that reads auth state synchronously at boot will misroute returning users
  during the restore window. The plan explicitly scoped out async-init plumbing, so leaving it is
  defensible — but it should be a CONSCIOUS carry-forward, not silent.
- **Fix**: Record as an explicit precondition for S-01's auth gate (await initialize() before installing
  the redirect, or gate the router on an AsyncValue). No change needed in F-01.
- **Decision**: FIXED IN CODE — `await client.auth.initialize()` before runApp() in main.dart (settles
  persisted auth state before first paint). Verified: flutter analyze 0, widget test passes.
