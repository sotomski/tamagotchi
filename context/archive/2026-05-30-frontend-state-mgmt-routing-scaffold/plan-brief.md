# Frontend state management + routing scaffold — Plan Brief

> Full plan: `context/changes/frontend-state-mgmt-routing-scaffold/plan.md`

## What & Why

Replace the bootstrap echo UI in `tamagotchi_flutter/` with a Riverpod (codegen) + go_router app shell. This is roadmap item **F-01** — a foundation slice with no user-visible product outcome. Its purpose is to lock in the framework and feature-folder layout so every later slice (S-01 → S-09) can ship a screen + state container without re-arguing it.

## Starting Point

`lib/main.dart` constructs a `late final Client client` global, builds a `MyApp` / `MyHomePage` that directly mounts `GreetingsScreen` (a server-echo demo). Screens live in `lib/screens/` (the by-layer layout `CLAUDE.md` rejects) and reach the client via `import '../main.dart'`. `SignInScreen` exists but is commented out in `main.dart:70-76`. No router, no Riverpod, no go_router in `pubspec.yaml`. One widget test asserts the AppBar title "Serverpod Example".

## Desired End State

The app boots into a `ProviderScope`, lands at `/` on a minimal "No creature yet" placeholder, and offers navigation to `/sign-in` where the Serverpod `SignInWidget` renders. The `Client` is exposed via a Riverpod provider overridden at the root; the global is gone. Code is organized into `lib/app/`, `lib/home/`, `lib/auth/` per the group-by-feature convention. `flutter analyze` and `flutter test` pass.

## Key Decisions Made

| Decision                  | Choice                                             | Why                                                                                       | Source |
| ------------------------- | -------------------------------------------------- | ----------------------------------------------------------------------------------------- | ------ |
| Riverpod variant          | `flutter_riverpod` + `riverpod_generator` (`@riverpod` codegen) | User accepted the second build_runner cycle for idiomatic 2.x annotation-based providers. | Plan   |
| Router                    | `go_router`                                        | Largest training-data footprint; clean refreshListenable hook S-01 will use for the auth gate. | Plan |
| Client access             | Riverpod provider, retire the global               | One source of truth; testable via override; eliminates the `'../main.dart'` import smell. | Plan   |
| GreetingsScreen demo      | Delete; ship an empty-state home stub instead      | No dead code carried forward; the stub is exactly what S-01 will replace properly.        | Plan   |
| Initial route map         | `/` + `/sign-in`, no guard yet                     | Smallest map that proves the router works; auth redirect is S-01's job, not F-01's.       | Plan   |

## Scope

**In scope:**
- Add `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`, `go_router`, `build_runner`, `custom_lint`, `riverpod_lint` to `pubspec.yaml`.
- Create `lib/app/{server_config.dart, client_provider.dart, app_router.dart, app_widget.dart}`.
- Create `lib/home/home_screen.dart` (empty-state placeholder).
- Create `lib/auth/sign_in_screen.dart` (Riverpod-aware port).
- Rewrite `lib/main.dart` as a slim bootstrap.
- Delete `lib/screens/` (`greetings_screen.dart` + old `sign_in_screen.dart`).
- Update `test/widget_test.dart` to assert the home placeholder.

**Out of scope:**
- Auth guard / route redirect (S-01).
- Creature, journal, stats screens (S-02, S-03, S-08).
- Adding `flutter analyze` / `flutter test` to CI (known gap from health-check; separate change).
- Theming work beyond Material 3 defaults.
- Dev-only diagnostic routes for the old server-echo demo.

## Architecture / Approach

Two-layer app shell. **Bootstrap layer** (`main.dart`): resolves the server URL, builds the `Client`, calls `runApp(ProviderScope(overrides: [serverUrlProvider.overrideWithValue(...), serverpodClientProvider.overrideWithValue(...)], child: AppWidget()))`. **App layer** (`lib/app/`): `AppWidget` is a `ConsumerWidget` that reads `appRouterProvider` and mounts `MaterialApp.router`. The router declares two routes. The `Client` provider's body throws `UnimplementedError` (canonical Riverpod pattern) — the real instance only ever arrives via the root override, which makes the widget test trivially clean (no override needed because `HomeScreen` doesn't read the client).

## Phases at a Glance

| Phase                                            | What it delivers                                              | Key risk                                                                                    |
| ------------------------------------------------ | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| 1. Dependencies + codegen wiring                 | New deps in `pubspec.yaml`; build_runner cycle confirmed working. | Version resolution conflicts with the Flutter `^3.44.0` / Dart `^3.8.0` constraint.        |
| 2. App shell — providers, router, screens, tests | Riverpod + go_router shell live; old `lib/screens/` deleted; widget test updated. | File moves can't be split; if any one of the eight files in this phase regresses, the whole phase regresses. |

**Prerequisites:** None (F-01 has no upstream slice). Devcontainer with Flutter 3.44 + Dart 3.8 tooling, which is already present.
**Estimated effort:** ~1-2 sessions across 2 phases. Foundation slice; mechanical work once decisions are made.

## Open Risks & Assumptions

- **Assumption:** Riverpod 2.6.x + `go_router` 14.x + `build_runner` 2.4.x resolve cleanly against Flutter 3.44 / Dart 3.8. If they don't, the implementer pins to the highest compatible majors at install time.
- **Assumption:** The Serverpod `SignInWidget` API has not changed since `lib/screens/sign_in_screen.dart` was written (it takes `client`, `onAuthenticated`, `onError`). If it has, the port in `lib/auth/sign_in_screen.dart` adjusts to the current API.
- **Risk:** Two codegen cycles now coexist (`serverpod generate` from `tamagotchi_server/`, `build_runner` from `tamagotchi_flutter/`). They write to disjoint packages and never collide, but the developer must remember which one to run when. Documented in the plan's Critical Implementation Details.

## Success Criteria (Summary)

- The app boots into a Riverpod-backed, go_router-routed shell with no global `Client`.
- `flutter analyze` and `flutter test` pass; the widget test asserts the home placeholder renders.
- The browser smoke test (load `/`, click "Sign in", navigate back) round-trips cleanly.
