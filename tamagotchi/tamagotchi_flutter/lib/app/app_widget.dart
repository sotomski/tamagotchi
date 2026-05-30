import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';

/// Root widget. Consumes the router provider and mounts [MaterialApp.router].
class AppWidget extends ConsumerWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'AI-Tamagotchi',
      theme: ThemeData(useMaterial3: true),
      routerConfig: router,
    );
  }
}
