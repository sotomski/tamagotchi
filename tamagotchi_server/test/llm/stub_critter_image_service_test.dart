import 'package:serverpod/serverpod.dart';
import 'package:tamagotchi_server/src/generated/protocol.dart';
import 'package:tamagotchi_server/src/llm/critter_image_prompt.dart';
import 'package:tamagotchi_server/src/llm/stub_critter_image_service.dart';
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

CritterImageRequest _request() =>
    CritterImageRequest(personality: _personality(), name: 'Nibbles', seed: 42);

void main() {
  group('StubCritterImageService', () {
    // Oracle = the plan's Phase 2 contract: the stub returns a non-empty, valid
    // JPEG (so a hermetic hatch succeeds and the e2e app can render it) and never
    // throws.
    test(
      'returns non-empty bytes framed by the JPEG SOI/EOI markers',
      () async {
        final bytes = await const StubCritterImageService().generateImage(
          _FakeSession(),
          _request(),
        );

        expect(bytes, isNotEmpty);
        // SOI (FF D8 FF) opens every JPEG; EOI (FF D9) closes it.
        expect(bytes.sublist(0, 3), [0xFF, 0xD8, 0xFF]);
        expect(bytes.sublist(bytes.length - 2), [0xFF, 0xD9]);
      },
    );

    test('is deterministic across calls (and never throws)', () async {
      final first = await const StubCritterImageService().generateImage(
        _FakeSession(),
        _request(),
      );
      final second = await const StubCritterImageService().generateImage(
        _FakeSession(),
        _request(),
      );

      expect(first, second);
    });
  });
}

/// The stub never touches the session, so a bare stand-in is enough to satisfy
/// the [CritterImageService] signature without booting Serverpod.
class _FakeSession implements Session {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Session is unused by the stub');
}
