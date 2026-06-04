import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/sign_in_screen.dart';
import '../home/home_screen.dart';

part 'app_router.g.dart';

/// The app's [GoRouter].
///
/// A flat two-route map. No auth guard yet — S-01 adds the redirect via a
/// `refreshListenable` tied to `client.auth.authInfoListenable`.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/',
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
