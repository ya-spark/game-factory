/// Family mode for Tug of war: two players take turns on one device. Pure Dart, no Flutter.
/// The rope and the rounds are [TugOfWarRun]; this adds the turn order, the first to
/// [roundsToWin] rounds taking the game, and the fair choice of settings.
library;

import '../../minigame_level.dart';
import 'tug_of_war_rules.dart';

/// Rounds a player needs to take the game.
const int familyRoundsToWin = 2;

/// Whether a child can play family Tug of war: has a year and it is inside the game's years
/// (in Scout, Year 3 and above).
bool familyTugEligibleYear(int? year, {int minYear = 0, int maxYear = 12}) =>
    year != null && year >= minYear && year <= maxYear;

/// Who may play: at least two eligible profiles are needed to show the button.
bool familyTugAvailable(
  Iterable<int?> years, {
  int minYear = 0,
  int maxYear = 12,
}) =>
    years
        .where(
          (y) => familyTugEligibleYear(y, minYear: minYear, maxYear: maxYear),
        )
        .length >=
    2;

/// The level both players use. If either would get the younger level, the gentler rules apply
/// to both; otherwise both use the older rules ([harder] for Champion).
MiniGameLevel familyTugLevel(
  Iterable<MiniGameLevel> levels, {
  bool harder = false,
}) {
  final allOlder = levels.every((l) => l.older);
  return allOlder
      ? MiniGameLevel.older(harder: harder)
      : const MiniGameLevel.younger();
}

enum FamilyTugEnd { none, round, game }

class FamilyTugRun {
  FamilyTugRun(this.level, {this.roundsToWin = familyRoundsToWin})
    : rope = TugOfWarRun(level);

  final MiniGameLevel level;
  final int roundsToWin;

  /// Position runs toward player 0 when positive, toward player 1 when negative.
  final TugOfWarRun rope;

  /// Whose turn it is: 0 or 1. Player 0 starts.
  int turn = 0;

  /// The player who took the last round, or null.
  int? lastRoundWinner;

  TugSettings get settings => rope.settings;
  int get position => rope.position;
  int roundsOf(int player) => player == 0 ? rope.roundsWon : rope.roundsLost;
  bool get isOver => winner != null;

  /// The player who took the game, or null while it is on.
  int? get winner {
    if (rope.roundsWon >= roundsToWin) return 0;
    if (rope.roundsLost >= roundsToWin) return 1;
    return null;
  }

  /// One answer by the player whose turn it is: a right answer pulls one step toward them; a
  /// wrong or slow one pulls one step back when the rules allow it. Then the turn passes.
  FamilyTugEnd answer({required bool correct}) {
    if (isOver) throw StateError('The game is over');
    final dir = turn == 0 ? 1 : -1;
    final end = rope.step(correct ? dir : (settings.pullsBack ? -dir : 0));
    lastRoundWinner = switch (end) {
      TugRoundEnd.won => 0,
      TugRoundEnd.lost => 1,
      TugRoundEnd.none => null,
    };
    if (isOver) return FamilyTugEnd.game;
    turn = 1 - turn;
    return end == TugRoundEnd.none ? FamilyTugEnd.none : FamilyTugEnd.round;
  }
}
