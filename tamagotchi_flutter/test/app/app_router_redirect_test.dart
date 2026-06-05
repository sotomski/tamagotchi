import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';
import 'package:tamagotchi_client/tamagotchi_client.dart';
import 'package:tamagotchi_flutter/app/app_router.dart';
import 'package:tamagotchi_flutter/app/app_widget.dart';
import 'package:tamagotchi_flutter/app/client_provider.dart';

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
/// controllable from the test (no secure storage, no network).
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
/// test viewport — a layout quirk inside the dependency, unrelated to the
/// redirect under test. Drain those so they don't fail the test, but re-throw
/// anything else so genuine errors still surface.
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

Future<ProviderContainer> _pumpApp(WidgetTester tester, Client client) async {
  final container = ProviderContainer(
    overrides: [serverpodClientProvider.overrideWithValue(client)],
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
  testWidgets('redirects an unauthenticated user from / to /sign-in', (
    tester,
  ) async {
    final container = await _pumpApp(tester, _buildClient());

    expect(_currentPath(container), '/sign-in');
  });

  testWidgets('keeps an authenticated user on / (no bounce to /sign-in)', (
    tester,
  ) async {
    final client = _buildClient();
    // Authenticated before first paint, mirroring main()'s
    // `await client.auth.initialize()` settling state before runApp.
    await client.auth.updateSignedInUser(_authSuccess());

    final container = await _pumpApp(tester, client);

    expect(_currentPath(container), '/');
  });

  testWidgets('re-routes live when auth state flips (sign-in then sign-out)', (
    tester,
  ) async {
    final client = _buildClient();
    final container = await _pumpApp(tester, client);
    // Starts signed out → on the sign-in screen.
    expect(_currentPath(container), '/sign-in');

    // Signing in fires authInfoListenable → refreshListenable re-runs the
    // redirect, moving an authenticated user off /sign-in to /.
    await client.auth.updateSignedInUser(_authSuccess());
    await tester.pumpAndSettle();
    _drainBenignOverflow(tester);
    expect(_currentPath(container), '/');

    // Signing out flips it back: the guard bounces to /sign-in.
    await client.auth.updateSignedInUser(null);
    await tester.pumpAndSettle();
    _drainBenignOverflow(tester);
    expect(_currentPath(container), '/sign-in');
  });
}
