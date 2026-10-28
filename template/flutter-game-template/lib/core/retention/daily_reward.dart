/// 7-day daily login reward cycle. Pure Dart.
class DailyRewardState {
  const DailyRewardState({this.nextDay = 0, this.lastClaimDay = -1});

  /// Index (0..6) of the reward the next claim gives.
  final int nextDay;

  /// Day index (see dayIndexOf) of the last claim, -1 if never.
  final int lastClaimDay;

  Map<String, Object?> toJson() => {
    'nextDay': nextDay,
    'lastClaimDay': lastClaimDay,
  };

  factory DailyRewardState.fromJson(Map<String, Object?>? j) => j == null
      ? const DailyRewardState()
      : DailyRewardState(
          nextDay: (j['nextDay'] as num?)?.toInt() ?? 0,
          lastClaimDay: (j['lastClaimDay'] as num?)?.toInt() ?? -1,
        );
}

class DailyRewardClaim {
  const DailyRewardClaim(this.state, this.coins, this.day);
  final DailyRewardState state;
  final int coins;

  /// Which cycle day (0..6) was claimed.
  final int day;
}

abstract final class DailyRewardEngine {
  static const List<int> coinsByDay = [50, 75, 100, 150, 200, 300, 500];
  static int get cycleLength => coinsByDay.length;

  static bool canClaim(DailyRewardState s, int today) =>
      s.lastClaimDay != today;

  /// The cycle day that would be claimed today: the cycle restarts if a day was missed.
  static int dayToClaim(DailyRewardState s, int today) {
    if (s.lastClaimDay < 0) return 0;
    final gap = today - s.lastClaimDay;
    if (gap <= 1) {
      return s.nextDay % cycleLength; // next day in a row, or already claimed
    }
    return 0; // missed at least one day
  }

  /// Claims today's reward. Returns null if already claimed today.
  static DailyRewardClaim? claim(DailyRewardState s, int today) {
    if (!canClaim(s, today)) return null;
    final day = dayToClaim(s, today);
    return DailyRewardClaim(
      DailyRewardState(nextDay: (day + 1) % cycleLength, lastClaimDay: today),
      coinsByDay[day],
      day,
    );
  }
}
