import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Empty-state placeholder so the router has somewhere to land.
///
/// S-01 (FR-001) replaces this with the real signed-in empty-creature view.
/// For now it only proves the router + provider container boot in a known
/// state and gives the user something coherent to see on first run.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI-Tamagotchi')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No creature yet'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/sign-in'),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
