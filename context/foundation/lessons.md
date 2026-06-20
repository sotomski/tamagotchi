# Lessons Learned

> Append-only register of recurring rules and patterns. Re-read at start by /10x-frame, /10x-research, /10x-plan, /10x-plan-review, /10x-implement, /10x-impl-review.

## Apply Serverpod migrations via `serverpod run start`, not `--apply-migrations`

- **Context**: Any phase that creates or applies a Serverpod migration locally in `tamagotchi_server/` (the `serverpod generate` → `create-migration` → apply cycle).
- **Problem**: Plans/research keep prescribing `dart bin/main.dart --apply-migrations`, which is not how this project applies migrations and wastes a step.
- **Rule**: To apply pending migrations locally, run `serverpod run start` — it boots the server and applies migrations automatically. Do not use `dart bin/main.dart --apply-migrations`.
- **Applies to**: research, plan, implement

## Test async Riverpod surfaces with provider overrides, not a real RPC

- **Context**: Widget-testing any screen driven by an async-data provider over the generated Serverpod client (first established for S-02's `creatureProvider` / `HomeScreen`; reusable for S-03's interactive slice).
- **Problem**: The real provider body calls `client.<endpoint>.<method>()`, which round-trips to a server that isn't running under `flutter test` — so the widget lands in an error/timeout state and the test can't reach the state it means to assert.
- **Rule**: Override the provider with canned `AsyncValue`s instead of faking the `Client`. For an `@riverpod Future<T>` provider, `overrideWith((ref) => ...)`:
  - **loading** → `(ref) => Completer<T>().future` (never completes; assert the spinner after a single `pump()`, not `pumpAndSettle()`).
  - **error** → `(ref) => Future<T>.error(Exception('...'))` (assert the error widget + retry).
  - **data** → `(ref) => value` (a sync return resolves to `AsyncData` immediately).
  - **flow (empty → present)** → point the provider at a flip-able seam — `creatureProvider.overrideWith((ref) => ref.watch(seam))` where `seam` is a `StateProvider<T?>` — and override the action notifier (`hatchControllerProvider.overrideWith(_FakeController.new)`) so its method sets the seam instead of calling the server. Tapping the real button then swaps the view, exercising the real form/validation without an RPC.
- **Gotchas (Riverpod 3.x / `riverpod_generator` 4.x)**: `StateProvider` now lives in `package:flutter_riverpod/legacy.dart`. The `Override` type isn't exported by name — don't annotate `List<Override>`; pass the list literal inline to `ProviderScope(overrides: [...])` and let inference handle it. A fake notifier should `extends` the generated controller and override only its action method (it inherits `build()` + `ref`).
- **Applies to**: implement, research, plan

## Inject impure collaborators via one production-default factory seam, never @visibleForTesting

- **Context**: Any phase wiring an impure/external collaborator (RNG, LLM/HTTP client, clock, mailer) into a Serverpod endpoint or other framework-instantiated class that can't take constructor injection.
- **Problem**: Marking the seam @visibleForTesting forces production code to read a test-only member (needing // ignore lints), and per-dependency global seams scatter injection — both mix test concerns into production and let the call site be misconfigured.
- **Rule**: Encapsulate impure/external collaborators behind one concrete service and inject it through a single plain factory seam whose default IS the production wiring (e.g. fooServiceFor(session)) — never @visibleForTesting. The endpoint calls the factory unconditionally; tests reassign the seam to inject fakes and self-clean with addTearDown.
- **Applies to**: plan, implement, impl-review

## `mutation_test` XML: put `<command>` text on one line with no leading whitespace

- **Context**: Any phase that runs `mutation_test` via a `mutation_test.xml` config (scoped mutation gate).
- **Problem**: `_addCommand` in mutation_test 1.8.0 splits the element's inner text on single spaces — indented, multi-line content puts a newline/whitespace token as `text[0]`, which `.trim()` collapses to `""`. `Process.start("")` then fails with `ProcessException: No such file or directory`. The error message shows the original raw text (which looks correct), masking the real cause. The dry-run (`--dry`) never executes commands, so it passes and hides the bug entirely.
- **Rule**: Write `<command>` with the command text immediately after the tag, on one line, no leading whitespace:
  ```xml
  <command group="unit" expected-return="0" timeout="60">dart test test/unit/ --no-color</command>
  ```
  Never put a newline before the command text, even for readability. The dry-run is not sufficient to validate the XML — always do one real (non-`--dry`) run to confirm the command launches.
- **Bonus**: Pass `-f md -o mutation_out` to get a markdown report instead of the default HTML tree; add `mutation_out/` to `.gitignore`.
- **Applies to**: implement, plan

## Patrol web e2e on Linux: pin Node 24.15.0, set a browser locale, point CHROME_EXECUTABLE

- **Context**: Any phase that runs `patrol test … -d chrome --web-headless` for the Flutter web app in this devcontainer (the `playwright-for-flutter` e2e layer — smoke, seed, and the persistence test, Phases 1–6). patrol 4.6.1 bundles playwright-core 1.56.0.
- **Problem**: Three independent toolchain gaps each silently break `patrol test` on web, with misleading symptoms: (1) Node 24.16.0 carries upstream bug nodejs/node#63487, which hangs the bundled playwright's `playwright install` forever after the first browser (microsoft/playwright#40998, fixed in pw 1.60.0 — not yet shipped by patrol) — `patrol test` stalls at "Installing Playwright dependencies…" with no output; (2) headless Chromium reports empty `navigator.languages`, so Flutter's CanvasKit `parseBrowserLanguages` throws "Incorrect locale information provided" during engine bootstrap and the app never exposes `window.__patrol__getTests`, so patrol reports `Total: 0` and exits 1 (reads as a discovery failure, not a render crash); (3) without `CHROME_EXECUTABLE`, `flutter devices` doesn't list Chrome so patrol's `-d chrome` won't resolve (patrol then runs `flutter run -d web-server`, but validates the chrome device first).
- **Rule**: For patrol web on this container keep three things wired in `.devcontainer/`: pin the node feature to `"24.15.0"`; set `PATROL_WEB_LOCALE=en-US` (remoteEnv) or pass `--web-locale en-US`; set `CHROME_EXECUTABLE` to the stable `/home/vscode/.cache/flutter-chrome` symlink that `postCreate` points at the newest `ms-playwright` chromium. Boot the API with `serverpod run e2e` (sidecars are always up — never `docker compose up`) and run `patrol test --target integration_test/<t>.dart -d chrome --web-headless true --web-port 7357`. Two operational gotchas: a container rebuild wipes `~/.pub-cache` so `postCreate` must `flutter pub get` (else the server won't compile); a killed patrol run can orphan the flutter web-server holding `--web-port` (7357) — free that port before re-running.
- **Applies to**: implement, e2e, plan, research

## Run `dart format` before committing — the Format CI gate is `--set-exit-if-changed`

- **Context**: Any phase that lands Dart in `tamagotchi_server/` or `tamagotchi_flutter/` (lib or test). Both packages have a Format workflow (`.github/workflows/format.yml`, `flutter.yml`) that runs `dart format --set-exit-if-changed .`.
- **Problem**: Several S-03 phase commits landed unformatted code (`feed_service.dart`, `mistral_client.dart`, three test files), so the Format check was silently red on the branch until a later catch-up commit reformatted five files. `dart analyze` passing does NOT imply formatting is clean — they are separate gates, and the format check fails the build on *any* diff.
- **Rule**: Run `dart format .` (server) and `dart format .` (flutter) and stage the result *before* each phase-end commit — do not rely on analyze. Treat formatting as part of the phase's automated verification, same as analyze/tests. When replicating CI locally, run `dart format --set-exit-if-changed .` in both packages and expect exit 0.
- **Applies to**: implement, impl-review
