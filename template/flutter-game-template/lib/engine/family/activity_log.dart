/// A daily activity log per child, kept for 8 weeks, so a grown-up can compare this week with
/// last week. Pure Dart: days are day numbers (the local date as a count), passed in by the
/// caller. Stored in the child's profile next to the play-time log; never leaves the device.
library;

import '../content/progress.dart';

/// What one child did on one day.
class DayActivity {
  const DayActivity({
    this.answers = 0,
    this.correct = 0,
    this.newlyPassed = 0,
    this.topics = const {},
  });

  final int answers;
  final int correct;

  /// Items passed for the first time that day.
  final int newlyPassed;

  /// Topic keys (`subject/year/topic`) touched that day.
  final Set<String> topics;

  DayActivity plus(DayActivity o) => DayActivity(
    answers: answers + o.answers,
    correct: correct + o.correct,
    newlyPassed: newlyPassed + o.newlyPassed,
    topics: {...topics, ...o.topics},
  );

  Map<String, Object?> toJson() => {
    'a': answers,
    'c': correct,
    'p': newlyPassed,
    't': (topics.toList()..sort()),
  };

  factory DayActivity.fromJson(Object? j) {
    if (j is! Map) return const DayActivity();
    int n(Object? v) => v is num && v > 0 ? v.toInt() : 0;
    return DayActivity(
      answers: n(j['a']),
      correct: n(j['c']),
      newlyPassed: n(j['p']),
      topics: {
        if (j['t'] is List)
          for (final t in j['t'] as List)
            if (t is String) t,
      },
    );
  }
}

class ActivityLog {
  const ActivityLog([this.days = const {}]);

  /// Days kept (8 weeks); older days are dropped when activity is added.
  static const int keepDays = 56;

  final Map<int, DayActivity> days;

  /// The last day with an entry, or null for an empty log.
  int? get lastDay =>
      days.isEmpty ? null : days.keys.reduce((a, b) => a > b ? a : b);

  /// Adds [a] to [day]. Nothing happens for an empty [a] or when the clock went back (a day
  /// before the latest entry): a later day is never overwritten.
  ActivityLog add(int day, DayActivity a) {
    if (a.answers <= 0 && a.newlyPassed <= 0) return this;
    final last = lastDay;
    if (last != null && day < last) return this;
    final next = {...days, day: (days[day] ?? const DayActivity()).plus(a)};
    next.removeWhere((d, _) => d <= day - keepDays);
    return ActivityLog(next);
  }

  /// Adds what changed between [before] and [after] (the answers recorded in between).
  ActivityLog recordChange(int day, ChildProgress before, ChildProgress after) {
    var answers = 0;
    var correct = 0;
    final touched = <String>{};
    for (final e in after.topics.entries) {
      final b = before.topics[e.key];
      final da = e.value.answers - (b?.answers ?? 0);
      if (da > 0) {
        answers += da;
        correct += (e.value.correct - (b?.correct ?? 0)).clamp(0, da);
        touched.add(e.key);
      }
    }
    var passed = 0;
    for (final e in after.items.entries) {
      if (e.value.passed && !(before.items[e.key]?.passed ?? false)) passed++;
    }
    return add(
      day,
      DayActivity(
        answers: answers,
        correct: correct,
        newlyPassed: passed,
        topics: touched,
      ),
    );
  }

  /// The totals for the seven days that end [weeksAgo] weeks before [today] (0 = this week:
  /// the seven days up to and including [today]).
  DayActivity week(int today, {int weeksAgo = 0}) {
    final end = today - 7 * weeksAgo;
    var sum = const DayActivity();
    for (final e in days.entries) {
      if (e.key > end - 7 && e.key <= end) sum = sum.plus(e.value);
    }
    return sum;
  }

  /// Days with activity in the seven days that end [weeksAgo] weeks before [today].
  int daysPlayed(int today, {int weeksAgo = 0}) {
    final end = today - 7 * weeksAgo;
    return days.entries
        .where((e) => e.key > end - 7 && e.key <= end && e.value.answers > 0)
        .length;
  }

  /// The longest run of days in a row with activity inside that week.
  int longestRun(int today, {int weeksAgo = 0}) {
    final end = today - 7 * weeksAgo;
    var best = 0;
    var run = 0;
    for (var d = end - 6; d <= end; d++) {
      if ((days[d]?.answers ?? 0) > 0) {
        run++;
        if (run > best) best = run;
      } else {
        run = 0;
      }
    }
    return best;
  }

  Map<String, Object?> toJson() => {
    for (final e in days.entries) '${e.key}': e.value.toJson(),
  };

  factory ActivityLog.fromJson(Object? j) {
    if (j is! Map) return const ActivityLog();
    final out = <int, DayActivity>{};
    for (final e in j.entries) {
      final d = int.tryParse('${e.key}');
      if (d == null) continue;
      final a = DayActivity.fromJson(e.value);
      if (a.answers > 0 || a.newlyPassed > 0) out[d] = a;
    }
    return ActivityLog(out);
  }
}
