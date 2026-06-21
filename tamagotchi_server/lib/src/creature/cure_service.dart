import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../llm/cure_copy.dart';
import '../llm/llm_service.dart';
import 'creature_service.dart';

/// The deterministic stat math behind curing the creature plus the LLM degrade
/// wrapper. Pure and DB-free where it can be — mirrors `play_service.dart`'s
/// style (small functions, one factory seam) and like play has **no RNG**:
/// curing is fully deterministic (`prd.md:39`). Cure relieves illness scaled by
/// `illnessDecayMod` (recovery responsiveness) and, per FR-006, costs **no
/// energy** and is always available — the math never reads energy as a guard.

/// Base illness relief one cure applies at the baseline personality
/// (`illnessDecayMod == 1.0`), scaled by the axis. Tunable magnitude. Over the
/// personality range `illnessDecayMod∈[0.5,1.5)` this yields relief ≈ 20–60.
const baseCureRelief = 40;

/// Illness relieved by a cure, scaled by the recovery-responsiveness axis. Range
/// ≈ 20 (sluggish, `illnessDecayMod` 0.5) → 60 (responsive, `~1.49`); monotone
/// ↑ — a more responsive creature recovers more per cure.
int cureRelief(double illnessDecayMod) =>
    (baseCureRelief * illnessDecayMod).round();

/// The deterministic stat change one cure applies to [c] given personality [p].
/// Illness falls by [cureRelief], clamp-encoded (the clamp lives in the delta)
/// so adding it lands the clamped target — illness floors at 0. Hunger, energy
/// and love never move; cure costs no energy (FR-006).
StatDelta cureDelta(Creature c, CreaturePersonality p) => StatDelta(
  illnessDelta:
      clampStat(c.illness - cureRelief(p.illnessDecayMod)) - c.illness,
  energyDelta: 0,
  hungerDelta: 0,
  loveDelta: 0,
);

/// The only impure collaborator a cure needs: the LLM. [CureService] wraps just
/// the model call plus the degrade fallback — there is no randomness seam
/// because curing has no random behaviour.
///
/// Production instances are assembled by [cureServiceFor] (the
/// key-presence-selected real/stub model). Tests construct one directly with a
/// stub or deliberately-failing [LlmService], so the endpoint never knows
/// whether its collaborator is real or fake.
class CureService {
  CureService({required LlmService llm}) : _llm = llm;

  final LlmService _llm;

  /// Produces the in-character response + journal narrative for one cure,
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
        'Cure LLM call failed; degrading to canned copy',
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

/// Builds the production [CureService] for [session]: the key-presence-selected
/// real/stub LLM ([llmServiceFor]). This is the only wiring the endpoint uses in
/// production — there is nothing to misconfigure at the call site.
CureService cureServiceFor(Session session) =>
    CureService(llm: llmServiceFor(session));

/// Dependency seam: the endpoint obtains its [CureService] through this, never by
/// constructing one. Defaults to the production wiring [cureServiceFor]; tests
/// reassign it to inject hermetic collaborators (a stub or failing
/// [LlmService]). Not a test-only member — it is the production injection point,
/// and its default *is* production.
CureService Function(Session session) cureServiceFactory = cureServiceFor;
