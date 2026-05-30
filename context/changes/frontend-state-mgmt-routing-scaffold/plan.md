# Frontend state management + routing scaffold — Implementation Plan

## Overview

Replace the bootstrap echo UI in the Flutter web client with a Riverpod + go_router app shell so every later feature slice can ship a screen + state container against a settled foundation. This is roadmap item **F-01** (`frontend-state-mgmt-routing-scaffold`) — a pure foundation slice with no user-visible product outcome; the payoff lands in S-01 / S-02 / S-03.

## Current State Analysis

- `tamagotchi/tamagotchi_flutter/lib/main.dart` is the bootstrap scaffold: a `late final Client client` global (`main.dart:15`) constructed in `main()` (`main.dart:33-37`), then `MyApp` (`main.dart:42`) mounts `MyHomePage` (`main.dart:55`) which mounts `GreetingsScreen` directly. No router. No state container. Two screens in `lib/screens/` (`greetings_screen.dart`, `sign_in_screen.dart`); both import the global via `'../main.dart'` (`greetings_screen.dart:3`, `sign_in_screen.dart:4`).
- `SignInScreen` is defined but unused — `MyHomePage` references it only inside a commented-out block (`main.dart:70-76`).
- `pubspec.yaml` has no Riverpod, no router. Dependencies are `flutter`, `tamagotchi_client` (path), `serverpod_flutter: 3.4.8`, `serverpod_auth_idp_flutter: 3.4.8`, `cupertino_icons: ^1.0.5`.
- The only Flutter test is `test/widget_test.dart` — it pumps `MyApp` and asserts the AppBar title "Serverpod Example". It will break the moment `main.dart` is rewritten and must be updated in the same change.
- `CLAUDE.md` mandates **group-by-feature** layout (`tamagotchi_flutter/lib/<feature>/{feature_screen.dart, feature_state.dart}`). The existing `lib/screens/` directory is the by-layer layout this convention rejects; the scaffold should set the new convention and retire the old folder.
- The server-side codegen cycle (`serverpod generate`, run from `tamagotchi_server/`) writes to `tamagotchi_client/lib/src/protocol/`. A second build_runner cycle (riverpod_generator) will run from `tamagotchi_flutter/` and write `.g.dart` siblings — different package, no collision.

## Desired End State

- `flutter analyze` and `flutter test` pass from `tamagotchi/tamagotchi_flutter/` with the new scaffold in place.
- `lib/main.dart` is a slim bootstrap that resolves the server URL, constructs the `Client`, and calls `runApp(ProviderScope(overrides: [...], child: const AppWidget()))`. No global `Client`. No `MyApp` / `MyHomePage` classes.
- `lib/app/` holds the shell (`app_widget.dart`, `app_router.dart`, `client_provider.dart`, `server_config.dart`). `lib/home/home_screen.dart` is an empty-state placeholder. `lib/auth/sign_in_screen.dart` is the Riverpod-aware port of the old sign-in widget. `lib/screens/` no longer exists.
- A user launching the app lands at `/` and sees the empty-state home placeholder ("No creature yet — sign in to get started" plus a navigation button to `/sign-in`). Navigating to `/sign-in` renders the Serverpod `SignInWidget` and returns to `/` on success. No auth guard yet (S-01 adds the redirect).
- `dart run build_runner build --delete-conflicting-outputs` (run from `tamagotchi_flutter/`) regenerates `.g.dart` files cleanly with no errors.
- The widget test pumps `ProviderScope(child: AppWidget())` and asserts the home placeholder text is visible — proof the router + provider container start in a known state without any client overrides required.

### Key Discoveries

- The Riverpod `@Riverpod(keepAlive: true)` annotation generates a synchronous provider stub that **throws `UnimplementedError`** in its body — the canonical pattern for an externally-supplied root dependency. Overriding it in the root `ProviderScope` via `serverpodClientProvider.overrideWithValue(client)` is the supported way to inject the pre-constructed `Client`. The widget test for the home stub does NOT need to override it because `HomeScreen` does not read the client.
- `GoRouter` plays well with Riverpod by exposing the router itself as a `Provider`. No `refreshListenable` wiring is needed in F-01 (auth gate is S-01); the router is a flat two-route map.
- Serverpod's `getServerUrl()` (used at `main.dart:31`) is the canonical helper for resolving the server URL from `--dart-define`, `assets/config.json`, or defaulting to `http://$localhost:8080/`. Resolve it once in `main()` and pass the resulting `Client` into the `ProviderScope` override; this keeps the rest of the app synchronous.
- `serverpod_auth_idp_flutter`'s `SignInWidget` already takes a `Client` parameter — porting the existing `lib/screens/sign_in_screen.dart` to read the client from Riverpod is a one-line change inside `build()`.

## What We're NOT Doing

- **No auth redirect / route guard.** The roadmap explicitly says "no guard yet — S-01 adds the auth gate." The router declares `/` and `/sign-in`; an unauthenticated user can reach `/` and see the empty-state stub (which has no real action), and `/sign-in` is reachable by direct navigation.
- **No creature / journal / stats screens.** Those land in S-02, S-03, S-08.
- **No CI workflow for the Flutter package.** `context/foundation/health-check.md` flagged the absence of `flutter analyze` / `flutter test` in CI as a known gap; closing it is its own change.
- **No theming work.** The default Material 3 ThemeData stands until a product-shaped slice cares.
- **No GreetingsScreen / server-echo dev route.** The old echo demo is deleted outright per the decision in the questioning round.
- **No splash / loading shell for async client init.** The `Client` is built synchronously in `main()` after `await getServerUrl()`, before `runApp()` — no `AsyncValue` plumbing at the app root.

## Implementation Approach

Two phases, smallest viable cuts:

1. **Wire the dependencies and confirm the codegen cycle works** on an empty annotation surface — so the second phase's `.g.dart` files have a known-good build_runner to lean on.
2. **Replace the app shell**: providers, router, screens, main, tests, cleanup — all in one phase because the file moves cannot be split without leaving the package in a broken state mid-commit.

The Riverpod variant is the codegen-based `@riverpod` annotation form (chosen with the tradeoff acknowledged that a second `build_runner` cycle now runs alongside Serverpod's `serverpod generate`). They never collide: `serverpod generate` runs from `tamagotchi_server/`, `build_runner` runs from `tamagotchi_flutter/`.

The Serverpod `Client` is exposed via a `@Riverpod(keepAlive: true)` provider whose body throws — the real instance is supplied via `overrideWithValue` in the root `ProviderScope`. The `late final Client client` global at `main.dart:15` is deleted in the same phase that updates the only two files that reference it (the new `auth/sign_in_screen.dart` reads from Riverpod; the deleted `screens/greetings_screen.dart` doesn't need anything).

## Critical Implementation Details

- **build_runner is invoked from `tamagotchi/tamagotchi_flutter/`**, not the workspace root. `serverpod generate` is invoked from `tamagotchi/tamagotchi_server/`. Each codegen surface writes only to files inside its own package; they never need to be coordinated. Run order does not matter.
- **The riverpod-generated `.g.dart` files are part of source** (not gitignored, not excluded from the analyzer) — Riverpod's convention is to commit them so consumers can be analyzed without running build_runner first. This differs from Serverpod's own generated trees (`tamagotchi_server/lib/src/generated/`, `tamagotchi_client/lib/src/protocol/`), which are also committed but are excluded from the analyzer.
- **The widget test must not trigger `serverpodClientProvider`'s body.** The test pumps the root `AppWidget` inside a plain `ProviderScope` with **no overrides**; the router starts at `/`, `HomeScreen` is a stateless placeholder that does not read the client, and the provider body never runs. If a later test needs to render `/sign-in`, it will override the client itself — F-01's test does not.

## Phase 1: Dependencies + codegen wiring

### Overview

Add Riverpod (codegen flavor), go_router, and the build_runner toolchain to `tamagotchi_flutter/pubspec.yaml`. Confirm `dart run build_runner build --delete-conflicting-outputs` runs cleanly with no annotated sources yet present — proves the codegen cycle is healthy before any `.g.dart` siblings are introduced in Phase 2.

### Changes Required

#### 1. pubspec.yaml additions

**File**: `tamagotchi/tamagotchi_flutter/pubspec.yaml`

**Intent**: Add the runtime + dev dependencies that the app shell will need. Pick versions compatible with Flutter `^3.44.0` / Dart `^3.8.0` declared in the existing `environment:` block.

**Contract**:

- `dependencies:` gains: `flutter_riverpod`, `riverpod_annotation`, `go_router`.
- `dev_dependencies:` gains: `build_runner`, `riverpod_generator`, `custom_lint`, `riverpod_lint`.
- The existing `dependency_overrides: flutter_secure_storage: ^10.0.0` block is preserved unchanged.
- Versions: pick the latest stable that resolves against Dart `^3.8.0` (e.g., `flutter_riverpod: ^2.6.0`, `riverpod_annotation: ^2.6.0`, `riverpod_generator: ^2.6.0`, `riverpod_lint: ^2.6.0`, `go_router: ^14.0.0`, `build_runner: ^2.4.0`, `custom_lint: ^0.7.0` — the implementer confirms exact versions at install time via `flutter pub get`).
- No changes to the `flutter:` section (assets stay as-is).

#### 2. analysis_options.yaml — wire custom_lint

**File**: `tamagotchi/tamagotchi_flutter/analysis_options.yaml`

**Intent**: Activate `custom_lint` so `riverpod_lint`'s rules surface during `flutter analyze`. Without this, Riverpod-specific lint feedback is silently ignored.

**Contract**: Add `analyzer: plugins: [custom_lint]` to the existing analyzer config. Keep the existing `include: package:flutter_lints/flutter.yaml` and `formatter:` blocks unchanged.

### Success Criteria

#### Automated Verification

- `flutter pub get` from `tamagotchi/tamagotchi_flutter/` resolves cleanly with no version conflicts.
- `dart run build_runner build --delete-conflicting-outputs` from `tamagotchi/tamagotchi_flutter/` exits 0 (no annotated sources yet; the run is a no-op that confirms the toolchain works).
- `flutter analyze` from `tamagotchi/tamagotchi_flutter/` exits 0.
- `flutter test` from `tamagotchi/tamagotchi_flutter/` still passes (the existing `widget_test.dart` is untouched in this phase — it asserts the old `MyApp` shell, which still exists).

#### Manual Verification

- `pubspec.lock` shows the four new runtime/dev packages with resolved versions; no surprise transitive bumps (skim `pubspec.lock` diff).

**Implementation Note**: After completing this phase and all automated verification passes, pause here for manual confirmation from the human that the dependency lockfile diff looks reasonable before proceeding to Phase 2.

---

## Phase 2: App shell — providers, router, screens, main, tests, cleanup

### Overview

Replace the bootstrap echo UI with the Riverpod + go_router scaffold. Establish the group-by-feature directory layout. Retire the global `Client`. Update the widget test to assert the home placeholder renders. Delete the old `lib/screens/` directory.

### Changes Required

#### 1. Server URL provider

**File**: `tamagotchi/tamagotchi_flutter/lib/app/server_config.dart` (new)

**Intent**: Hold the resolved server URL as a Riverpod-visible value so future features (e.g., feature flags pinned to environments) can read it without reaching into `main.dart`.

**Contract**: A `@Riverpod(keepAlive: true)` provider named `serverUrl` returning `String`. Body throws `UnimplementedError('serverUrlProvider must be overridden at the app root')`. A companion `part 'server_config.g.dart';` directive is declared.

#### 2. Serverpod client provider

**File**: `tamagotchi/tamagotchi_flutter/lib/app/client_provider.dart` (new)

**Intent**: Expose the Serverpod `Client` to consumers via Riverpod, so the `late final Client` global at `main.dart:15` can be deleted and screens stop importing `'../main.dart'`.

**Contract**: A `@Riverpod(keepAlive: true)` provider named `serverpodClient` returning `tamagotchi_client.Client` (from `package:tamagotchi_client/tamagotchi_client.dart`). Body throws `UnimplementedError('serverpodClientProvider must be overridden at the app root')`. A companion `part 'client_provider.g.dart';` directive is declared.

#### 3. App router

**File**: `tamagotchi/tamagotchi_flutter/lib/app/app_router.dart` (new)

**Intent**: Declare the two-route map and expose it as a Riverpod-visible `GoRouter` instance. Auth guard is intentionally absent — S-01 adds it via a `refreshListenable` tied to `client.auth.authInfoListenable`.

**Contract**: A `@Riverpod(keepAlive: true)` provider named `appRouter` returning `GoRouter`. Two `GoRoute`s: `path: '/'` → `HomeScreen()`, `path: '/sign-in'` → `SignInScreen()`. `initialLocation: '/'`. No `redirect:` callback. A companion `part 'app_router.g.dart';` directive is declared.

#### 4. App widget

**File**: `tamagotchi/tamagotchi_flutter/lib/app/app_widget.dart` (new)

**Intent**: Root widget that consumes the router provider and mounts `MaterialApp.router`. Replaces the old `MyApp` / `MyHomePage` classes.

**Contract**: A `ConsumerWidget` named `AppWidget`. In `build()`: read `appRouterProvider`, return `MaterialApp.router(title: 'AI-Tamagotchi', theme: ThemeData(useMaterial3: true), routerConfig: router)`. No other behavior. No `home:` parameter.

#### 5. Home screen — empty-state placeholder

**File**: `tamagotchi/tamagotchi_flutter/lib/home/home_screen.dart` (new)

**Intent**: A minimal empty-state placeholder so the router has somewhere to land. S-01 (FR-001) will replace this with the real signed-in empty-creature view; for now, it exists only to prove the router works and to give the user something coherent to see on first run.

**Contract**: A `StatelessWidget` named `HomeScreen`. Renders a `Scaffold` with an `AppBar(title: Text('AI-Tamagotchi'))` and a body containing two centered widgets: a `Text('No creature yet')` and an `ElevatedButton(onPressed: () => context.go('/sign-in'), child: Text('Sign in'))`. The button uses `context.go` from `package:go_router/go_router.dart`.

#### 6. Sign-in screen — Riverpod port

**File**: `tamagotchi/tamagotchi_flutter/lib/auth/sign_in_screen.dart` (new — replaces `lib/screens/sign_in_screen.dart`)

**Intent**: Port the existing sign-in widget into the new feature layout and read the `Client` from Riverpod instead of the global. Behavior matches the old `lib/screens/sign_in_screen.dart`: shows `SignInWidget` when unauthenticated, returns to `/` after a successful sign-in. The `widget.child` parameter on the old class is dropped — routing now controls what comes next, not widget nesting.

**Contract**: A `ConsumerStatefulWidget` named `SignInScreen` (no constructor params). State subscribes to `client.auth.authInfoListenable` in `initState` and unsubscribes in `dispose` (mirroring the old listener pattern in `lib/screens/sign_in_screen.dart:18-28`). In `build()`: read `serverpodClientProvider`; if `client.auth.isAuthenticated` is true, call `context.go('/')` post-frame (`WidgetsBinding.instance.addPostFrameCallback`) and return a placeholder Scaffold; otherwise return a `Scaffold` containing the Serverpod `SignInWidget(client: client, onAuthenticated: () => context.go('/'), onError: (e) => ScaffoldMessenger.of(context).showSnackBar(...))`.

#### 7. main.dart — slim bootstrap

**File**: `tamagotchi/tamagotchi_flutter/lib/main.dart`

**Intent**: Become a thin bootstrap: resolve the server URL, build the `Client`, initialize auth, then `runApp(ProviderScope(overrides: [...], child: AppWidget()))`. Delete the `late final Client client` global, `late String serverUrl`, `MyApp`, and `MyHomePage`. Delete the import of the old `screens/greetings_screen.dart`.

**Contract**: Single `Future<void> main() async` function. Order: `WidgetsFlutterBinding.ensureInitialized()`; `final serverUrl = await getServerUrl()`; `final client = Client(serverUrl)..connectivityMonitor = FlutterConnectivityMonitor()..authSessionManager = FlutterAuthSessionManager()`; `client.auth.initialize()`; `runApp(ProviderScope(overrides: [serverUrlProvider.overrideWithValue(serverUrl), serverpodClientProvider.overrideWithValue(client)], child: const AppWidget()))`. No other top-level declarations.

```dart
// Sketch — included because the override list is the load-bearing contract
// that ties Phase 2's providers to the resolved bootstrap values.
runApp(
  ProviderScope(
    overrides: [
      serverUrlProvider.overrideWithValue(serverUrl),
      serverpodClientProvider.overrideWithValue(client),
    ],
    child: const AppWidget(),
  ),
);
```

#### 8. Widget test — assert home placeholder renders

**File**: `tamagotchi/tamagotchi_flutter/test/widget_test.dart`

**Intent**: Update the test to match the new shell. Asserts that pumping `AppWidget` inside a bare `ProviderScope` (no client override) lands on the home placeholder. Proves the router boots without requiring an injected `Client` — which it doesn't, because `HomeScreen` is stateless and does not read providers.

**Contract**: One `testWidgets` case named `'App boots into the home placeholder'`. Body: `await tester.pumpWidget(const ProviderScope(child: AppWidget()))`; `await tester.pumpAndSettle()`; `expect(find.text('No creature yet'), findsOneWidget)`; `expect(find.text('Sign in'), findsOneWidget)`.

#### 9. Delete the old screens directory

**File**: `tamagotchi/tamagotchi_flutter/lib/screens/` (delete)

**Intent**: Retire the by-layer layout per `CLAUDE.md`. Delete `lib/screens/greetings_screen.dart` (server-echo demo, no longer mounted anywhere) and `lib/screens/sign_in_screen.dart` (replaced by `lib/auth/sign_in_screen.dart`). The empty directory is removed afterwards.

**Contract**: Both files removed from the working tree. No replacement; no shim.

#### 10. Run codegen

**Step (not a file)**

**Intent**: Generate the four `.g.dart` siblings for `server_config.dart`, `client_provider.dart`, `app_router.dart`, and (no `.g.dart` needed for `app_widget.dart`, `home_screen.dart`, `sign_in_screen.dart` — they are unannotated). Without this step, the `part '*.g.dart'` directives point at missing files and analysis fails.

**Contract**: Run `dart run build_runner build --delete-conflicting-outputs` from `tamagotchi/tamagotchi_flutter/`. Commit the resulting `.g.dart` files alongside their sources.

### Success Criteria

#### Automated Verification

- `dart run build_runner build --delete-conflicting-outputs` from `tamagotchi/tamagotchi_flutter/` exits 0 and produces the expected `.g.dart` siblings.
- `flutter analyze` from `tamagotchi/tamagotchi_flutter/` exits 0.
- `flutter test` from `tamagotchi/tamagotchi_flutter/` passes — specifically the updated `widget_test.dart` case `'App boots into the home placeholder'`.
- `git ls-files tamagotchi/tamagotchi_flutter/lib/screens/` returns nothing (the old directory is gone from the index).
- `grep -r "late final Client client" tamagotchi/tamagotchi_flutter/lib/` returns no matches (the global is gone).
- `grep -r "import '../main.dart'" tamagotchi/tamagotchi_flutter/lib/` returns no matches (no widget reaches into `main.dart` anymore).

#### Manual Verification

- Build the Flutter web app via `serverpod run flutter_build` from `tamagotchi/tamagotchi_server/`, then start the Serverpod server (`dart bin/main.dart --apply-migrations`) and load `http://localhost:8080/` in a browser; confirm the home placeholder ("No creature yet" + "Sign in" button) renders.
- Click "Sign in"; confirm the URL changes to `/sign-in` and the Serverpod `SignInWidget` renders.
- Navigate back to `/` directly via the browser URL bar; confirm the home placeholder renders again (router round-trip works).

**Implementation Note**: After completing this phase and all automated verification passes, pause here for manual confirmation from the human that the manual browser test passed (home renders, `/sign-in` renders, navigation round-trips) before treating F-01 as complete.

---

## Testing Strategy

### Unit Tests

- No unit-only logic in this scaffold worth a standalone unit test (the providers' bodies throw; the screens are stateless or pure-listener widgets).

### Integration Tests

- Not applicable at the Flutter package level for F-01. The server already has integration tests (per `health-check.md`); no server-side changes here.

### Manual Testing Steps

1. From `tamagotchi/tamagotchi_server/`: `serverpod run flutter_build` to produce the web bundle.
2. Start the Serverpod server in development mode and load `http://localhost:8080/` in a browser.
3. Confirm the page renders the home placeholder text "No creature yet" and a "Sign in" button.
4. Click "Sign in". Confirm the URL changes to `/sign-in` and the Serverpod sign-in widget renders.
5. Navigate to `/sign-in` directly via URL bar from a fresh tab. Confirm the same screen renders (deep-link round-trip works).
6. Navigate back to `/` via URL bar. Confirm the home placeholder re-renders.

## Performance Considerations

None. The scaffold introduces one Riverpod `ProviderScope` and one `GoRouter` instance — both have negligible cost. No NFR-1 latency budget is exercised in F-01 (no LLM call, no endpoint call).

## Migration Notes

- The `lib/screens/greetings_screen.dart` server-echo demo is deleted. No replacement; the server endpoint `greeting.hello` is untouched and can still be invoked from server-side tests if needed.
- The `lib/screens/sign_in_screen.dart` widget is replaced by `lib/auth/sign_in_screen.dart`. Behavior is preserved (listens to auth state, renders `SignInWidget` until authenticated) but the `widget.child` constructor parameter is dropped — routing now controls what comes after sign-in, not widget nesting.
- The `late final Client client` global is deleted. Any future code that needs the client reads `ref.read(serverpodClientProvider)` (or `ref.watch` inside a `build`).

## References

- Roadmap source: `context/foundation/roadmap.md` — entry F-01 (`frontend-state-mgmt-routing-scaffold`).
- PRD anchor: `context/foundation/prd.md` §Non-Functional Requirements (NFR-1 — 5-second perceived response).
- Project conventions: `CLAUDE.md` (group-by-feature layout, Flutter web build command).
- Current bootstrap: `tamagotchi/tamagotchi_flutter/lib/main.dart:1-79`.
- Existing sign-in widget being ported: `tamagotchi/tamagotchi_flutter/lib/screens/sign_in_screen.dart:1-73`.
- Codegen sibling cycle for the server: `tamagotchi/tamagotchi_server/CLAUDE.md` (the spy → generate cycle).

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: Dependencies + codegen wiring

#### Automated

- [x] 1.1 `flutter pub get` from `tamagotchi/tamagotchi_flutter/` resolves cleanly with no version conflicts — f68e959
- [x] 1.2 `dart run build_runner build --delete-conflicting-outputs` from `tamagotchi/tamagotchi_flutter/` exits 0 — f68e959
- [x] 1.3 `flutter analyze` from `tamagotchi/tamagotchi_flutter/` exits 0 — f68e959
- [x] 1.4 `flutter test` from `tamagotchi/tamagotchi_flutter/` still passes — f68e959

#### Manual

- [x] 1.5 `pubspec.lock` diff shows the four new packages with sane resolved versions; no surprise transitive bumps — f68e959

### Phase 2: App shell — providers, router, screens, main, tests, cleanup

#### Automated

- [x] 2.1 `dart run build_runner build --delete-conflicting-outputs` from `tamagotchi/tamagotchi_flutter/` exits 0 and produces the expected `.g.dart` siblings
- [x] 2.2 `flutter analyze` from `tamagotchi/tamagotchi_flutter/` exits 0
- [x] 2.3 `flutter test` from `tamagotchi/tamagotchi_flutter/` passes — specifically `'App boots into the home placeholder'`
- [x] 2.4 `git ls-files tamagotchi/tamagotchi_flutter/lib/screens/` returns nothing
- [x] 2.5 `grep -r "late final Client client" tamagotchi/tamagotchi_flutter/lib/` returns no matches
- [x] 2.6 `grep -r "import '../main.dart'" tamagotchi/tamagotchi_flutter/lib/` returns no matches

#### Manual

- [x] 2.7 Home placeholder ("No creature yet" + "Sign in" button) renders at `/` in a browser
- [x] 2.8 Clicking "Sign in" navigates to `/sign-in` and the Serverpod `SignInWidget` renders
- [x] 2.9 Deep-link to `/sign-in` from a fresh tab renders the sign-in screen; navigating back to `/` re-renders the home placeholder
