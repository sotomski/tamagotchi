import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import '../app/client_provider.dart';

/// Sign-in screen. Shows the Serverpod [SignInWidget] while unauthenticated.
///
/// Post-sign-in navigation is owned entirely by the router's auth gate
/// (`appRouter`'s `redirect` + `refreshListenable` on
/// `client.auth.authInfoListenable`). Navigating here on `onAuthenticated`
/// would fight that guard and cause a re-sign-in loop, so this screen no longer
/// routes — it only surfaces auth errors.
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(serverpodClientProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Center(
        child: SignInWidget(
          client: client,
          onError: (error) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Authentication failed: $error'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          },
        ),
      ),
    );
  }
}
