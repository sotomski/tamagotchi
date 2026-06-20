import 'package:serverpod/serverpod.dart';
import 'package:tamagotchi_server/src/generated/protocol.dart';
import 'package:tamagotchi_server/src/llm/creature_prompt.dart';
import 'package:tamagotchi_server/src/llm/llm_service.dart';
import 'package:test/test.dart';

/// Builds a personality with distinct, recognisable modifier values so the
/// summary's presence can be asserted without pinning exact wording.
CreaturePersonality _personality() => CreaturePersonality(
  creatureId: UuidValue.fromString('00000000-0000-7000-8000-000000000000'),
  hungerDecayMod: 0.60,
  hungerRegenMod: 1.10,
  energyDecayMod: 0.90,
  energyRegenMod: 1.20,
  loveRegenMod: 1.30,
  illnessDecayMod: 0.80,
  illnessRegenMod: 1.40,
);

void main() {
  group('buildInteractionMessages', () {
    // Oracle = the plan's Phase 1 contract: a system persona message + a user
    // message carrying the volatile state (stats, mood, accepted, tastiness,
    // recent entries). We assert presence/structure, never exact prose.
    test('emits a system persona message then a user state message', () {
      final messages = buildInteractionMessages(
        InteractionRequest(
          personality: _personality(),
          hunger: 42,
          energy: 73,
          love: 64,
          illness: 5,
          mood: CreatureMood.content,
          interactionType: JournalEvent.feed,
          accepted: true,
          tastiness: 0.81,
          recentEntries: const [],
        ),
      );

      expect(messages, hasLength(2));
      expect(messages[0]['role'], 'system');
      expect(messages[1]['role'], 'user');

      final system = messages[0]['content'] as String;
      // The guardrail (stay in character, no chatbot/AI/disclaimer language) and
      // the food-naming instruction must be fixed in the persona message.
      expect(system.toLowerCase(), contains('in character'));
      expect(system.toLowerCase(), contains('language model'));
      expect(system.toLowerCase(), contains('food'));
      expect(system, contains('userResponse'));
      expect(system, contains('journalNarrative'));
    });

    test('user message carries stats, mood, accepted, tastiness', () {
      final user =
          buildInteractionMessages(
                InteractionRequest(
                  personality: _personality(),
                  hunger: 42,
                  energy: 73,
                  love: 64,
                  illness: 5,
                  mood: CreatureMood.sad,
                  interactionType: JournalEvent.feed,
                  accepted: false,
                  tastiness: 0.07,
                  recentEntries: const [],
                ),
              )[1]['content']
              as String;

      // Stats present (each raw value rendered).
      expect(user, contains('42'));
      expect(user, contains('73'));
      expect(user, contains('64'));
      expect(user, contains('5'));
      // Mood name present.
      expect(user, contains('sad'));
      // The accept decision and tastiness drive accept-vs-refuse prose.
      expect(user, contains('false'));
      expect(user, contains('0.07'));
      // Personality summary present (a distinctive modifier value).
      expect(user, contains('1.40'));
    });

    test(
      'recent entries appear in the user message; empty renders a placeholder',
      () {
        final withMemory =
            buildInteractionMessages(
                  InteractionRequest(
                    personality: _personality(),
                    hunger: 10,
                    energy: 90,
                    love: 80,
                    illness: 0,
                    mood: CreatureMood.happy,
                    interactionType: JournalEvent.feed,
                    accepted: true,
                    tastiness: 0.5,
                    recentEntries: const [
                      'Devoured a glorious Quadruple-Truffle Soufflé.',
                      'Sulked when offered cold gruel.',
                    ],
                  ),
                )[1]['content']
                as String;

        expect(withMemory, contains('Quadruple-Truffle Soufflé'));
        expect(withMemory, contains('cold gruel'));

        final noMemory =
            buildInteractionMessages(
                  InteractionRequest(
                    personality: _personality(),
                    hunger: 10,
                    energy: 90,
                    love: 80,
                    illness: 0,
                    mood: CreatureMood.happy,
                    interactionType: JournalEvent.feed,
                    accepted: true,
                    tastiness: 0.5,
                    recentEntries: const [],
                  ),
                )[1]['content']
                as String;

        expect(noMemory.toLowerCase(), contains('no earlier entries'));
      },
    );
  });
}
