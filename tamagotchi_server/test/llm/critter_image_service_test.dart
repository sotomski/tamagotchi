import 'package:tamagotchi_server/src/llm/critter_image_service.dart';
import 'package:tamagotchi_server/src/llm/gemini_critter_image_service.dart';
import 'package:tamagotchi_server/src/llm/stub_critter_image_service.dart';
import 'package:test/test.dart';

void main() {
  group('critterImageServiceForKey (the pure decision behind '
      'critterImageServiceFor)', () {
    // Oracle = the plan's key-presence rule (copied from llmServiceForKey): a
    // non-empty geminiApiKey selects the real Gemini client; a null/empty key the
    // hermetic stub. NOT run-mode based — dev (local key) and prod (injected key)
    // hit the real API, the test/e2e run modes (no key) stay on the stub.
    test('null key -> StubCritterImageService', () {
      expect(critterImageServiceForKey(null), isA<StubCritterImageService>());
    });

    test('empty key -> StubCritterImageService', () {
      expect(critterImageServiceForKey(''), isA<StubCritterImageService>());
    });

    test('non-empty key -> GeminiCritterImageService', () {
      expect(
        critterImageServiceForKey('AIza-some-key'),
        isA<GeminiCritterImageService>(),
      );
    });
  });
}
