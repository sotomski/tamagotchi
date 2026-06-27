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
                      (
                        event: JournalEvent.feed,
                        age: 'earlier today',
                        prose: 'Devoured a glorious Quadruple-Truffle Soufflé.',
                      ),
                      (
                        event: JournalEvent.feed,
                        age: 'yesterday',
                        prose: 'Sulked when offered cold gruel.',
                      ),
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

    // Oracle = the plan's Phase 5 contract: the structured memory window renders
    // each entry's event kind + relative age + prose, and the seam invites the
    // model to refer back to earlier moments (backward callbacks). We assert
    // presence/structure, never exact prose.
    test(
      'structured window renders event + age + prose and invites callbacks',
      () {
        final user =
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
                      (
                        event: JournalEvent.play,
                        age: 'yesterday',
                        prose: 'Chased the ribbon across the terrarium.',
                      ),
                      (
                        event: JournalEvent.hatched,
                        age: 'a while back',
                        prose: 'I awoke as Nibbles and met my owner.',
                      ),
                    ],
                  ),
                )[1]['content']
                as String;

        // Each entry's event kind, relative age, and prose are rendered.
        expect(user, contains('play'));
        expect(user, contains('yesterday'));
        expect(user, contains('Chased the ribbon'));
        expect(user, contains('a while back'));
        expect(user, contains('I awoke as Nibbles'));
        // The seam invites the creature to refer back to earlier moments.
        expect(user.toLowerCase(), contains('refer back'));
      },
    );

    // Oracle = the plan's Phase 4 contract: a refused feed is prompted with its
    // severity so the model narrates fullness (stuffed) distinctly from distaste
    // (picky). We assert the reason is present and the two read differently —
    // never exact prose.
    test('a full refusal is framed as fullness, a picky one as distaste', () {
      String userFor(RefusalSeverity severity) =>
          buildInteractionMessages(
                InteractionRequest(
                  personality: _personality(),
                  hunger: 0,
                  energy: 90,
                  love: 64,
                  illness: 5,
                  mood: CreatureMood.content,
                  interactionType: JournalEvent.feed,
                  accepted: false,
                  tastiness: 0.2,
                  recentEntries: const [],
                  refusalSeverity: severity,
                ),
              )[1]['content']
              as String;

      final full = userFor(RefusalSeverity.full).toLowerCase();
      final picky = userFor(RefusalSeverity.picky).toLowerCase();

      // The full refusal reads as "too full"; the picky one as distaste.
      expect(full, contains('full'));
      expect(picky, contains('picky'));
      // The two refusals must be prompted differently.
      expect(full, isNot(picky));
    });
  });

  group('buildInteractionMessages — play branch', () {
    // Oracle = the plan's Phase 2 contract: when interactionType == play, the
    // system prompt keeps the in-character/no-chatbot guardrails but is about
    // PLAYING TOGETHER (no food, no tastiness), coloured by sociability; the user
    // message carries stats/mood/personality/memory and references neither
    // tastiness nor accepted. We assert presence/structure, never exact prose.
    InteractionRequest playRequest({
      List<JournalMemory> recentEntries = const [],
      CreatureMood mood = CreatureMood.content,
    }) => InteractionRequest(
      personality: _personality(),
      hunger: 42,
      energy: 73,
      love: 64,
      illness: 5,
      mood: mood,
      interactionType: JournalEvent.play,
      accepted: true,
      tastiness: 0,
      recentEntries: recentEntries,
    );

    test(
      'emits a play persona message with guardrails and sociability framing',
      () {
        final messages = buildInteractionMessages(playRequest());

        expect(messages, hasLength(2));
        expect(messages[0]['role'], 'system');
        expect(messages[1]['role'], 'user');

        final system = (messages[0]['content'] as String).toLowerCase();
        // Same in-character / no-chatbot guardrails as feed.
        expect(system, contains('in character'));
        expect(system, contains('language model'));
        // Play-specific: about playing together, coloured by sociability.
        expect(system, contains('play'));
        expect(system, contains('sociab'));
        // Two output fields unchanged.
        expect(messages[0]['content'] as String, contains('userResponse'));
        expect(messages[0]['content'] as String, contains('journalNarrative'));
        // No food / tastiness wording leaks into the play persona.
        expect(system, isNot(contains('food')));
        expect(system, isNot(contains('tastiness')));
      },
    );

    test(
      'play user message carries stats, mood, and personality; no tastiness',
      () {
        final user =
            buildInteractionMessages(
                  playRequest(mood: CreatureMood.sad),
                )[1]['content']
                as String;

        // Stats present (each raw value rendered).
        expect(user, contains('42'));
        expect(user, contains('73'));
        expect(user, contains('64'));
        // Mood name present.
        expect(user, contains('sad'));
        // Personality summary present (a distinctive modifier value).
        expect(user, contains('1.40'));
        // Play does not reference tastiness or the accept/refuse decision.
        expect(user.toLowerCase(), isNot(contains('tastiness')));
        expect(user.toLowerCase(), isNot(contains('accepted')));
      },
    );

    test('play user message includes the recent-memory window', () {
      final withMemory =
          buildInteractionMessages(
                playRequest(
                  recentEntries: const [
                    (
                      event: JournalEvent.play,
                      age: 'earlier today',
                      prose: 'Basked in a long afternoon of scritches.',
                    ),
                    (
                      event: JournalEvent.play,
                      age: 'yesterday',
                      prose: 'Sulked alone by the water bowl.',
                    ),
                  ],
                ),
              )[1]['content']
              as String;

      expect(withMemory, contains('afternoon of scritches'));
      expect(withMemory, contains('water bowl'));
    });
  });

  group('buildInteractionMessages — hatched branch', () {
    // Oracle = the plan's Phase 3 contract: when interactionType == hatched, the
    // system prompt keeps the in-character/no-chatbot guardrails but is about
    // BEING BORN / first awakening (no food, no tastiness), and the user message
    // introduces the creature by name and carries its personality so the model
    // can describe its character. We assert presence/structure, never exact prose.
    InteractionRequest hatchRequest({String name = 'Nibbles'}) =>
        InteractionRequest(
          personality: _personality(),
          name: name,
          hunger: 0,
          energy: 100,
          love: 50,
          illness: 0,
          mood: CreatureMood.content,
          interactionType: JournalEvent.hatched,
          accepted: true,
          tastiness: 0,
          recentEntries: const [],
        );

    test('emits a birth persona message with guardrails and no food', () {
      final messages = buildInteractionMessages(hatchRequest());

      expect(messages, hasLength(2));
      expect(messages[0]['role'], 'system');
      expect(messages[1]['role'], 'user');

      final system = (messages[0]['content'] as String).toLowerCase();
      // Same in-character / no-chatbot guardrails as the other interactions.
      expect(system, contains('in character'));
      expect(system, contains('language model'));
      // Birth-specific: about being born / hatching / first awakening.
      expect(
        system,
        anyOf(contains('born'), contains('hatch'), contains('awak')),
      );
      // Two output fields unchanged.
      expect(messages[0]['content'] as String, contains('userResponse'));
      expect(messages[0]['content'] as String, contains('journalNarrative'));
      // No food / tastiness wording leaks into the birth persona.
      expect(system, isNot(contains('food')));
      expect(system, isNot(contains('tastiness')));
    });

    test('hatch user message names the creature and carries personality', () {
      final user =
          buildInteractionMessages(
                hatchRequest(name: 'Wobblesworth'),
              )[1]['content']
              as String;

      // The creature is introduced by name so the birth narrative can use it.
      expect(user, contains('Wobblesworth'));
      // Personality summary present (a distinctive modifier value).
      expect(user, contains('1.40'));
      // Birth has no food/tastiness or accept/refuse decision.
      expect(user.toLowerCase(), isNot(contains('tastiness')));
    });
  });

  group('buildInteractionMessages — cure branch', () {
    // Oracle = the plan's Phase 1 contract: when interactionType == cure, the
    // system prompt keeps the in-character/no-chatbot guardrails but is about
    // RECOVERING / feeling better (no food, no tastiness); the user message
    // carries stats/mood/personality/memory and references neither tastiness nor
    // accepted. We assert presence/structure, never exact prose.
    InteractionRequest cureRequest({
      List<JournalMemory> recentEntries = const [],
      CreatureMood mood = CreatureMood.sick,
      int illness = 70,
    }) => InteractionRequest(
      personality: _personality(),
      hunger: 42,
      energy: 73,
      love: 64,
      illness: illness,
      mood: mood,
      interactionType: JournalEvent.cure,
      accepted: true,
      tastiness: 0,
      recentEntries: recentEntries,
    );

    test(
      'emits a cure persona message with guardrails and recovery framing',
      () {
        final messages = buildInteractionMessages(cureRequest());

        expect(messages, hasLength(2));
        expect(messages[0]['role'], 'system');
        expect(messages[1]['role'], 'user');

        final system = (messages[0]['content'] as String).toLowerCase();
        // Same in-character / no-chatbot guardrails as feed and play.
        expect(system, contains('in character'));
        expect(system, contains('language model'));
        // Cure-specific: about recovering / feeling better.
        expect(system, anyOf(contains('better'), contains('recover')));
        // Two output fields unchanged.
        expect(messages[0]['content'] as String, contains('userResponse'));
        expect(messages[0]['content'] as String, contains('journalNarrative'));
        // No food / tastiness wording leaks into the cure persona.
        expect(system, isNot(contains('food')));
        expect(system, isNot(contains('tastiness')));
      },
    );

    test(
      'cure user message carries stats, mood, and personality; no tastiness',
      () {
        final user =
            buildInteractionMessages(
                  cureRequest(mood: CreatureMood.sick),
                )[1]['content']
                as String;

        // Stats present (each raw value rendered).
        expect(user, contains('42'));
        expect(user, contains('73'));
        expect(user, contains('64'));
        expect(user, contains('70'));
        // Mood name present.
        expect(user, contains('sick'));
        // Personality summary present (a distinctive modifier value).
        expect(user, contains('1.40'));
        // Cure does not reference tastiness or the accept/refuse decision.
        expect(user.toLowerCase(), isNot(contains('tastiness')));
        expect(user.toLowerCase(), isNot(contains('accepted')));
      },
    );

    test('cure user message includes the recent-memory window', () {
      final withMemory =
          buildInteractionMessages(
                cureRequest(
                  recentEntries: const [
                    (
                      event: JournalEvent.cure,
                      age: 'earlier today',
                      prose: 'Shivered with fever through the long night.',
                    ),
                    (
                      event: JournalEvent.cure,
                      age: 'yesterday',
                      prose: 'Sniffled miserably by the heat lamp.',
                    ),
                  ],
                ),
              )[1]['content']
              as String;

      expect(withMemory, contains('Shivered with fever'));
      expect(withMemory, contains('heat lamp'));
    });
  });
}
