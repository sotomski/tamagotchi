import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'mistral_client.dart';
import 'stub_llm_service.dart';

/// The volatile, per-call state handed to the LLM to shape one creature
/// interaction. Server-internal (never crosses the RPC boundary), so it is a
/// plain Dart class rather than a Serverpod model — the prompt builder and the
/// service implementations are the only consumers.
///
/// Two output fields come back ([LlmService.generateInteraction]); the funny
/// food name is NOT a field — the prompt instructs the model to invent one whose
/// fanciness matches [tastiness] and weave it into the prose.
class InteractionRequest {
  const InteractionRequest({
    required this.personality,
    required this.hunger,
    required this.energy,
    required this.love,
    required this.illness,
    required this.mood,
    required this.interactionType,
    required this.accepted,
    required this.tastiness,
    required this.recentEntries,
  });

  /// The creature's rolled decay/regen modifiers — its disposition, summarised
  /// into the prompt so the response reads in-character.
  final CreaturePersonality personality;

  /// Current raw stats (0-100). `hunger=0` means full.
  final int hunger;
  final int energy;
  final int love;
  final int illness;

  /// Mood derived from the current stats.
  final CreatureMood mood;

  /// Which interaction this is. Feed-only this slice (S-03), but typed for reuse
  /// by Pet/Cure (S-04/S-05).
  final JournalEvent interactionType;

  /// Whether the creature accepted the interaction. Drives accept- vs
  /// refuse-appropriate prose; the picky accept/reject roll happens upstream.
  final bool accepted;

  /// Food tastiness `[0,1)` rolled upstream — higher = fancier. The prompt turns
  /// it into the invented food's fanciness; it never moves stat magnitudes.
  final double tastiness;

  /// Up to the last 10 non-empty journal prose entries (newest first), the
  /// creature's short-term memory window (ORQ-1).
  final List<String> recentEntries;
}

/// The seam the Feed endpoint depends on, so the deterministic layer is testable
/// against a stub without a live model. Implemented by [MistralLlmService] (real)
/// and [StubLlmService] (no network).
abstract interface class LlmService {
  /// Produces the user-facing in-character response and the journal narrative
  /// for one interaction. The two are generated together so they stay coherent.
  Future<({String userResponse, String journalNarrative})> generateInteraction(
    Session session,
    InteractionRequest request,
  );
}

/// Picks the real client vs the stub by key presence — NOT by run mode. A
/// non-empty `mistralApiKey` password means dev (local key) and prod
/// (scloud-injected) both hit the real API, while the test run mode (no
/// `passwords.yaml` entry) stays hermetic on the stub. This deliberately
/// diverges from the EmailLabs run-mode gate so dev can manually exercise the
/// model.
LlmService llmServiceFor(Session session) =>
    llmServiceForKey(session.passwords['mistralApiKey']);

/// The pure key→service decision behind [llmServiceFor], split out so it is
/// unit-testable without constructing a [Session]: a non-empty key selects the
/// real [MistralLlmService], a null/empty key the [StubLlmService].
LlmService llmServiceForKey(String? mistralApiKey) {
  if (mistralApiKey != null && mistralApiKey.isNotEmpty) {
    return MistralLlmService();
  }
  return StubLlmService();
}
