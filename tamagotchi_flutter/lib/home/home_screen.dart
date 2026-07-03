import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';
import 'package:tamagotchi_client/tamagotchi_client.dart';

import '../app/client_provider.dart';
import '../app/retro_loader.dart';
import '../creature/creature_provider.dart';
import '../creature/creature_view.dart';
import '../creature/hatch_form.dart';
import '../creature/journal_view.dart';
import '../creature/reset_confirm_dialog.dart';
import '../creature/reset_controller.dart';

/// The signed-in creature home (S-01 / S-02).
///
/// The router's auth gate guarantees an authenticated viewer here. The body is
/// driven by [creatureProvider]: a spinner while loading, an inline error with
/// retry on failure, the [HatchForm] empty state when the user has no creature,
/// and — once a creature exists — the responsive [HomeBody] (two-pane
/// [CreatureView] | [JournalView] on a wide window, Creature/Journal tabs on a
/// narrow one). The [AppBar] log-out action calls `client.auth.signOutDevice()`;
/// the gate's `refreshListenable` then bounces the now-signed-out user back to
/// `/sign-in`.
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
    // Surface a reset failure the way every sibling controller surfaces its
    // errors: the confirm dialog is already gone and the creature is still
    // present, so a SnackBar is the one-shot feedback that the delete didn't
    // happen — without it the button just silently re-enables.
    ref.listen(resetControllerProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            key: Key('resetErrorSnackBar'),
            content: Text('Could not reset — please try again.'),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI-Tamagotchi'),
        // The default actionsPadding is EdgeInsets.zero, so the trailing Log out
        // button otherwise hugs the right edge. Inset it so it sits off the edge
        // symmetrically with the toolbar's vertical breathing room.
        actionsPadding: const EdgeInsets.only(right: 8),
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
          child: RetroLoader(key: Key('creatureLoadingIndicator')),
        ),
        error: (error, _) => _CreatureLoadError(
          onRetry: () => ref.invalidate(creatureProvider),
        ),
        // No creature → just the hatch form. With a creature → the responsive
        // two-pane / tabbed body.
        data: (status) =>
            status == null ? const HatchForm() : HomeBody(status: status),
      ),
    );
  }
}

/// The present-creature home body, laid out by viewport width.
///
/// [CreatureView] and [JournalView] both stay fully usable on a phone: at or
/// above [_wideBreakpoint] they sit side-by-side (the desktop two-pane split
/// with a [VerticalDivider]); below it — a phone-shaped window — they split into
/// Creature / Journal tabs so neither half is squeezed into an unusable column.
///
/// A plain [StatelessWidget] (not a `ConsumerWidget`): [CreatureView] already
/// takes its [status] directly and does its own provider watching, so this
/// layout shell needs no `ref`. Extracted from [HomeScreen] so the breakpoint is
/// unit-testable without the auth/reset chrome (see `home_layout_test.dart`).
class HomeBody extends StatelessWidget {
  const HomeBody({required this.status, super.key});

  final CreatureStatus status;

  /// Width at/above which the two panes sit side-by-side; below it they tab.
  static const double _wideBreakpoint = 700;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _wideBreakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: CreatureView(status: status)),
              const VerticalDivider(width: 1),
              const Expanded(child: JournalView()),
            ],
          );
        }
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Creature'),
                  Tab(text: 'Journal'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    CreatureView(status: status),
                    const JournalView(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
