import 'package:flutter/widgets.dart';

/// MemoryMatch's own test IDs (the shared ones are `GameIds` in game_core).
abstract final class MemoryMatchIds {
  static const matchScreen = Key('match.screen');
  static const matchExit = Key('match.exit');
  static const matchStars = Key('match.stars');
  static const matchProgress = Key('match.progress');
  static const matchSpeak = Key('match.speak');
  static Key matchCard(int i) => Key('match.card.$i');
  static const matchFeedback = Key('match.feedback');
  static const matchNext = Key('match.next');
  static const matchPrompt = Key('match.prompt');
  static const matchSummary = Key('match.summary');
  static const matchTimer = Key('match.timer');
  static const matchPause = Key('match.pause');
  static const matchPaused = Key('match.paused');
  static const matchResume = Key('match.resume');
  static const matchLeave = Key('match.leave');
  static const matchModeOne = Key('match.mode.one');
  static const matchModeTwo = Key('match.mode.two');
  static const matchP1Score = Key('match.p1.score');
  static const matchP2Score = Key('match.p2.score');
  static const matchTurn = Key('match.turn');
  static const matchBoardResult = Key('match.board.result');
  static const matchWinner = Key('match.winner');
  static const matchAgain = Key('match.again');
  static const matchDone = Key('match.done');
}
