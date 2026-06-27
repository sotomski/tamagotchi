import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';
import 'package:tamagotchi_client/tamagotchi_client.dart';

import 'app/app_widget.dart';
import 'app/client_provider.dart';
import 'app/server_config.dart';

Future<void> main() async {
  // Use clean path-based URLs (e.g. /app/sign-in) instead of the default
  // hash strategy (/app/#/sign-in), so deep links and refreshes route
  // correctly. The server's FlutterRoute serves index.html for /app/** so the
  // path is handed to go_router on load.
  usePathUrlStrategy();

  // In debug builds, install Marionette's binding so an MCP-driven agent can
  // drive the live app for exploration (playwright-for-flutter Phase 5).
  // kDebugMode-gated: release builds keep the standard WidgetsFlutterBinding and
  // the marionette import tree-shakes away. Patrol/e2e tests never reach this
  // main() — they bootstrap under PatrolBinding inside patrolTest — so the swap
  // is invisible to them.
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }

  // The server URL is resolved from `--dart-define=SERVER_URL=...`, the
  // `assets/config.json` file, or defaults to `http://$localhost:8080/`.
  final serverUrl = await getServerUrl();

  final client = Client(serverUrl)
    ..connectivityMonitor = FlutterConnectivityMonitor()
    ..authSessionManager = FlutterAuthSessionManager();

  // Restore and validate any persisted session BEFORE first paint, so a
  // returning signed-in user doesn't briefly render as unauthenticated and
  // S-01's auth guard can read settled auth state at boot.
  //
  // This MUST NOT be allowed to abort boot. `SessionManager.initialize` wraps
  // its server round-trip in `.timeout(...)` but only catches
  // `ServerpodClientException` — a `TimeoutException` (e.g. a slow prod auth
  // call exceeding the default 2s budget) escapes uncaught, killing `main()`
  // before `runApp` and leaving a blank white screen. We give it a longer
  // budget and swallow any failure: the router's auth gate reads whatever auth
  // state restored, and validation can be retried later.
  try {
    await client.auth.initialize(timeout: const Duration(seconds: 10));
  } catch (error, stackTrace) {
    debugPrint(
      'Auth initialize failed; continuing to app: $error\n$stackTrace',
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        serverUrlProvider.overrideWithValue(serverUrl),
        serverpodClientProvider.overrideWithValue(client),
      ],
      child: const AppWidget(),
    ),
  );
}
