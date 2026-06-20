import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../llm/llm_service.dart';
import '../llm/pet_copy.dart';
import 'creature_service.dart';

/// The deterministic stat math behind a pet plus the LLM degrade wrapper. Pure
/// and DB-free where it can be — mirrors `feed_service.dart`'s style (small
/// functions, one factory seam) but has **no RNG**: Pet is fully deterministic
/// (`prd.md:39`). The single introvert↔extravert axis is `loveRegenMod`: an
/// extravert gains more love and tires less; an introvert gains less and tires
/// more.

/// Base love gained on a pet at the baseline personality (`loveRegenMod == 1.0`),
/// scaled by the axis. Tunable magnitude.
const basePetLove = 15;

/// Base energy spent on a pet at the baseline personality, scaled inversely by
/// the axis (introverts pay more). Tunable magnitude.
const basePetEnergy = 4;

/// Love gained on a pet, scaled by the sociability axis. Range ≈ 8 (introvert,
/// `loveRegenMod` 0.5) → 22 (extravert, `~1.49`); monotone ↑.
int petLoveGain(double loveRegenMod) => (basePetLove * loveRegenMod).round();

/// Energy spent on a pet, scaled inversely by the sociability axis. Range ≈ 6
/// (introvert) → 2 (extravert); monotone ↓ — an introvert finds attention more
/// tiring, so it pays more.
int petEnergyCost(double loveRegenMod) =>
    (basePetEnergy * (2 - loveRegenMod)).round();

/// The deterministic stat change one pet applies to [c] given personality [p].
/// Love rises by [petLoveGain], energy falls by [petEnergyCost]; hunger and
/// illness never move. Each delta is clamp-encoded (the clamp lives in the
/// delta) so adding it lands the clamped target — love holds at 100, energy
/// floors at 0.
StatDelta petDelta(Creature c, CreaturePersonality p) => StatDelta(
  loveDelta: clampStat(c.love + petLoveGain(p.loveRegenMod)) - c.love,
  energyDelta: clampStat(c.energy - petEnergyCost(p.loveRegenMod)) - c.energy,
  hungerDelta: 0,
  illnessDelta: 0,
);

/// The only impure collaborator a pet needs: the LLM. [PetService] wraps just
/// the model call plus the degrade fallback — there is no randomness seam
/// because Pet has no random behaviour.
///
/// Production instances are assembled by [petServiceFor] (the
/// key-presence-selected real/stub model). Tests construct one directly with a
/// stub or deliberately-failing [LlmService], so the endpoint never knows
/// whether its collaborator is real or fake.
class PetService {
  PetService({required LlmService llm}) : _llm = llm;

  final LlmService _llm;

  /// Produces the in-character response + journal narrative for one pet,
  /// degrading to canned [degradeUserResponse]/[degradeJournalNarrative] if the
  /// model call throws — so a flaky/unreachable model never blocks the
  /// interaction and the stat+journal pair still commits.
  Future<({String userResponse, String journalNarrative})> interaction(
    Session session,
    InteractionRequest request,
  ) async {
    try {
      return await _llm.generateInteraction(session, request);
    } catch (e, stackTrace) {
      session.log(
        'Pet LLM call failed; degrading to canned copy',
        level: LogLevel.warning,
        exception: e,
        stackTrace: stackTrace,
      );
      return (
        userResponse: degradeUserResponse,
        journalNarrative: degradeJournalNarrative,
      );
    }
  }
}

/// Builds the production [PetService] for [session]: the key-presence-selected
/// real/stub LLM ([llmServiceFor]). This is the only wiring the endpoint uses in
/// production — there is nothing to misconfigure at the call site.
PetService petServiceFor(Session session) =>
    PetService(llm: llmServiceFor(session));

/// Dependency seam: the endpoint obtains its [PetService] through this, never by
/// constructing one. Defaults to the production wiring [petServiceFor]; tests
/// reassign it to inject hermetic collaborators (a stub or failing
/// [LlmService]). Not a test-only member — it is the production injection point,
/// and its default *is* production.
PetService Function(Session session) petServiceFactory = petServiceFor;
