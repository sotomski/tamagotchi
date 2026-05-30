import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';
import 'package:tamagotchi_client/tamagotchi_client.dart';

import '../app/client_provider.dart';

/// Sign-in screen. Shows the Serverpod [SignInWidget] while unauthenticated and
/// returns to `/` once the user signs in.
///
/// Ported from the old `lib/screens/sign_in_screen.dart`: reads the [Client]
/// from Riverpod instead of the deleted global, and drops the `child`
/// constructor parameter — routing now controls what comes after sign-in, not
/// widget nesting. No auth guard yet (S-01 adds the redirect).
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  late final Client _client;

  @override
  void initState() {
    super.initState();
    _client = ref.read(serverpodClientProvider);
    _client.auth.authInfoListenable.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _client.auth.authInfoListenable.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    if (_client.auth.isAuthenticated) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(serverpodClientProvider);

    if (client.auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Center(
        child: SignInWidget(
          client: client,
          onAuthenticated: () {
            if (context.mounted) context.go('/');
          },
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
