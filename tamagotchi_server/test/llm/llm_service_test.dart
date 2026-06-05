import 'package:tamagotchi_server/src/llm/llm_service.dart';
import 'package:tamagotchi_server/src/llm/mistral_client.dart';
import 'package:tamagotchi_server/src/llm/stub_llm_service.dart';
import 'package:test/test.dart';

void main() {
  group('llmServiceForKey (the pure decision behind llmServiceFor)', () {
    // Oracle = the plan's key-presence rule: a non-empty mistralApiKey selects
    // the real Mistral client; a null/empty key the hermetic stub. NOT run-mode
    // based — dev (local key) and prod (injected key) hit the real API, the test
    // run mode (no key) stays on the stub.
    test('null key -> StubLlmService', () {
      expect(llmServiceForKey(null), isA<StubLlmService>());
    });

    test('empty key -> StubLlmService', () {
      expect(llmServiceForKey(''), isA<StubLlmService>());
    });

    test('non-empty key -> MistralLlmService', () {
      expect(llmServiceForKey('sk-some-key'), isA<MistralLlmService>());
    });
  });
}
