import 'package:flutter/material.dart';

/// Shows a modal confirmation gating the destructive reset.
///
/// Returns `true` only when the user taps the destructive **Reset** button;
/// `false` on Cancel or a barrier dismiss. The copy states the loss is
/// permanent. Labels are plain text ("Cancel" / "Reset") so e2e can reach them
/// by role/text rather than a test id.
Future<bool> showResetConfirmDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Reset creature?'),
      content: const Text(
        'This permanently deletes your creature and its entire journal. '
        'This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('resetConfirmButton'),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Reset'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
