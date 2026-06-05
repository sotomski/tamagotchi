import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import '../app/client_provider.dart';

/// The signed-in empty-creature home (S-01 / FR-001).
///
/// The router's auth gate guarantees an authenticated viewer here, so this is a
/// text-only "no creature yet" empty state — no anonymous "Sign in" button and
/// no Hatch button (hatching is S-02). The [AppBar] log-out action calls
/// `client.auth.signOutDevice()`; the gate's `refreshListenable` then bounces
/// the now-signed-out user back to `/sign-in`.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI-Tamagotchi'),
        actions: [
          // A text-labelled action (not a bare icon): the "Log out" label
          // renders from the app font, so it stays visible on Flutter web even
          // when the tree-shaken MaterialIcons subset is served stale from cache.
          TextButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
            onPressed: () =>
                ref.read(serverpodClientProvider).auth.signOutDevice(),
          ),
        ],
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No creature yet — hatch one to begin',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
