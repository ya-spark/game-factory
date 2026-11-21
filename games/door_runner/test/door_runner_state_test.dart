import 'package:game_core/engine/engine.dart';
import 'package:game_door_runner/src/rules/door_runner_rules.dart';
import 'package:game_door_runner/src/rules/door_runner_state.dart';
import 'package:flutter_test/flutter_test.dart';

List<Door> _doors(int n, {int right = 1}) => [
  for (var i = 0; i < n; i++) Door('D$i', i == right),
];

DoorRunnerState _older({bool harder = false, bool wait = false}) =>
    DoorRunnerState(
      settings: DoorRunSettings.forLevel(MiniGameLevel.older(harder: harder)),
      level: MiniGameLevel.older(harder: harder),
      doorsWait: wait,
    )..startQuestion(_doors(3));

DoorRunnerState _younger() => DoorRunnerState(
  settings: DoorRunSettings.forLevel(const MiniGameLevel.younger()),
  level: const MiniGameLevel.younger(),
)..startQuestion(_doors(2));

void main() {
  test('settings by level', () {
    final y = DoorRunSettings.forLevel(const MiniGameLevel.younger());
    expect((y.doors, y.hearts, y.retry), (2, null, true));
    final o = DoorRunSettings.forLevel(const MiniGameLevel.older());
    expect((o.doors, o.hearts, o.approachSeconds), (3, 3, 12.0));
    final h = DoorRunSettings.forLevel(const MiniGameLevel.older(harder: true));
    expect((h.doors, h.approachSeconds), (4, 8.0));
  });

  test('1. left and right move one lane and stop at the edges', () {
    final s = _older();
    expect(s.lane, 1);
    s.moveLeft();
    s.moveLeft();
    s.moveLeft();
    expect(s.lane, 0);
    s.moveRight();
    s.moveRight();
    s.moveRight();
    expect(s.lane, 2);
  });

  test('2. zap picks the door in the runner lane at once', () {
    final s = _older()..moveLeft();
    final p = s.zap()!;
    expect((p.index, p.outcome), (0, DoorOutcome.wrong));
    expect(s.phase, DoorPhase.answered);
    expect(s.approach, 0, reason: 'did not wait for the door to arrive');
  });

  test('2. a zap on a door number picks that door from any lane', () {
    final s = _older()..moveLeft();
    final p = s.zap(1)!;
    expect(p.outcome, DoorOutcome.right);
    expect(p.gained, 10);
    expect(s.run.score, 10);
    expect(s.run.streak, 1);
  });

  test('2. older wrong zap: heart lost, streak reset, the answer is known', () {
    final s = _older();
    s.zap(1);
    s.startQuestion(_doors(3));
    expect(s.run.streak, 1);
    final p = s.zap(2)!;
    expect(p.outcome, DoorOutcome.wrong);
    expect(p.correctIndex, 1);
    expect(s.hearts, 2);
    expect(s.run.streak, 0);
    expect(s.run.score, 10, reason: 'score is never taken away');
    expect(s.missedIndex, 2);
  });

  test('3. Down held slows to 40 percent and releasing restores it', () {
    final s = _older();
    expect(s.speed, 1);
    s.setSlow(true);
    expect(s.speed, closeTo(0.4, 1e-9));
    s.tick(1.2);
    expect(s.approach, closeTo(1.2 * 0.4 / 12, 1e-9));
    s.setSlow(false);
    expect(s.speed, 1);
  });

  test('speed rises with the streak up to the cap', () {
    final s = _older();
    for (var i = 0; i < 10; i++) {
      s.startQuestion(_doors(3));
      s.zap(1);
    }
    expect(s.speed, closeTo(1.3, 1e-9));
  });

  test('older: a door arriving at the runner is picked', () {
    final s = _older()..moveRight();
    DoorPick? p;
    for (var i = 0; i < 200 && p == null; i++) {
      p = s.tick(0.1);
    }
    expect(p, isNotNull);
    expect(p!.index, 2);
    expect(p.outcome, DoorOutcome.wrong);
    expect(s.approach, 1);
  });

  test('doors wait for the child when reduced motion asks for it', () {
    final s = _older(wait: true);
    for (var i = 0; i < 400; i++) {
      expect(s.tick(0.1), isNull);
    }
    expect(s.approach, 1);
    expect(s.phase, DoorPhase.approaching);
    expect(s.zap(1)!.outcome, DoorOutcome.right);
  });

  test('4. nothing moves or counts while paused', () {
    final s = _older()..pause();
    s.moveLeft();
    expect(s.lane, 1);
    expect(s.tick(5), isNull);
    expect(s.approach, 0);
    expect(s.zap(1), isNull);
    s.resume();
    expect(s.zap(1)!.outcome, DoorOutcome.right);
  });

  test(
    '6. younger: no hearts, doors wait, a wrong door greys out and can retry',
    () {
      final s = _younger();
      expect(s.hearts, isNull);
      for (var i = 0; i < 400; i++) {
        expect(s.tick(0.1), isNull);
      }
      expect(s.approach, 1);
      final w = s.zap(0)!;
      expect(w.outcome, DoorOutcome.retry);
      expect(s.disabled, {0});
      expect(s.phase, DoorPhase.approaching);
      expect(s.zap(0), isNull, reason: 'a greyed-out door cannot be picked');
      final r = s.zap(1)!;
      expect(r.outcome, DoorOutcome.right);
      expect(
        r.clean,
        isFalse,
        reason: 'a wrong try came first: no first-pass credit',
      );
      expect(s.over, isFalse);
    },
  );

  test('6. older: the round is over at 0 hearts', () {
    final s = _older();
    for (var i = 0; i < 3; i++) {
      s.startQuestion(_doors(3));
      expect(s.over, isFalse);
      s.zap(0);
    }
    expect(s.hearts, 0);
    expect(s.over, isTrue);
  });

  test('a clean right pick is flagged', () {
    final s = _older();
    expect(s.zap(1)!.clean, isTrue);
  });
}
