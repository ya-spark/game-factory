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

/// What one day of the cycle pays: coins and/or power-up stock (keys are power-up ids).
class DailyReward {
  const DailyReward({this.coins = 0, this.powerUps = const {}});
  final int coins;
  final Map<String, int> powerUps;

  /// Short label for the UI, e.g. `150 + Sweep` or `Slow`.
  String get label {
    final parts = [
      if (coins > 0) '$coins',
      for (final e in powerUps.entries)
        '${e.value > 1 ? '${e.value}x ' : ''}'
            '${e.key[0].toUpperCase()}${e.key.substring(1)}',
    ];
    return parts.join(' + ');
  }
}

class DailyRewardClaim {
  const DailyRewardClaim(
    this.state,
    this.coins,
    this.day, {
    this.powerUps = const {},
  });
  final DailyRewardState state;
  final int coins;

  /// Power-up stock to add (power-up id to amount), empty on coin-only days.
  final Map<String, int> powerUps;

  /// Which cycle day (0..6) was claimed.
  final int day;
}

abstract final class DailyRewardEngine {
  /// Blockfall cycle: coins on days 1, 2, 3, 5; day 4 a Slow, day 6 a Bomb, day 7 coins
  /// plus a Sweep. Power-up ids match `PowerUpType.name` (checked in a test).
  static const List<DailyReward> rewards = [
    DailyReward(coins: 30),
    DailyReward(coins: 40),
    DailyReward(coins: 50),
    DailyReward(powerUps: {'slow': 1}),
    DailyReward(coins: 70),
    DailyReward(powerUps: {'bomb': 1}),
    DailyReward(coins: 150, powerUps: {'sweep': 1}),
  ];
  static List<int> get coinsByDay => [for (final r in rewards) r.coins];
  static int get cycleLength => rewards.length;

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
      rewards[day].coins,
      day,
      powerUps: rewards[day].powerUps,
    );
  }
}
