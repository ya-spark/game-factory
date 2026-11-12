/// Time played per day, kept for about two weeks, so a grown-up can see this week's total.
/// Pure Dart: days are day numbers (the local date as a count), passed in by the caller.
library;

class PlayTimeLog {
  const PlayTimeLog([this.secondsByDay = const {}]);

  /// Days kept; older days are dropped when time is added.
  static const int keepDays = 14;

  /// Longest single stretch counted (a phone left open on the home screen is not play).
  static const int maxStretchSeconds = 2 * 60 * 60;

  final Map<int, int> secondsByDay;

  /// Adds [seconds] to [day]. Zero or negative amounts change nothing; one stretch is capped.
  PlayTimeLog add(int day, int seconds) {
    if (seconds <= 0) return this;
    final s = seconds > maxStretchSeconds ? maxStretchSeconds : seconds;
    final next = {...secondsByDay, day: (secondsByDay[day] ?? 0) + s};
    next.removeWhere((d, _) => d <= day - keepDays);
    return PlayTimeLog(next);
  }

  /// Seconds played in the seven days up to and including [today].
  int weekSeconds(int today) {
    var sum = 0;
    for (final e in secondsByDay.entries) {
      if (e.key > today - 7 && e.key <= today) sum += e.value;
    }
    return sum;
  }

  Map<String, Object?> toJson() => {
    for (final e in secondsByDay.entries) '${e.key}': e.value,
  };

  factory PlayTimeLog.fromJson(Object? j) {
    if (j is! Map) return const PlayTimeLog();
    final out = <int, int>{};
    for (final e in j.entries) {
      final d = int.tryParse('${e.key}');
      final v = e.value;
      if (d != null && v is num && v > 0) out[d] = v.toInt();
    }
    return PlayTimeLog(out);
  }

  /// "Less than a minute", "12 minutes", "1 hour", "1 hour 5 minutes".
  static String describe(int seconds) {
    final minutes = seconds ~/ 60;
    if (minutes < 1) return 'Less than a minute';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    String unit(int n, String w) => '$n $w${n == 1 ? '' : 's'}';
    if (h == 0) return unit(m, 'minute');
    if (m == 0) return unit(h, 'hour');
    return '${unit(h, 'hour')} ${unit(m, 'minute')}';
  }
}
