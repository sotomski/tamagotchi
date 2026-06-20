import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'feed_copy.dart';
import 'llm_service.dart';
import 'pet_copy.dart' as pet;

/// A no-network [LlmService] for key-less environments (test run mode, CI) and
/// as the default in widget/integration tests. Returns deterministic copy:
/// pet-flavoured strings for a pet interaction, otherwise the feed copy varying
/// by [InteractionRequest.accepted] so accept-vs-refuse paths are
/// distinguishable in assertions. Never throws.
class StubLlmService implements LlmService {
  const StubLlmService();

  @override
  Future<({String userResponse, String journalNarrative})> generateInteraction(
    Session session,
    InteractionRequest request,
  ) async {
    if (request.interactionType == JournalEvent.pet) {
      return (
        userResponse: pet.stubUserResponse,
        journalNarrative: pet.stubJournalNarrative,
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
