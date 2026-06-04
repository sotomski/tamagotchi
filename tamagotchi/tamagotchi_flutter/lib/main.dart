import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
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

  WidgetsFlutterBinding.ensureInitialized();

  // The server URL is resolved from `--dart-define=SERVER_URL=...`, the
  // `assets/config.json` file, or defaults to `http://$localhost:8080/`.
  final serverUrl = await getServerUrl();

  final client = Client(serverUrl)
    ..connectivityMonitor = FlutterConnectivityMonitor()
    ..authSessionManager = FlutterAuthSessionManager();

  // Restore and validate any persisted session BEFORE first paint, so a
  // returning signed-in user doesn't briefly render as unauthenticated and
  // S-01's auth guard can read settled auth state at boot.
  await client.auth.initialize();

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
