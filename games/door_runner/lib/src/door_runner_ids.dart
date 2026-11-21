import 'package:flutter/widgets.dart';

/// The stable test IDs of Door runner (hard rule 4). The key strings are part of the game's
/// contract: tests in every container use them.
abstract final class DoorRunnerIds {
  static const screen = Key('door_runner.screen');
  static const frame = Key('door_runner.frame');
  static const intro = Key('door_runner.intro');
  static const start = Key('door_runner.start');
  static const exit = Key('door_runner.exit');
  static const pause = Key('door_runner.pause');
  static const resume = Key('door_runner.resume');
  static const quit = Key('door_runner.quit');
  static const hearts = Key('door_runner.hearts');
  static const score = Key('door_runner.score');
  static const streak = Key('door_runner.streak');
  static const question = Key('door_runner.question');
  static const questionDialog = Key('door_runner.question.dialog');
  static const questionSpeak = Key('door_runner.question.speak');
  static const questionBack = Key('door_runner.question.back');
  static Key answer(int i) => Key('door_runner.answer.$i');
  static Key door(int i) => Key('door_runner.door.$i');
  static Key lane(int i) => Key('door_runner.lane.$i');
  static const runner = Key('door_runner.runner');
  static const runner1 = Key('door_runner.p1.runner');
  static const runner2 = Key('door_runner.p2.runner');
  static const slow = Key('door_runner.slow');
  static const keys = Key('door_runner.keys');
  static const adSlot = Key('door_runner.ad_slot');
  static const field = Key('door_runner.field');
  static const banner = Key('door_runner.banner');
  static const feedback = Key('door_runner.feedback');
  static const next = Key('door_runner.next');
  static const results = Key('door_runner.results');
  static const stars = Key('door_runner.stars');
  static const done = Key('door_runner.done');
  static const modeTwo = Key('door_runner.mode.two');
  static const raceScreen = Key('door_runner.race.screen');
  static const p1Score = Key('door_runner.p1.score');
  static const p2Score = Key('door_runner.p2.score');
  static const raceMessage = Key('door_runner.race.message');
  static const winner = Key('door_runner.winner');
  static const again = Key('door_runner.again');
  static const raceLeave = Key('door_runner.race.leave');
}
