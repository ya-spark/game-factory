/// Zen mode (M5): what a Zen run hides, what it records and what it leaves out. Pure Dart, no
/// Flutter imports. Zen is a saved switch; it applies to the next game started, not to a game
/// already open (the screens read a snapshot taken when the game opens).
library;

/// What a run shows and allows. [ZenPolicy.of] gives the policy for a run.
class ZenPolicy {
  const ZenPolicy._(this.zen);

  /// The policy of a run: Zen when [zen] is true, otherwise the normal game.
  factory ZenPolicy.of(bool zen) => zen ? const ZenPolicy._(true) : normal;

  static const ZenPolicy normal = ZenPolicy._(false);
  final bool zen;

  /// Score, move count, mistake count, stars, best score, coin message, "New personal best".
  bool get showNumbers => !zen;

  /// Tips dialogs, voice cues and vibration are off for a Zen run (the saved settings stay).
  bool get quiet => zen;

  /// Reduce motion is on for a Zen run (the saved choice stays).
  bool get reduceMotion => zen;

  /// Hints (and Mahjong shuffles) never run out and cost nothing.
  bool get unlimitedHints => zen;

  /// Merge always plays Relaxed.
  bool get mergeRelaxed => zen;

  /// The ambience the player chose still plays; Off stays Off.
  String ambienceFor(String saved) => saved;

  /// A run's score may set a best score, a fastest-solve record or count toward the
  /// "score points" challenge. Unlimited hints and endless Merge are not comparable.
  bool get countsScores => !zen;

  /// Stars, bests and trends are recorded only for normal runs.
  bool get countsInAveragesAndBests => !zen;

  /// Plays, solves, active time, the daily puzzle, the play-day streak and the "play N different
  /// games" challenge count in every mode.
  bool get countsPlays => true;

  /// The score a run reports to the score-based challenge: nothing in Zen.
  int challengeScore(int score) => zen ? 0 : score;

  /// The results line of a Zen run.
  static const String resultsLine = 'Finished. Well played.';

  /// The note on the menus of the copied games, which play as usual.
  static const String copiedGameNote = 'Zen mode: this game plays as usual';
}

/// Zen plays and time, by game. Kept apart from `GameStats`, so Zen runs never enter averages,
/// bests, fastest solves or trends; the Stats page adds them to the plays and time numbers.
class ZenStats {
  const ZenStats({this.plays = const {}, this.seconds = const {}});

  final Map<String, int> plays;
  final Map<String, int> seconds;

  bool get isEmpty => plays.isEmpty;
  int get totalPlays => plays.values.fold(0, (a, b) => a + b);
  int get totalSeconds => seconds.values.fold(0, (a, b) => a + b);
  int playsOf(String game) => plays[game] ?? 0;
  int secondsOf(String game) => seconds[game] ?? 0;

  /// Counts one Zen play of [game] with [secs] active seconds (negative counts as zero).
  ZenStats record(String game, int secs) => ZenStats(
    plays: {...plays, game: playsOf(game) + 1},
    seconds: {...seconds, game: secondsOf(game) + (secs < 0 ? 0 : secs)},
  );

  Map<String, Object?> toJson() => {'plays': plays, 'secs': seconds};

  factory ZenStats.fromJson(Map<String, Object?>? j) {
    Map<String, int> ints(Object? o) => {
      if (o is Map)
        for (final e in o.entries)
          if (e.value is num) e.key.toString(): (e.value as num).toInt(),
    };
    return j == null
        ? const ZenStats()
        : ZenStats(plays: ints(j['plays']), seconds: ints(j['secs']));
  }
}
