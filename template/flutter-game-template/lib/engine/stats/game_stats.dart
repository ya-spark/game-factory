/// Per-game personal stats for the hubs (M2): aggregation, the 20-run window, fastest solve per
/// variant, new-best detection, the foreground-only timer and the reset scope. Pure Dart: the
/// day number and the clock are passed in. Device only; nothing here is shared or exported.
library;

import 'dart:math';

/// Runs kept per game for the average and the trend.
const int statsRunWindow = 20;

/// Days of per-day time kept for "time played this week".
const int statsDayWindow = 28;

/// What a game screen adds to its score report: only what the game knows. The hub fills in the
/// seconds (it times the screen) unless the game passes its own (a resumed puzzle).
class RunExtras {
  const RunExtras({
    this.won,
    this.mistakes,
    this.hints,
    this.variant,
    this.seconds,
  });

  /// Null where the game has no wins.
  final bool? won;
  final int? mistakes;
  final int? hints;

  /// Sudoku "Hard", Solitaire "Draw three", a Mahjong layout name, Merge "Classic".
  final String? variant;

  /// Set only when the game keeps its own active seconds (a resumed puzzle).
  final int? seconds;
}

/// One finished run, as reported by the hub next to the existing score call.
class RunReport {
  const RunReport({
    required this.gameId,
    required this.score,
    this.won,
    this.seconds = 0,
    this.mistakes,
    this.hints,
    this.variant,
  });
  final String gameId;
  final int score;
  final bool? won;
  final int seconds;
  final int? mistakes;
  final int? hints;
  final String? variant;
}

/// One entry of the last-20 window.
class RunRecord {
  const RunRecord({
    required this.day,
    required this.score,
    required this.seconds,
    this.won,
  });
  final int day;
  final int score;
  final int seconds;
  final bool? won;

  Map<String, Object?> toJson() => {
    'd': day,
    's': score,
    't': seconds,
    if (won != null) 'w': won,
  };
  factory RunRecord.fromJson(Map<String, Object?> j) => RunRecord(
    day: (j['d'] as num?)?.toInt() ?? 0,
    score: (j['s'] as num?)?.toInt() ?? 0,
    seconds: (j['t'] as num?)?.toInt() ?? 0,
    won: j['w'] as bool?,
  );
}

/// Numbers for one game.
class GameStatsEntry {
  const GameStatsEntry({
    this.plays = 0,
    this.winPlays = 0,
    this.wins = 0,
    this.bestScore = 0,
    this.totalSeconds = 0,
    this.lastDay = -1,
    this.runs = const [],
    this.fastest = const {},
  });

  final int plays;

  /// Plays of a game that has wins (the win-rate denominator).
  final int winPlays;
  final int wins;
  final int bestScore;
  final int totalSeconds;
  final int lastDay;

  /// The last [statsRunWindow] runs, oldest first.
  final List<RunRecord> runs;

  /// Fastest won solve in seconds, by variant.
  final Map<String, int> fastest;

  bool get hasWins => winPlays > 0;

  /// Percent 0..100 (rounded); null where the game has no wins.
  int? get winRatePercent =>
      winPlays == 0 ? null : (wins * 100 / winPlays).round();

  /// Average score of the last [statsRunWindow] runs (rounded); null with no runs.
  int? get averageScore => runs.isEmpty
      ? null
      : (runs.fold<int>(0, (s, r) => s + r.score) / runs.length).round();

  Map<String, Object?> toJson() => {
    'plays': plays,
    'winPlays': winPlays,
    'wins': wins,
    'best': bestScore,
    'secs': totalSeconds,
    'last': lastDay,
    'runs': [for (final r in runs) r.toJson()],
    'fastest': fastest,
  };

  factory GameStatsEntry.fromJson(Map<String, Object?> j) {
    final runs = [
      for (final r in (j['runs'] as List?) ?? const [])
        if (r is Map) RunRecord.fromJson(r.cast<String, Object?>()),
    ];
    final f = j['fastest'];
    return GameStatsEntry(
      plays: (j['plays'] as num?)?.toInt() ?? 0,
      winPlays: (j['winPlays'] as num?)?.toInt() ?? 0,
      wins: (j['wins'] as num?)?.toInt() ?? 0,
      bestScore: (j['best'] as num?)?.toInt() ?? 0,
      totalSeconds: (j['secs'] as num?)?.toInt() ?? 0,
      lastDay: (j['last'] as num?)?.toInt() ?? -1,
      runs: runs.length > statsRunWindow
          ? runs.sublist(runs.length - statsRunWindow)
          : runs,
      fastest: {
        if (f is Map)
          for (final e in f.entries)
            if (e.value is num) e.key.toString(): (e.value as num).toInt(),
      },
    );
  }
}

/// What one recorded run changed, for the "New personal best" message.
class RunOutcome {
  const RunOutcome({
    required this.book,
    this.newBestScore = false,
    this.newFastestVariant,
  });
  final GameStats book;
  final bool newBestScore;

  /// The variant whose fastest solve improved, or null.
  final String? newFastestVariant;
  bool get isNewBest => newBestScore || newFastestVariant != null;
}

/// All games' stats plus the overview numbers.
class GameStats {
  const GameStats({
    this.games = const {},
    this.daySeconds = const {},
    this.daysPlayed = 0,
    this.lastDay = -1,
  });

  final Map<String, GameStatsEntry> games;

  /// Active seconds by day number, the last [statsDayWindow] days.
  final Map<int, int> daySeconds;
  final int daysPlayed;
  final int lastDay;

  bool get isEmpty => games.isEmpty;

  int get totalSeconds =>
      games.values.fold<int>(0, (s, e) => s + e.totalSeconds);

  /// Seconds in the 7 days ending [today] (today included).
  int secondsThisWeek(int today) => daySeconds.entries
      .where((e) => e.key > today - 7 && e.key <= today)
      .fold<int>(0, (s, e) => s + e.value);

  GameStatsEntry entry(String gameId) =>
      games[gameId] ?? const GameStatsEntry();

  /// Records [r] on [day]. [priorBest] is the best score already known elsewhere (the tile's);
  /// a "new best" needs an earlier best to beat, so the first run only sets the baseline.
  /// Negative seconds count as zero.
  RunOutcome record(RunReport r, int day, {int priorBest = 0}) {
    final secs = max(0, r.seconds);
    final e = entry(r.gameId);
    final baseline = max(e.bestScore, priorBest);
    final newBestScore = baseline > 0 && r.score > baseline;
    String? fastVariant;
    final fast = {...e.fastest};
    final v = r.variant;
    if (r.won == true && v != null && secs > 0) {
      final old = fast[v];
      if (old == null || secs < old) {
        if (old != null) fastVariant = v;
        fast[v] = secs;
      }
    }
    var runs = [
      ...e.runs,
      RunRecord(day: day, score: r.score, seconds: secs, won: r.won),
    ];
    if (runs.length > statsRunWindow) {
      runs = runs.sublist(runs.length - statsRunWindow);
    }
    final next = GameStatsEntry(
      plays: e.plays + 1,
      winPlays: e.winPlays + (r.won == null ? 0 : 1),
      wins: e.wins + (r.won == true ? 1 : 0),
      bestScore: max(baseline, r.score),
      totalSeconds: e.totalSeconds + secs,
      lastDay: day,
      runs: runs,
      fastest: fast,
    );
    final days = {...daySeconds};
    days[day] = (days[day] ?? 0) + secs;
    days.removeWhere((d, _) => d <= day - statsDayWindow);
    final book = GameStats(
      games: {...games, r.gameId: next},
      daySeconds: days,
      daysPlayed: daysPlayed + (lastDay == day ? 0 : 1),
      lastDay: max(lastDay, day),
    );
    return RunOutcome(
      book: book,
      newBestScore: newBestScore,
      newFastestVariant: fastVariant,
    );
  }

  /// Clears history, averages, wins, times and days; keeps each game's best score.
  GameStats reset() => GameStats(
    games: {
      for (final e in games.entries)
        if (e.value.bestScore > 0)
          e.key: GameStatsEntry(bestScore: e.value.bestScore),
    },
  );

  Map<String, Object?> toJson() => {
    'games': {for (final e in games.entries) e.key: e.value.toJson()},
    'days': {for (final e in daySeconds.entries) '${e.key}': e.value},
    'daysPlayed': daysPlayed,
    'last': lastDay,
  };

  factory GameStats.fromJson(Map<String, Object?>? j) {
    if (j == null) return const GameStats();
    final g = j['games'];
    final d = j['days'];
    return GameStats(
      games: {
        if (g is Map)
          for (final e in g.entries)
            if (e.value is Map)
              e.key.toString(): GameStatsEntry.fromJson(
                (e.value as Map).cast<String, Object?>(),
              ),
      },
      daySeconds: {
        if (d is Map)
          for (final e in d.entries)
            if (int.tryParse(e.key.toString()) != null && e.value is num)
              int.parse(e.key.toString()): (e.value as num).toInt(),
      },
      daysPlayed: (j['daysPlayed'] as num?)?.toInt() ?? 0,
      lastDay: (j['last'] as num?)?.toInt() ?? -1,
    );
  }
}

/// Text equivalent of the trend line: direction from the last five runs against the five before,
/// then the last five scores. Null with fewer than two runs.
String? trendText(List<RunRecord> runs) {
  if (runs.length < 2) return null;
  final last = runs.length <= 5 ? runs : runs.sublist(runs.length - 5);
  final before = runs.length <= 5
      ? <RunRecord>[]
      : runs.sublist(max(0, runs.length - 10), runs.length - 5);
  double avg(List<RunRecord> l) =>
      l.fold<int>(0, (s, r) => s + r.score) / l.length;
  final a = avg(last);
  final b = before.isEmpty ? avg(runs.sublist(0, 1)) : avg(before);
  final dir = a > b * 1.05 + 0.001
      ? 'up'
      : (a < b * 0.95 - 0.001 ? 'down' : 'steady');
  final word = dir == 'steady' ? 'Scores steady' : 'Scores trending $dir';
  return '$word, last ${last.length}: ${last.map((r) => r.score).join(', ')}';
}

/// Seconds of foreground play, counted in segments. The hub pauses it when the app leaves the
/// foreground and resumes it on return; a clock moved back never makes a segment negative.
class ActiveTimer {
  ActiveTimer(this._clock);
  final DateTime Function() _clock;
  DateTime? _since;
  int _banked = 0;

  bool get running => _since != null;

  void start() => _since ??= _clock();

  void pause() {
    final s = _since;
    if (s == null) return;
    _since = null;
    _banked += max(0, _clock().difference(s).inSeconds);
  }

  void resume() => start();

  /// Total active seconds so far (the timer keeps running).
  int get seconds {
    final s = _since;
    return _banked + (s == null ? 0 : max(0, _clock().difference(s).inSeconds));
  }

  /// Returns the seconds counted since the last restart and starts counting again from zero
  /// (a screen with several runs: each run is timed on its own).
  int lap() {
    final total = seconds;
    _banked = 0;
    if (_since != null) _since = _clock();
    return total;
  }
}
