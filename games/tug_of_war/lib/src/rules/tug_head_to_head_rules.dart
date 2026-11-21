/// Tug of war, head to head: two players race on the same question. Pure Dart, no Flutter. The
/// rope is [TugOfWarRun]; this adds the two players, the per-question lock-outs and the end of
/// a round and of the game. Nothing here touches a quiz session: no progress is recorded.
library;

import 'package:game_core/engine/engine.dart';

import 'family_tug_rules.dart';
import 'tug_of_war_rules.dart';

/// What a press did.
enum HeadPress {
  /// Nothing: the question is over, or this player is locked out.
  ignored,

  /// A right answer: the rope moved toward the player and the question ended.
  pulled,

  /// A wrong answer: the player is locked out of this question (older levels also lose a step).
  locked,
}

/// Player 1 pulls toward the positive end of the rope, player 2 toward the negative end.
class HeadToHeadRun {
  HeadToHeadRun(this.level, {this.roundsToWin = familyRoundsToWin})
    : rope = TugOfWarRun(level);

  final MiniGameLevel level;
  final int roundsToWin;
  final TugOfWarRun rope;

  final Set<int> _locked = {};
  bool _questionOver = false;
  int? _questionWinner;
  int? _roundWinner;

  TugSettings get settings => rope.settings;

  /// The rope's position: positive toward player 1, negative toward player 2.
  int get position => rope.position;

  int roundsOf(int player) => player == 1 ? rope.roundsWon : rope.roundsLost;

  bool isLocked(int player) => _locked.contains(player);

  /// The current question has ended (someone pulled, both are locked out, or time ran out).
  bool get questionOver => _questionOver;

  /// The player who answered the question right, or null.
  int? get questionWinner => _questionWinner;

  /// The player who took the round that ended with the last press (1, 2) or null.
  int? get roundWinner => _roundWinner;

  /// The player who took the game, or null while it is on.
  int? get winner {
    if (rope.roundsWon >= roundsToWin) return 1;
    if (rope.roundsLost >= roundsToWin) return 2;
    return null;
  }

  bool get isOver => winner != null;

  /// A player's answer, [correct] or not. The first right answer pulls and ends the question; a
  /// wrong answer locks that player out (and, where the rules pull back, costs them a step).
  HeadPress press(int player, {required bool correct}) {
    assert(player == 1 || player == 2);
    if (isOver || _questionOver || _locked.contains(player)) {
      return HeadPress.ignored;
    }
    _roundWinner = null;
    if (correct) {
      _questionWinner = player;
      _questionOver = true;
      _noteRound(rope.step(player == 1 ? 1 : -1));
      return HeadPress.pulled;
    }
    _locked.add(player);
    if (settings.pullsBack) {
      _noteRound(rope.step(player == 1 ? -1 : 1));
    }
    if (_locked.length == 2 || isOver) _questionOver = true;
    return HeadPress.locked;
  }

  /// The time for the question ran out (older levels): it ends with no pull.
  void timeUp() {
    if (!_questionOver) {
      _roundWinner = null;
      _questionOver = true;
    }
  }

  /// Starts the next question: nobody is locked out any more.
  void nextQuestion() {
    _locked.clear();
    _questionOver = false;
    _questionWinner = null;
    _roundWinner = null;
  }

  void _noteRound(TugRoundEnd end) {
    if (end == TugRoundEnd.won) _roundWinner = 1;
    if (end == TugRoundEnd.lost) _roundWinner = 2;
  }

  /// Who wins when the questions run out: most rounds, then the rope position, then a draw (0).
  int decideWhenOut() {
    final w = winner;
    if (w != null) return w;
    final a = rope.roundsWon, b = rope.roundsLost;
    if (a != b) return a > b ? 1 : 2;
    if (position != 0) return position > 0 ? 1 : 2;
    return 0;
  }
}
