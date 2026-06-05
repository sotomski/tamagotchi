import 'package:tamagotchi_server/src/llm/feed_copy.dart';
import 'package:test/test.dart';

void main() {
  group('fullRefusalLines', () {
    // Oracle = the plan's Phase 1 contract: 10-20 funny "I'm stuffed" lines,
    // all non-empty, picked via the shared Random on the full-refusal path.
    test('has 10-20 entries', () {
      expect(fullRefusalLines.length, inInclusiveRange(10, 20));
    });

    test('every line is non-empty and trimmed', () {
      for (final line in fullRefusalLines) {
        expect(line.trim(), isNotEmpty);
      }
    });

    test('lines are distinct (no accidental duplicates)', () {
      expect(fullRefusalLines.toSet(), hasLength(fullRefusalLines.length));
    });
  });

  group('degrade + stub copy', () {
    test('degrade strings are non-empty', () {
      expect(degradeUserResponse.trim(), isNotEmpty);
      expect(degradeJournalNarrative.trim(), isNotEmpty);
    });

    test('stub accept/refuse strings are non-empty', () {
      expect(stubAcceptUserResponse.trim(), isNotEmpty);
      expect(stubAcceptJournalNarrative.trim(), isNotEmpty);
      expect(stubRefuseUserResponse.trim(), isNotEmpty);
      expect(stubRefuseJournalNarrative.trim(), isNotEmpty);
    });

    test('stub accept and refuse copy are distinguishable', () {
      // The stub varies by `accepted` so integration assertions can tell the
      // two paths apart — they must not collide.
      expect(stubAcceptUserResponse, isNot(stubRefuseUserResponse));
      expect(stubAcceptJournalNarrative, isNot(stubRefuseJournalNarrative));
    });
  });
}
