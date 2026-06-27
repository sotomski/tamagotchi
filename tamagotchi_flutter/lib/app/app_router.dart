import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import '../auth/sign_in_screen.dart';
import '../home/home_screen.dart';
import 'client_provider.dart';

part 'app_router.g.dart';

/// The app's [GoRouter] with the S-01 auth gate.
///
/// Watches [serverpodClientProvider] for `client.auth`: a `redirect` bounces
/// unauthenticated users to `/sign-in` and keeps authenticated users on the
/// app surface, while `refreshListenable` re-evaluates the redirect live on
/// every sign-in / sign-out (the listenable fires when `authInfo` changes).
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final client = ref.watch(serverpodClientProvider);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: client.auth.authInfoListenable,
    redirect: (context, state) {
      final isAuthenticated = client.auth.isAuthenticated;
      final isOnSignIn = state.matchedLocation == '/sign-in';
      if (!isAuthenticated && !isOnSignIn) return '/sign-in';
      if (isAuthenticated && isOnSignIn) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
    ],
  );
}
