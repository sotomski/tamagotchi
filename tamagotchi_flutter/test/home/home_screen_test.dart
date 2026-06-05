import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';
import 'package:tamagotchi_client/tamagotchi_client.dart';
import 'package:tamagotchi_flutter/app/app_router.dart';
import 'package:tamagotchi_flutter/app/app_widget.dart';
import 'package:tamagotchi_flutter/app/client_provider.dart';
import 'package:tamagotchi_flutter/creature/creature_provider.dart';

/// In-memory [ClientAuthSuccessStorage] so the session manager works in tests
/// without the secure-storage platform channel. Auth state is flipped by
/// driving [FlutterAuthSessionManager.updateSignedInUser].
class _InMemoryAuthStorage implements ClientAuthSuccessStorage {
  AuthSuccess? _data;

  @override
  Future<AuthSuccess?> get() async => _data;

  @override
  Future<void> set(AuthSuccess? data) async => _data = data;
}

/// A real [Client] wired to a [FlutterAuthSessionManager] backed by in-memory
/// storage, so `client.auth.isAuthenticated` / `authInfoListenable` are
/// controllable from the test (no secure storage).
Client _buildClient() =>
    Client('http://localhost:8080/')
      ..authSessionManager = FlutterAuthSessionManager(
        storage: _InMemoryAuthStorage(),
      );

AuthSuccess _authSuccess() => AuthSuccess(
  authStrategy: 'email',
  token: 'test-token',
  authUserId: UuidValue.fromString('00000000-0000-0000-0000-000000000001'),
  scopeNames: const {},
);

/// The route the guard has settled the app on.
String _currentPath(ProviderContainer container) => container
    .read(appRouterProvider)
    .routerDelegate
    .currentConfiguration
    .uri
    .path;

/// The real Serverpod [SignInWidget] form overflows its fixed-width box at the
/// test viewport — a layout quirk inside the dependency, unrelated to anything
/// under test. Drain those, but re-throw anything else so genuine errors still
/// surface.
void _drainBenignOverflow(WidgetTester tester) {
  for (
    Object? caught = tester.takeException();
    caught != null;
    caught = tester.takeException()
  ) {
    if (!caught.toString().contains('overflowed')) {
      throw caught;
    }
  }
}

/// Pumps the full app (so the auth guard runs) and returns its container.
Future<ProviderContainer> _pumpApp(WidgetTester tester, Client client) async {
  final container = ProviderContainer(
    overrides: [
      serverpodClientProvider.overrideWithValue(client),
      // Keep the home hermetic: the creature fetch resolves to "no creature"
      // (the S-02 empty state) instead of round-tripping a real RPC to a server
      // that isn't running in widget tests.
      creatureProvider.overrideWith((ref) => null),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const AppWidget(),
    ),
  );
  await tester.pumpAndSettle();
  _drainBenignOverflow(tester);
  return container;
}

void main() {
  testWidgets(
    'authenticated home with no creature shows the hatch form '
    '(name field + Hatch button)',
    (tester) async {
      final client = _buildClient();
      // Authenticated before first paint → the guard keeps the user on /.
      await client.auth.updateSignedInUser(_authSuccess());

      final container = await _pumpApp(tester, client);
      expect(_currentPath(container), '/');

      // S-02 empty state: the creature provider resolved to null, so the home
      // shows the hatch affordance — a name field and a Hatch button (this is
      // the assertion S-01 deliberately inverted: a button now exists).
      expect(find.byType(TextField), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Hatch'), findsOneWidget);
      // Still no anonymous "Sign in" button — the gate guarantees a real user.
      expect(find.text('Sign in'), findsNothing);
    },
  );

  testWidgets(
    'tapping log-out signs the user out and the guard bounces to /sign-in',
    (tester) async {
      final client = _buildClient();
      await client.auth.updateSignedInUser(_authSuccess());

      final container = await _pumpApp(tester, client);
      expect(_currentPath(container), '/');

      // A visible, text-labelled log-out control is present (a bare icon can
      // render blank on web when the icon font is stale).
      final logout = find.widgetWithText(TextButton, 'Log out');
      expect(logout, findsOneWidget);

      // The log-out action drives client.auth.signOutDevice(): whether or not
      // the server round-trip succeeds, its `finally` clears local auth state,
      // and the guard's refreshListenable then bounces to /sign-in.
      await tester.tap(logout);
      await tester.runAsync(() async {
        for (var i = 0; i < 100 && client.auth.isAuthenticated; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pumpAndSettle();
      _drainBenignOverflow(tester);

      expect(client.auth.isAuthenticated, isFalse);
      expect(_currentPath(container), '/sign-in');
    },
  );
}
