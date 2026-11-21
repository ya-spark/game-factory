/// Door runner rules for one round: lanes, doors coming down, steering, zap, slow, pause, hearts.
/// Pure Dart (no Flutter, no timers): the screen feeds it time with [DoorRunnerState.tick] and
/// maps keys and touches to the commands. Door choice and scoring are in `door_runner_rules.dart`
/// ([layoutDoors], [DoorRunnerRun]); the engine (`game_core`) supplies the level and the session.
library;

import 'dart:math';

import 'package:game_core/engine/engine.dart';

import 'door_runner_rules.dart';

/// Numbers per level.
class DoorRunSettings {
  const DoorRunSettings({
    required this.doors,
    required this.hearts,
    required this.approachSeconds,
    required this.retry,
    required this.rampPerStreak,
    required this.rampCap,
  });

  /// Doors, and lanes, per question.
  final int doors;

  /// Hearts at the start; null at the younger level (no failing).
  final int? hearts;

  /// Seconds the doors take to come from the horizon to the runner at normal speed.
  final double approachSeconds;

  /// A wrong door is greyed out and the child tries another (younger level).
  final bool retry;

  /// The doors speed up by this much per right answer in a row, up to [rampCap].
  final double rampPerStreak;
  final double rampCap;

  /// Speed while Down is held.
  static const double slowFactor = 0.4;

  factory DoorRunSettings.forLevel(MiniGameLevel l) {
    if (!l.older) {
      return const DoorRunSettings(
        doors: 2,
        hearts: null,
        approachSeconds: 6,
        retry: true,
        rampPerStreak: 0,
        rampCap: 1,
      );
    }
    return DoorRunSettings(
      doors: l.harder ? 4 : 3,
      hearts: 3,
      approachSeconds: l.harder ? 8 : 12,
      retry: false,
      rampPerStreak: 0.05,
      rampCap: 1.3,
    );
  }
}

enum DoorPhase { idle, approaching, answered }

enum DoorOutcome {
  /// The right door.
  right,

  /// A wrong door that ends the question (older level).
  wrong,

  /// A wrong door that only greys that door out (younger level).
  retry,
}

/// What one pick did.
class DoorPick {
  const DoorPick({
    required this.outcome,
    required this.index,
    required this.correctIndex,
    required this.gained,
    required this.clean,
  });
  final DoorOutcome outcome;
  final int index;
  final int correctIndex;

  /// Score earned by this pick.
  final int gained;

  /// Right with no wrong try before it (the evidence counts only these as right).
  final bool clean;
}

class DoorRunnerState {
  DoorRunnerState({
    required this.settings,
    required this.level,
    this.doorsWait = false,
  }) : hearts = settings.hearts,
       run = DoorRunnerRun(level);

  final DoorRunSettings settings;
  final MiniGameLevel level;

  /// Doors never arrive by themselves: reduced motion, or the younger level.
  final bool doorsWait;

  /// Score and streak of the round.
  final DoorRunnerRun run;

  List<Door> doors = const [];
  int lane = 0;

  /// 0 at the horizon, 1 at the runner.
  double approach = 0;
  bool slow = false;
  bool paused = false;
  DoorPhase phase = DoorPhase.idle;
  int? hearts;
  int wrongTries = 0;

  /// Wrong doors already tried (younger level).
  final Set<int> disabled = {};

  /// The wrong door picked when the question ended (older level), for the view.
  int? missedIndex;

  bool get waits => doorsWait || settings.retry;
  bool get over => hearts != null && hearts! <= 0;
  int get correctIndex => doors.indexWhere((d) => d.correct);
  bool get _live => phase == DoorPhase.approaching && !paused;

  /// 1 normally; faster with a streak (older), slower while Down is held.
  double get speed {
    final ramp = min(1 + settings.rampPerStreak * run.streak, settings.rampCap);
    return ramp * (slow ? DoorRunSettings.slowFactor : 1);
  }

  /// Starts a question with [newDoors] (one right door). The runner starts in the middle lane.
  void startQuestion(List<Door> newDoors) {
    doors = newDoors;
    lane = (newDoors.length - 1) ~/ 2;
    approach = 0;
    slow = false;
    wrongTries = 0;
    missedIndex = null;
    disabled.clear();
    phase = DoorPhase.approaching;
  }

  void moveLeft() {
    if (_live) lane = max(0, lane - 1);
  }

  void moveRight() {
    if (_live) lane = min(doors.length - 1, lane + 1);
  }

  void setSlow(bool held) => slow = held;

  void pause() => paused = true;
  void resume() => paused = false;

  /// Zap: picks door [index], or the door in the runner's lane.
  DoorPick? zap([int? index]) => _pick(index ?? lane);

  /// Moves the doors by [dt] seconds. At the older level a door arriving at the runner is picked.
  DoorPick? tick(double dt) {
    if (!_live) return null;
    approach = min(1.0, approach + dt * speed / settings.approachSeconds);
    if (approach >= 1 && !waits) return _pick(lane);
    return null;
  }

  DoorPick? _pick(int i) {
    if (!_live || i < 0 || i >= doors.length || disabled.contains(i)) {
      return null;
    }
    final right = correctIndex;
    if (doors[i].correct) {
      final before = run.score;
      final clean = wrongTries == 0;
      run.right();
      phase = DoorPhase.answered;
      return DoorPick(
        outcome: DoorOutcome.right,
        index: i,
        correctIndex: right,
        gained: run.score - before,
        clean: clean,
      );
    }
    if (settings.retry) {
      disabled.add(i);
      wrongTries++;
      return DoorPick(
        outcome: DoorOutcome.retry,
        index: i,
        correctIndex: right,
        gained: 0,
        clean: false,
      );
    }
    run.miss();
    if (hearts != null) hearts = hearts! - 1;
    missedIndex = i;
    phase = DoorPhase.answered;
    return DoorPick(
      outcome: DoorOutcome.wrong,
      index: i,
      correctIndex: right,
      gained: 0,
      clean: false,
    );
  }
}
