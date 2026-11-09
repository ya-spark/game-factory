/// Stars (progress, never spent) and the capped weekly coin trickle for Craft apps.
/// Pure Dart. Days are local day numbers (see `dayIndexOf`).
library;

/// `rewards:` in `app.config.yaml`.
class RewardsConfig {
  const RewardsConfig({
    this.starsEnabled = true,
    this.perFirstPass = 1,
    this.topicBonus = 5,
    this.streakBonus = 2,
    this.weeklyCapPerChild = 60,
    this.topicCoins = 10,
    this.streakMilestones = const {3: 10, 7: 15, 14: 20, 30: 30},
    this.dailyGoalItems = 5,
    this.dailyGoalCoins = 5,
    this.weeklyGoalItems = 25,
    this.weeklyGoalCoins = 15,
  });

  /// Mind hubs set this false: no stars. Coins there come from play, not from this engine.
  final bool starsEnabled;
  final int perFirstPass;
  final int topicBonus;

  /// Stars once per day, on the first pass of a day that continues a streak of 2 days or more.
  final int streakBonus;
  final int weeklyCapPerChild;
  final int topicCoins;

  /// Streak length to coins; each milestone pays once per child.
  final Map<int, int> streakMilestones;
  final int dailyGoalItems;
  final int dailyGoalCoins;
  final int weeklyGoalItems;
  final int weeklyGoalCoins;
}

/// Monday-based week number of a day number (1970-01-01 was a Thursday).
int weekOfDay(int day) => (day + 3) ~/ 7;

/// What one child has earned. Lives inside `ChildProgress`.
class RewardState {
  const RewardState({
    this.stars = 0,
    this.paid = const {},
    this.dayMarks = const {},
    this.weekCoins = const {},
    this.todayDay = -1,
    this.todayPasses = 0,
    this.weekIndex = -1,
    this.weekPasses = 0,
  });

  final int stars;

  /// One-time events already paid (`topic:..`, `streak:7`).
  final Set<String> paid;

  /// Per-day or per-week events already paid (`goal:<day>`, `star:<day>`, `wgoal:<week>`).
  final Set<String> dayMarks;

  /// Coins paid out in each week (week number to coins).
  final Map<int, int> weekCoins;
  final int todayDay;
  final int todayPasses;
  final int weekIndex;
  final int weekPasses;

  int coinsThisWeek(int day) => weekCoins[weekOfDay(day)] ?? 0;

  RewardState copyWith({
    int? stars,
    Set<String>? paid,
    Set<String>? dayMarks,
    Map<int, int>? weekCoins,
    int? todayDay,
    int? todayPasses,
    int? weekIndex,
    int? weekPasses,
  }) => RewardState(
    stars: stars ?? this.stars,
    paid: paid ?? this.paid,
    dayMarks: dayMarks ?? this.dayMarks,
    weekCoins: weekCoins ?? this.weekCoins,
    todayDay: todayDay ?? this.todayDay,
    todayPasses: todayPasses ?? this.todayPasses,
    weekIndex: weekIndex ?? this.weekIndex,
    weekPasses: weekPasses ?? this.weekPasses,
  );

  Map<String, Object?> toJson() => {
    's': stars,
    'paid': paid.toList()..sort(),
    'marks': dayMarks.toList()..sort(),
    'wc': {for (final e in weekCoins.entries) '${e.key}': e.value},
    'td': todayDay,
    'tp': todayPasses,
    'wi': weekIndex,
    'wp': weekPasses,
  };

  factory RewardState.fromJson(Map<String, Object?>? j) {
    if (j == null) return const RewardState();
    return RewardState(
      stars: (j['s'] as num?)?.toInt() ?? 0,
      paid: {...?(j['paid'] as List?)?.cast<String>()},
      dayMarks: {...?(j['marks'] as List?)?.cast<String>()},
      weekCoins: {
        if (j['wc'] is Map)
          for (final e in (j['wc'] as Map).entries)
            if (int.tryParse('${e.key}') != null)
              int.parse('${e.key}'): (e.value as num).toInt(),
      },
      todayDay: (j['td'] as num?)?.toInt() ?? -1,
      todayPasses: (j['tp'] as num?)?.toInt() ?? 0,
      weekIndex: (j['wi'] as num?)?.toInt() ?? -1,
      weekPasses: (j['wp'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Stars and coins earned by one event.
class RewardGrant {
  const RewardGrant(this.state, {this.stars = 0, this.coins = 0});
  final RewardState state;
  final int stars;
  final int coins;
}

abstract final class RewardsEngine {
  /// Pays [wanted] coins, cut down to what is left of this week's cap. The cap is per child.
  /// An event cut to nothing by the cap is not retried later: its mark stays.
  static ({RewardState state, int coins}) _payCoins(
    RewardState s,
    int wanted,
    int day,
    RewardsConfig cfg,
  ) {
    final week = weekOfDay(day);
    final used = s.weekCoins[week] ?? 0;
    final left = cfg.weeklyCapPerChild - used;
    final pay = wanted.clamp(0, left < 0 ? 0 : left);
    if (pay == 0) return (state: s, coins: 0);
    return (
      state: s.copyWith(weekCoins: {...s.weekCoins, week: used + pay}),
      coins: pay,
    );
  }

  /// A first pass of an item on [day]. [topicDone] is true when it completed its topic.
  /// [streakDays] is the child's current play-day streak (0 when unknown).
  static RewardGrant onFirstPass(
    RewardState before,
    RewardsConfig cfg, {
    required int day,
    required String topicKey,
    required bool topicDone,
    required int streakDays,
  }) {
    var s = before;
    var stars = 0;
    var coins = 0;
    final week = weekOfDay(day);

    // Counters for the daily and weekly goals.
    s = s.copyWith(
      todayDay: day,
      todayPasses: (s.todayDay == day ? s.todayPasses : 0) + 1,
      weekIndex: week,
      weekPasses: (s.weekIndex == week ? s.weekPasses : 0) + 1,
    );

    final topicNew = topicDone && !s.paid.contains('topic:$topicKey');
    if (cfg.starsEnabled) {
      stars += cfg.perFirstPass;
      if (topicNew) stars += cfg.topicBonus;
      if (streakDays >= 2 && !s.dayMarks.contains('star:$day')) {
        stars += cfg.streakBonus;
        s = s.copyWith(dayMarks: {...s.dayMarks, 'star:$day'});
      }
    }

    void coin(int wanted) {
      final r = _payCoins(s, wanted, day, cfg);
      s = r.state;
      coins += r.coins;
    }

    if (topicNew) {
      s = s.copyWith(paid: {...s.paid, 'topic:$topicKey'});
      coin(cfg.topicCoins);
    }
    final ms = cfg.streakMilestones[streakDays];
    if (ms != null && !s.paid.contains('streak:$streakDays')) {
      s = s.copyWith(paid: {...s.paid, 'streak:$streakDays'});
      coin(ms);
    }
    if (s.todayPasses >= cfg.dailyGoalItems &&
        !s.dayMarks.contains('goal:$day')) {
      s = s.copyWith(dayMarks: {...s.dayMarks, 'goal:$day'});
      coin(cfg.dailyGoalCoins);
    }
    if (s.weekPasses >= cfg.weeklyGoalItems &&
        !s.dayMarks.contains('wgoal:$week')) {
      s = s.copyWith(dayMarks: {...s.dayMarks, 'wgoal:$week'});
      coin(cfg.weeklyGoalCoins);
    }
    return RewardGrant(
      s.copyWith(stars: s.stars + stars),
      stars: stars,
      coins: coins,
    );
  }

  /// Clamps coins from another earner (the template's daily reward and challenges, in Craft
  /// apps) to the weekly cap and records them. Returns the coins to add to the wallet.
  static ({RewardState state, int coins}) grantCapped(
    RewardState s,
    int wanted,
    int day,
    RewardsConfig cfg,
  ) => _payCoins(s, wanted, day, cfg);
}
