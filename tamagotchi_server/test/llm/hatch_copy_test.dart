import 'package:tamagotchi_server/src/llm/hatch_copy.dart' as hatch;
import 'package:test/test.dart';

void main() {
  group('hatch stub copy', () {
    // Oracle = the plan's Phase 3 contract: hatch_copy.dart holds STUB constants
    // only (no degrade copy — hatch blocks on failure instead of degrading). The
    // stub returns these deterministic birth strings in key-less environments.
    test('stub birth strings are non-empty', () {
      expect(hatch.stubUserResponse.trim(), isNotEmpty);
      expect(hatch.stubJournalNarrative.trim(), isNotEmpty);
    });

    test('stub user response and journal narrative are distinct', () {
      expect(hatch.stubUserResponse, isNot(hatch.stubJournalNarrative));
    });
  });
}
