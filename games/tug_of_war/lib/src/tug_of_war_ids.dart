import 'package:flutter/widgets.dart';

/// Tug of war's own test IDs (the shared ones are `GameIds` in game_core).
abstract final class TugIds {
  static const modeHeadToHead = Key('tug.mode.headtohead');
  static const h2hScreen = Key('tug.h2h.screen');
  static const start = Key('tug.h2h.start');
  static const question = Key('tug.h2h.question');
  static const rope = Key('tug.h2h.rope');
  static const message = Key('tug.h2h.message');
  static const p1Score = Key('tug.p1.score');
  static const p2Score = Key('tug.p2.score');
  static const p1Locked = Key('tug.p1.locked');
  static const p2Locked = Key('tug.p2.locked');
  static const winner = Key('tug.winner');
  static const again = Key('tug.again');
  static const leave = Key('tug.leave');
  static const timer = Key('tug.h2h.timer');
  static const pause = Key('tug.h2h.pause');
  static const paused = Key('tug.h2h.paused');
  static const resume = Key('tug.h2h.resume');
  static const exit = Key('tug.h2h.exit');
  static Key option(int i) => Key('tug.h2h.option.$i');
}
