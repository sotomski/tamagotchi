import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import '../app/client_provider.dart';
import '../creature/creature_provider.dart';
import '../creature/creature_view.dart';
import '../creature/hatch_form.dart';
import '../creature/reset_confirm_dialog.dart';
import '../creature/reset_controller.dart';

/// The signed-in creature home (S-01 / S-02).
///
/// The router's auth gate guarantees an authenticated viewer here. The body is
/// driven by [creatureProvider]: a spinner while loading, an inline error with
/// retry on failure, the [HatchForm] empty state when the user has no creature,
/// and the [CreatureView] stats view once they do. The [AppBar] log-out action
/// calls `client.auth.signOutDevice()`; the gate's `refreshListenable` then
/// bounces the now-signed-out user back to `/sign-in`.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creatureStatus = ref.watch(creatureProvider);
    // Only offer Reset once a creature exists — there's nothing to delete from
    // the empty (HatchForm) state.
    final hasCreature = creatureStatus.asData?.value != null;
    // Watch (not just read) the reset controller so the auto-dispose provider
    // stays alive across its in-flight RPC: a bare `read` lets it dispose
    // between the await and the post-reset `invalidate(creatureProvider)`, so
    // the home never falls back to the HatchForm. Watching also gives us the
    // loading flag to disable the button mid-reset.
    final resetting = ref.watch(resetControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI-Tamagotchi'),
        actions: [
          // A text-labelled action (not a bare icon): the labels render from the
          // app font, so they stay visible on Flutter web even when the
          // tree-shaken MaterialIcons subset is served stale from cache.
          if (hasCreature)
            TextButton.icon(
              key: const Key('resetButton'),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset'),
              onPressed: resetting
                  ? null
                  : () async {
                      final confirmed = await showResetConfirmDialog(context);
                      if (confirmed) {
                        await ref
                            .read(resetControllerProvider.notifier)
                            .reset();
                      }
                    },
            ),
          TextButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
            onPressed: () =>
                ref.read(serverpodClientProvider).auth.signOutDevice(),
          ),
        ],
      ),
      body: creatureStatus.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            key: Key('creatureLoadingIndicator'),
          ),
        ),
        error: (error, _) => _CreatureLoadError(
          onRetry: () => ref.invalidate(creatureProvider),
        ),
        data: (status) =>
            status == null ? const HatchForm() : CreatureView(status: status),
      ),
    );
  }
}

/// Shown when [creatureProvider] fails to load — a message plus a retry that
/// re-invalidates the provider.
class _CreatureLoadError extends StatelessWidget {
  const _CreatureLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Could not load your creature.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
