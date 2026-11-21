import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_door_runner/src/rules/door_runner_rules.dart';
import 'package:game_door_runner/src/rules/door_runner_race.dart';
import 'package:game_door_runner/src/rules/door_runner_state.dart';

const _doors3 = [Door('a', false), Door('b', true), Door('c', false)];
const _doors2 = [Door('a', false), Door('b', true)];

DoorRaceState race({
  MiniGameLevel level = const MiniGameLevel.older(),
  bool wait = false,
}) {
  final s = DoorRaceState(
    settings: DoorRunSettings.forLevel(level),
    level: level,
    doorsWait: wait,
  );
  s.startQuestion(level.older ? _doors3 : _doors2);
  return s;
}

void main() {
  test('player 2 starts in the first lane and player 1 in the last', () {
    final r = race();
    expect(r.laneOf(2), 0);
    expect(r.laneOf(1), 2);
    expect(r.phase, DoorPhase.approaching);
  });

  test('each player steers only their own runner and stays in the field', () {
    final r = race();
    r.moveLeft(1);
    expect(r.laneOf(1), 1);
    expect(r.laneOf(2), 0);
    r.moveLeft(2);
    expect(r.laneOf(2), 0);
    r.moveRight(2);
    r.moveRight(2);
    r.moveRight(2);
    expect(r.laneOf(2), 2);
    expect(r.laneOf(1), 1);
  });

  test('two runners can stand in one lane', () {
    final r = race();
    r.moveLeft(1);
    r.moveRight(2);
    r.moveRight(2);
    r.moveLeft(2);
    expect(r.laneOf(1), r.laneOf(2));
  });

  test('the first right pick scores a point and ends the question', () {
    final r = race();
    final p = r.zap(1, 1)!;
    expect(p.outcome, RaceOutcome.right);
    expect(r.pointsOf(1), 1);
    expect(r.pointsOf(2), 0);
    expect(r.questionOver, isTrue);
    expect(r.scorers, {1});
    expect(r.zap(2, 1), isNull); // too late
  });

  test('a zap with no index picks the door in the runner\'s lane', () {
    final r = race();
    r.moveLeft(1); // lane 1, the right door
    expect(r.zap(1)!.outcome, RaceOutcome.right);
  });

  test('a wrong pick locks only that player, the other can still answer', () {
    final r = race();
    expect(r.zap(1, 0)!.outcome, RaceOutcome.wrong);
    expect(r.isLocked(1), isTrue);
    expect(r.isLocked(2), isFalse);
    expect(r.questionOver, isFalse);
    expect(r.zap(1, 1), isNull); // locked out
    expect(r.zap(2, 1)!.outcome, RaceOutcome.right);
    expect(r.scorers, {2});
  });

  test(
    'a locked player\'s runner cannot move; a greyed door cannot be picked',
    () {
      final r = race();
      r.zap(1, 0);
      final lane = r.laneOf(1);
      r.moveLeft(1);
      expect(r.laneOf(1), lane);
      expect(r.wrongDoors, {0});
      expect(r.zap(2, 0), isNull);
      expect(r.isLocked(2), isFalse);
    },
  );

  test('both locked out ends the question with no point', () {
    final r = race();
    r.zap(1, 0);
    r.zap(2, 2);
    expect(r.questionOver, isTrue);
    expect(r.scorers, isEmpty);
    expect(r.pointsOf(1) + r.pointsOf(2), 0);
  });

  test('older: the doors arriving pick for both runners at once', () {
    final r = race();
    r.moveLeft(1); // player 1 on the right door (lane 1)
    final picks = r.tick(100);
    expect(r.approach, 1);
    expect(r.questionOver, isTrue);
    expect(picks.map((p) => (p.player, p.outcome)), [
      (1, RaceOutcome.right),
      (2, RaceOutcome.wrong),
    ]);
    expect(r.pointsOf(1), 1);
    expect(r.isLocked(2), isTrue);
  });

  test('a photo finish: both on the right door both score', () {
    final r = race();
    r.moveLeft(1); // lane 1
    r.moveRight(2); // lane 1
    r.tick(100);
    expect(r.scorers, {1, 2});
    expect(r.pointsOf(1), 1);
    expect(r.pointsOf(2), 1);
  });

  test('the doors reaching the line with both wrong ends the question', () {
    final r = race();
    r.tick(100); // player 1 in lane 2 (wrong), player 2 in lane 0 (wrong)
    expect(r.questionOver, isTrue);
    expect(r.scorers, isEmpty);
  });

  test(
    'younger: the doors wait at the line, nothing is picked by arriving',
    () {
      final r = race(level: const MiniGameLevel.younger());
      final picks = r.tick(100);
      expect(r.approach, 1);
      expect(picks, isEmpty);
      expect(r.questionOver, isFalse);
      expect(r.zap(2, 1)!.outcome, RaceOutcome.right);
    },
  );

  test('a paused race moves nothing and picks nothing', () {
    final r = race();
    r.pause();
    r.moveLeft(1);
    expect(r.laneOf(1), 2);
    expect(r.zap(1, 1), isNull);
    expect(r.tick(100), isEmpty);
    expect(r.approach, 0);
    r.resume();
    expect(r.zap(1, 1), isNotNull);
  });

  test('five points win the race (seven at the harder level)', () {
    expect(raceTarget(const MiniGameLevel.older()), 5);
    expect(raceTarget(const MiniGameLevel.older(harder: true)), 7);
    final r = race();
    for (var i = 0; i < 5; i++) {
      r.startQuestion(_doors3);
      r.zap(2, 1);
    }
    expect(r.winner, 2);
    expect(r.isOver, isTrue);
  });

  test('level at or past the target plays on until one leads', () {
    final r = race();
    for (var i = 0; i < 5; i++) {
      r.startQuestion(_doors3);
      r.moveLeft(1);
      r.moveRight(2);
      r.moveRight(2);
      r.moveLeft(2);
      r.tick(100); // photo finish
    }
    expect(r.pointsOf(1), 5);
    expect(r.pointsOf(2), 5);
    expect(r.winner, isNull);
    r.startQuestion(_doors3);
    r.zap(1, 1);
    expect(r.winner, 1);
  });

  test('when the questions run out: more points, or a draw', () {
    final r = race();
    expect(r.decideWhenOut(), 0);
    r.zap(2, 1);
    expect(r.decideWhenOut(), 2);
  });

  test('a new question lifts the lock-outs and the grey doors', () {
    final r = race();
    r.zap(1, 0);
    r.startQuestion(_doors3);
    expect(r.isLocked(1), isFalse);
    expect(r.wrongDoors, isEmpty);
    expect(r.scorers, isEmpty);
  });
}
