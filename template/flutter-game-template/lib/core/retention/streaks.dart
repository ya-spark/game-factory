/// Play-day streaks with optional streak freezes. Pure Dart.
class StreakState {
  const StreakState({
    this.current = 0,
    this.best = 0,
    this.lastActiveDay = -1,
    this.freezes = 0,
  });

  final int current;
  final int best;
  final int lastActiveDay;

  /// Owned freezes; each one protects one missed day.
  final int freezes;

  StreakState copyWith({
    int? current,
    int? best,
    int? lastActiveDay,
    int? freezes,
  }) => StreakState(
    current: current ?? this.current,
    best: best ?? this.best,
    lastActiveDay: lastActiveDay ?? this.lastActiveDay,
    freezes: freezes ?? this.freezes,
  );

  Map<String, Object?> toJson() => {
    'current': current,
    'best': best,
    'lastActiveDay': lastActiveDay,
    'freezes': freezes,
  };

  factory StreakState.fromJson(Map<String, Object?>? j) => j == null
      ? const StreakState()
      : StreakState(
          current: (j['current'] as num?)?.toInt() ?? 0,
          best: (j['best'] as num?)?.toInt() ?? 0,
          lastActiveDay: (j['lastActiveDay'] as num?)?.toInt() ?? -1,
          freezes: (j['freezes'] as num?)?.toInt() ?? 0,
        );
}

class StreakUpdate {
  const StreakUpdate(
    this.state, {
    this.freezesUsed = 0,
    this.freezeGranted = false,
    this.broken = false,
    this.changed = false,
  });

  final StreakState state;
  final int freezesUsed;
  final bool freezeGranted;

  /// The streak was reset because days were missed and freezes did not cover them.
  final bool broken;
  final bool changed;
}

abstract final class StreakEngine {
  static const int maxFreezes = 2;
  static const int freezeEveryDays = 7;

  /// Registers that the player was active on [today].
  /// [useFreezes] false means "do not spend freezes" (the optional part).
  static StreakUpdate recordActivity(
    StreakState s,
    int today, {
    bool useFreezes = true,
  }) {
    if (s.lastActiveDay == today || today < s.lastActiveDay) {
      return StreakUpdate(s);
    }
    var freezes = s.freezes;
    var used = 0;
    var broken = false;
    int current;
    if (s.lastActiveDay < 0) {
      current = 1;
    } else {
      final missed = today - s.lastActiveDay - 1;
      if (missed == 0) {
        current = s.current + 1;
      } else if (useFreezes && freezes >= missed) {
        freezes -= missed;
        used = missed;
        current = s.current + 1;
      } else {
        current = 1;
        broken = s.current > 1;
      }
    }
    var granted = false;
    if (current % freezeEveryDays == 0 &&
        current > s.current &&
        freezes < maxFreezes) {
      freezes += 1;
      granted = true;
    }
    final best = current > s.best ? current : s.best;
    return StreakUpdate(
      StreakState(
        current: current,
        best: best,
        lastActiveDay: today,
        freezes: freezes,
      ),
      freezesUsed: used,
      freezeGranted: granted,
      broken: broken,
      changed: true,
    );
  }

  /// Streak value to display today (it reads as 0 once a day was missed beyond freeze cover).
  static int displayStreak(StreakState s, int today) {
    if (s.lastActiveDay < 0) return 0;
    final missed = today - s.lastActiveDay - 1;
    if (missed <= 0) return s.current;
    return s.freezes >= missed ? s.current : 0;
  }
}
