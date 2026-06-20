// Patrol toolchain canary (Phase 1, playwright-for-flutter).
//
// This is NOT a risk-tied test and NOT the seed (those land in Phase 2/4). Its
// only job is to prove the toolchain end-to-end: that `patrol test` builds and
// serves the Flutter web app, drives headless Chromium, and the served build
// reaches the e2e Serverpod API on :8080.
//
// Run from tamagotchi_flutter/ (sidecars already up; API booted via
// `serverpod run e2e` in tamagotchi_server/):
//   patrol test --target integration_test/smoke_test.dart \
//     -d chrome --web-headless true --web-port 7357 --web-locale en-US
//
// Toolchain gotchas this devcontainer bakes in (see .devcontainer/devcontainer.json
// and the Phase 6 cookbook) — all three are load-bearing on Linux web:
//   1. Node 24.15.0 (pinned). Node 24.16.0 carries upstream bug nodejs/node#63487,
//      which hangs patrol's bundled playwright-core 1.56.0 `playwright install`
//      forever after the first browser (microsoft/playwright#40998, fixed in pw
//      1.60.0 which patrol doesn't ship yet). 24.15.0 sidesteps it.
//   2. PATROL_WEB_LOCALE=en-US (remoteEnv) — equivalently `--web-locale en-US`.
//      Headless Chromium reports empty `navigator.languages`, so Flutter's
//      CanvasKit `parseBrowserLanguages` throws "Incorrect locale information
//      provided" on boot and patrol discovers 0 tests. A non-empty locale fixes it.
//   3. CHROME_EXECUTABLE (remoteEnv → /home/vscode/.cache/flutter-chrome symlink)
//      so `flutter devices` lists Chrome and patrol's `-d chrome` resolves.
// patrol downloads its own playwright browsers (build v1194) on first run (~370 MB,
// one-time); under Node 24.15.0 that completes without hanging.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';
import 'package:tamagotchi_client/tamagotchi_client.dart';
import 'package:tamagotchi_flutter/app/app_widget.dart';
import 'package:tamagotchi_flutter/app/client_provider.dart';
import 'package:tamagotchi_flutter/app/server_config.dart';

void main() {
  patrolTest('smoke: app boots and renders the Sign-in screen', ($) async {
    // Replicate main()'s bootstrap so the test drives the REAL app. A fresh
    // patrol browser has no stored session, so client.auth.initialize() settles
    // as unauthenticated and the router's auth gate lands on /sign-in.
    final serverUrl = await getServerUrl();
    final client = Client(serverUrl)
      ..connectivityMonitor = FlutterConnectivityMonitor()
      ..authSessionManager = FlutterAuthSessionManager();
    await client.auth.initialize();

    await $.pumpWidgetAndSettle(
      ProviderScope(
        overrides: [
          serverUrlProvider.overrideWithValue(serverUrl),
          serverpodClientProvider.overrideWithValue(client),
        ],
        child: const AppWidget(),
      ),
    );

    // The unauthenticated app shows the Sign-in screen: the AppBar title
    // 'Sign in' AND the Serverpod SignInWidget's submit button both render that
    // text, so there are two matches — `findsWidgets` (>=1), not `findsOneWidget`.
    // Finding any is the minimal proof that patrol built + served the app, drove
    // headless Chromium, and the served build reached the e2e API on :8080.
    await $('Sign in').waitUntilVisible();
    expect($('Sign in'), findsWidgets);
  });
}
