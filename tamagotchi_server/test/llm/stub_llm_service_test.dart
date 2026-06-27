import 'package:serverpod/serverpod.dart';
import 'package:tamagotchi_server/src/generated/protocol.dart';
import 'package:tamagotchi_server/src/llm/feed_copy.dart';
import 'package:tamagotchi_server/src/llm/hatch_copy.dart' as hatch;
import 'package:tamagotchi_server/src/llm/llm_service.dart';
import 'package:tamagotchi_server/src/llm/stub_llm_service.dart';
import 'package:test/test.dart';

CreaturePersonality _personality() => CreaturePersonality(
  creatureId: UuidValue.fromString('00000000-0000-7000-8000-000000000000'),
  hungerDecayMod: 1.0,
  hungerRegenMod: 1.0,
  energyDecayMod: 1.0,
  energyRegenMod: 1.0,
  loveRegenMod: 1.0,
  illnessDecayMod: 1.0,
  illnessRegenMod: 1.0,
);

InteractionRequest _hatchRequest() => InteractionRequest(
  personality: _personality(),
  name: 'Nibbles',
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

InteractionRequest _feedRefusalRequest(RefusalSeverity severity) =>
    InteractionRequest(
      personality: _personality(),
      hunger: 0,
      energy: 100,
      love: 50,
      illness: 0,
      mood: CreatureMood.content,
      interactionType: JournalEvent.feed,
      accepted: false,
      tastiness: 0,
      recentEntries: const [],
      refusalSeverity: severity,
    );

void main() {
  group('StubLlmService — hatched branch', () {
    // Oracle = the plan's Phase 3 contract: a hatched interaction returns the
    // deterministic birth copy, distinct from the feed accept/refuse fallback so
    // the hatch path is assertable in integration tests.
    test('returns the deterministic hatch birth copy', () async {
      final reply = await const StubLlmService().generateInteraction(
        _FakeSession(),
        _hatchRequest(),
      );

      expect(reply.userResponse, hatch.stubUserResponse);
      expect(reply.journalNarrative, hatch.stubJournalNarrative);
    });
  });

  group('StubLlmService — full-refusal branch', () {
    // Oracle = the plan's Phase 4 contract: a feed refused because the creature
    // is FULL returns the deterministic full-refusal copy, distinct from the
    // picky-refusal copy so the two refusals are assertable apart in integration.
    test(
      'returns the deterministic full-refusal copy for a full feed',
      () async {
        final reply = await const StubLlmService().generateInteraction(
          _FakeSession(),
          _feedRefusalRequest(RefusalSeverity.full),
        );

        expect(reply.userResponse, stubFullRefusalUserResponse);
        expect(reply.journalNarrative, stubFullRefusalJournalNarrative);
      },
    );

    test('a picky refusal still returns the distinct picky copy', () async {
      final reply = await const StubLlmService().generateInteraction(
        _FakeSession(),
        _feedRefusalRequest(RefusalSeverity.picky),
      );

      expect(reply.userResponse, stubRefuseUserResponse);
      expect(reply.journalNarrative, stubRefuseJournalNarrative);
      // The two refusals must not collide.
      expect(reply.userResponse, isNot(stubFullRefusalUserResponse));
    });
  });
}

/// The stub never touches the session, so a bare stand-in is enough to satisfy
/// the [LlmService] signature without booting Serverpod.
class _FakeSession implements Session {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Session is unused by the stub');
}
