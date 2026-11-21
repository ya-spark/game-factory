/// Door runner, race: two players run the same doors and race to the right answer. Pure Dart, no
/// Flutter, no timers: the screen feeds time with [DoorRaceState.tick]. Door layout is
/// [layoutDoors]; the doors' count and pace are [DoorRunSettings]. Nothing here touches a quiz
/// session: a race records no progress.
library;

import 'dart:math';

import 'package:game_core/engine/engine.dart';

import 'door_runner_rules.dart';
import 'door_runner_state.dart';

/// Right answers needed to win the race.
int raceTarget(MiniGameLevel level) => level.harder ? 7 : 5;

/// What a pick did to the player who made it.
enum RaceOutcome {
  /// The right door: a point, and the question ends.
  right,

  /// A wrong door: this player is locked out of the question.
  wrong,
}

class RacePick {
  const RacePick(this.player, this.index, this.outcome);
  final int player;
  final int index;
  final RaceOutcome outcome;
}

class DoorRaceState {
  DoorRaceState({
    required this.settings,
    required this.level,
    this.doorsWait = false,
    int? target,
  }) : target = target ?? raceTarget(level);

  final DoorRunSettings settings;
  final MiniGameLevel level;

  /// Doors never arrive by themselves: reduced motion, or the younger level.
  final bool doorsWait;

  /// Points needed to win.
  final int target;

  List<Door> doors = const [];
  final Map<int, int> _lane = {1: 0, 2: 0};
  final Map<int, int> _points = {1: 0, 2: 0};
  final Set<int> _locked = {};
  final Set<int> _scored = {};
  final Set<int> _wrongDoors = {};

  /// 0 at the horizon, 1 at the runner line.
  double approach = 0;
  bool paused = false;
  DoorPhase phase = DoorPhase.idle;

  bool get waits => doorsWait || settings.retry;
  bool get _live => phase == DoorPhase.approaching && !paused;
  int get correctIndex => doors.indexWhere((d) => d.correct);

  int laneOf(int player) => _lane[player]!;
  int pointsOf(int player) => _points[player]!;
  bool isLocked(int player) => _locked.contains(player);

  /// The players who scored on the question that just ended (both on a photo finish).
  Set<int> get scorers => Set.unmodifiable(_scored);

  /// Wrong doors already picked this question (they turn grey and cannot be picked again).
  Set<int> get wrongDoors => Set.unmodifiable(_wrongDoors);

  bool get questionOver => phase == DoorPhase.answered;

  /// The player who took the race, or null. Two players level at or past the target play on.
  int? get winner {
    final a = _points[1]!, b = _points[2]!;
    if (max(a, b) < target || a == b) return null;
    return a > b ? 1 : 2;
  }

  bool get isOver => winner != null;

  /// When the questions run out: more points wins, level is a draw (0).
  int decideWhenOut() {
    final a = _points[1]!, b = _points[2]!;
    return a == b ? 0 : (a > b ? 1 : 2);
  }

  /// Starts a question with [newDoors] (one right door). Player 2 starts in the first lane and
  /// player 1 in the last, each on their own side.
  void startQuestion(List<Door> newDoors) {
    doors = newDoors;
    _lane[2] = 0;
    _lane[1] = newDoors.length - 1;
    approach = 0;
    _locked.clear();
    _scored.clear();
    _wrongDoors.clear();
    phase = DoorPhase.approaching;
  }

  void moveLeft(int player) {
    if (_live && !isLocked(player)) _lane[player] = max(0, _lane[player]! - 1);
  }

  void moveRight(int player) {
    if (_live && !isLocked(player)) {
      _lane[player] = min(doors.length - 1, _lane[player]! + 1);
    }
  }

  void pause() => paused = true;
  void resume() => paused = false;

  /// Zap: [player] picks door [index], or the door in their lane.
  RacePick? zap(int player, [int? index]) =>
      _pick(player, index ?? _lane[player]!);

  /// Moves the doors by [dt] seconds. When they reach the line (and do not wait) every player not
  /// locked out picks the door in their lane at once: the right ones score, the wrong ones are
  /// locked out. Two right players on one door both score (a photo finish).
  List<RacePick> tick(double dt) {
    if (!_live) return const [];
    approach = min(1.0, approach + dt / settings.approachSeconds);
    if (approach < 1 || waits) return const [];
    final picks = <RacePick>[];
    final right = <int>[];
    for (final p in [1, 2]) {
      if (isLocked(p)) continue;
      final i = _lane[p]!;
      if (_wrongDoors.contains(i)) {
        _locked.add(p);
        picks.add(RacePick(p, i, RaceOutcome.wrong));
      } else if (doors[i].correct) {
        right.add(p);
        picks.add(RacePick(p, i, RaceOutcome.right));
      } else {
        _locked.add(p);
        _wrongDoors.add(i);
        picks.add(RacePick(p, i, RaceOutcome.wrong));
      }
    }
    for (final p in right) {
      _points[p] = _points[p]! + 1;
      _scored.add(p);
    }
    // The question ends at the line whatever happened: someone scored or no one did.
    phase = DoorPhase.answered;
    return picks;
  }

  RacePick? _pick(int player, int i) {
    if (!_live || isLocked(player) || i < 0 || i >= doors.length) return null;
    if (_wrongDoors.contains(i)) return null;
    if (doors[i].correct) {
      _points[player] = _points[player]! + 1;
      _scored.add(player);
      phase = DoorPhase.answered;
      return RacePick(player, i, RaceOutcome.right);
    }
    _locked.add(player);
    _wrongDoors.add(i);
    if (_locked.length == 2) phase = DoorPhase.answered;
    return RacePick(player, i, RaceOutcome.wrong);
  }
}
