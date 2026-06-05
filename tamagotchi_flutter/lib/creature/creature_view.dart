import 'package:flutter/material.dart';
import 'package:tamagotchi_client/tamagotchi_client.dart';

/// The present-creature state: the creature's name, its derived [mood] label,
/// and the four raw stat numbers (0–100, raw per MVP — no icons/bars).
class CreatureView extends StatelessWidget {
  const CreatureView({required this.status, super.key});

  final CreatureStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final creature = status.creature;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(creature.name, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Mood: ${status.mood.name}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            _StatRow(label: 'Hunger', value: creature.hunger),
            _StatRow(label: 'Energy', value: creature.energy),
            _StatRow(label: 'Love', value: creature.love),
            _StatRow(label: 'Illness', value: creature.illness),
          ],
        ),
      ),
    );
  }
}

/// One labelled stat line, e.g. `Energy  100`.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 100, child: Text(label)),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
