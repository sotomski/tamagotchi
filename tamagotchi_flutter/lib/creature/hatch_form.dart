import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tamagotchi_client/tamagotchi_client.dart';

import 'hatch_controller.dart';

/// The empty-creature state: a name field and a Hatch button.
///
/// A blank name is blocked client-side (the controller is never called). While
/// the hatch is in flight the button is replaced by a spinner; a server-side
/// [CreatureHatchError] (e.g. a duplicate hatch) is rendered inline under the
/// field.
class HatchForm extends ConsumerStatefulWidget {
  const HatchForm({super.key});

  @override
  ConsumerState<HatchForm> createState() => _HatchFormState();
}

class _HatchFormState extends ConsumerState<HatchForm> {
  final _nameController = TextEditingController();

  /// Client-side validation message (blank name), cleared on a real submit.
  String? _localError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _localError = 'Please enter a name.');
      return;
    }
    setState(() => _localError = null);
    ref.read(hatchControllerProvider.notifier).hatch(name);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hatchControllerProvider);
    final isLoading = state.isLoading;
    final errorText = _localError ?? _hatchErrorText(state.error);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'No creature yet — hatch one to begin',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              enabled: !isLoading,
              decoration: InputDecoration(
                labelText: 'Name',
                errorText: errorText,
              ),
              onSubmitted: (_) {
                if (!isLoading) _submit();
              },
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Hatch'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Maps a hatch failure to an inline message. The typed [CreatureHatchError]
/// reasons get specific copy; anything else falls back to a generic retry hint.
String? _hatchErrorText(Object? error) {
  if (error == null) return null;
  if (error is CreatureHatchError) {
    switch (error.reason) {
      case CreatureHatchErrorReason.alreadyHatched:
        return 'You already have a creature.';
      case CreatureHatchErrorReason.emptyName:
        return 'Please enter a name.';
    }
  }
  return 'Could not hatch — please try again.';
}
