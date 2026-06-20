import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'feed_copy.dart';
import 'llm_service.dart';
import 'play_copy.dart' as play;

/// A no-network [LlmService] for key-less environments (test run mode, CI) and
/// as the default in widget/integration tests. Returns deterministic copy:
/// play-flavoured strings for a play interaction, otherwise the feed copy varying
/// by [InteractionRequest.accepted] so accept-vs-refuse paths are
/// distinguishable in assertions. Never throws.
class StubLlmService implements LlmService {
  const StubLlmService();

  @override
  Future<({String userResponse, String journalNarrative})> generateInteraction(
    Session session,
    InteractionRequest request,
  ) async {
    if (request.interactionType == JournalEvent.play) {
      return (
        userResponse: play.stubUserResponse,
        journalNarrative: play.stubJournalNarrative,
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
