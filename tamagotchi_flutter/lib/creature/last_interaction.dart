import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'last_interaction.g.dart';

/// The most-recent interaction outcome the shared response area renders: the
/// in-character `userResponse` plus whether the creature `accepted` (Feed can
/// refuse — styled distinctly; Pet always accepts). Feed and Play are different
/// result types, so this common record is the seam that lets one response
/// widget show whichever ran most recently.
typedef InteractionOutcome = ({String userResponse, bool accepted});

/// Holds the [InteractionOutcome] of the most recent Feed *or* Play. `null`
/// before the first interaction. Both controllers write it on success
/// (Feed passes its `accepted`; Play always passes `true`); [CreatureView] reads
/// it to render the shared response box.
@riverpod
class LastInteraction extends _$LastInteraction {
  @override
  InteractionOutcome? build() => null;

  void set({required String userResponse, required bool accepted}) {
    state = (userResponse: userResponse, accepted: accepted);
  }
}
