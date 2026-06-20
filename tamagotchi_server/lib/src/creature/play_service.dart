import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../llm/llm_service.dart';
import '../llm/play_copy.dart';
import 'creature_service.dart';

/// The deterministic stat math behind playing with the creature plus the LLM
/// degrade wrapper. Pure and DB-free where it can be — mirrors
/// `feed_service.dart`'s style (small functions, one factory seam) but has **no
/// RNG**: playing is fully deterministic (`prd.md:39`). The single
/// introvert↔extravert axis is `loveRegenMod`: an extravert gains more love and
/// tires less; an introvert gains less and tires more.

/// Base love gained from a play session at the baseline personality
/// (`loveRegenMod == 1.0`), scaled by the axis. Tunable magnitude.
const basePlayLove = 15;

/// Base energy spent on a play session at the baseline personality, scaled
/// inversely by the axis (introverts pay more). Tunable magnitude.
const basePlayEnergy = 4;

/// Love gained from playing, scaled by the sociability axis. Range ≈ 8
/// (introvert, `loveRegenMod` 0.5) → 22 (extravert, `~1.49`); monotone ↑.
int playLoveGain(double loveRegenMod) => (basePlayLove * loveRegenMod).round();

/// Energy spent playing, scaled inversely by the sociability axis. Range ≈ 6
/// (introvert) → 2 (extravert); monotone ↓ — an introvert finds a boisterous
/// romp more tiring, so it pays more.
int playEnergyCost(double loveRegenMod) =>
    (basePlayEnergy * (2 - loveRegenMod)).round();

/// The deterministic stat change one play session applies to [c] given
/// personality [p]. Love rises by [playLoveGain], energy falls by
/// [playEnergyCost]; hunger and illness never move. Each delta is clamp-encoded
/// (the clamp lives in the delta) so adding it lands the clamped target — love
/// holds at 100, energy floors at 0.
StatDelta playDelta(Creature c, CreaturePersonality p) => StatDelta(
  loveDelta: clampStat(c.love + playLoveGain(p.loveRegenMod)) - c.love,
  energyDelta: clampStat(c.energy - playEnergyCost(p.loveRegenMod)) - c.energy,
  hungerDelta: 0,
  illnessDelta: 0,
);

/// The only impure collaborator a play session needs: the LLM. [PlayService]
/// wraps just the model call plus the degrade fallback — there is no randomness
/// seam because playing has no random behaviour.
///
/// Production instances are assembled by [playServiceFor] (the
/// key-presence-selected real/stub model). Tests construct one directly with a
/// stub or deliberately-failing [LlmService], so the endpoint never knows
/// whether its collaborator is real or fake.
class PlayService {
  PlayService({required LlmService llm}) : _llm = llm;

  final LlmService _llm;

  /// Produces the in-character response + journal narrative for one play
  /// session, degrading to canned [degradeUserResponse]/[degradeJournalNarrative]
  /// if the model call throws — so a flaky/unreachable model never blocks the
  /// interaction and the stat+journal pair still commits.
  Future<({String userResponse, String journalNarrative})> interaction(
    Session session,
    InteractionRequest request,
  ) async {
    try {
      return await _llm.generateInteraction(session, request);
    } catch (e, stackTrace) {
      session.log(
        'Play LLM call failed; degrading to canned copy',
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

/// Builds the production [PlayService] for [session]: the key-presence-selected
/// real/stub LLM ([llmServiceFor]). This is the only wiring the endpoint uses in
/// production — there is nothing to misconfigure at the call site.
PlayService playServiceFor(Session session) =>
    PlayService(llm: llmServiceFor(session));

/// Dependency seam: the endpoint obtains its [PlayService] through this, never by
/// constructing one. Defaults to the production wiring [playServiceFor]; tests
/// reassign it to inject hermetic collaborators (a stub or failing
/// [LlmService]). Not a test-only member — it is the production injection point,
/// and its default *is* production.
PlayService Function(Session session) playServiceFactory = playServiceFor;
