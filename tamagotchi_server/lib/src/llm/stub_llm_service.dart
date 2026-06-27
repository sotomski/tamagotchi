import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'cure_copy.dart' as cure;
import 'feed_copy.dart';
import 'hatch_copy.dart' as hatch;
import 'llm_service.dart';
import 'play_copy.dart' as play;

/// A no-network [LlmService] for key-less environments (test run mode, CI) and
/// as the default in widget/integration tests. Returns deterministic copy:
/// birth-flavoured strings for a hatched interaction, play-flavoured strings for
/// a play interaction, cure-flavoured strings for a cure interaction, otherwise
/// the feed copy varying by
/// [InteractionRequest.accepted] so accept-vs-refuse paths are distinguishable in
/// assertions. Never throws.
class StubLlmService implements LlmService {
  const StubLlmService();

  @override
  Future<({String userResponse, String journalNarrative})> generateInteraction(
    Session session,
    InteractionRequest request,
  ) async {
    if (request.interactionType == JournalEvent.hatched) {
      return (
        userResponse: hatch.stubUserResponse,
        journalNarrative: hatch.stubJournalNarrative,
      );
    }
    if (request.interactionType == JournalEvent.play) {
      return (
        userResponse: play.stubUserResponse,
        journalNarrative: play.stubJournalNarrative,
      );
    }
    if (request.interactionType == JournalEvent.cure) {
      return (
        userResponse: cure.stubUserResponse,
        journalNarrative: cure.stubJournalNarrative,
      );
    }
    if (request.accepted) {
      return (
        userResponse: stubAcceptUserResponse,
        journalNarrative: stubAcceptJournalNarrative,
      );
    }
    return (
      userResponse: stubRefuseUserResponse,
      journalNarrative: stubRefuseJournalNarrative,
    );
  }
}
