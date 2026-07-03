import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'retro_theme.dart';

/// Built once (lazily on first use) — the retro theme is immutable, so there's
/// no need to reconstruct a full [ThemeData] on every [AppWidget] rebuild.
final ThemeData _retroTheme = buildRetroTheme();

/// Root widget. Consumes the router provider and mounts [MaterialApp.router].
class AppWidget extends ConsumerWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'AI-Tamagotchi',
      theme: _retroTheme,
      routerConfig: router,
    );
  }
}
