/// Cognitive skills for the Mind hubs: what each standalone game trains, the level a score
/// reaches, a trend, and the daily workout. Pure Dart; the day number is passed in.
///
/// Nothing here is saved: levels and trends come from the per-game stats the hubs already keep
/// (best score and the last 20 runs), and today's workout is a function of the runs before today,
/// so it does not change as the player plays it. Wording stays modest: exercise, practise,
/// challenge. Never a claim to prevent decline or to treat anything.
library;

import 'dart:math';

import '../stats/game_stats.dart';

enum CognitiveSkill {
  memory('Memory'),
  attention('Attention'),
  logic('Logic'),
  spatial('Spatial thinking'),
  speed('Reaction'),
  maths('Number sense'),
  words('Words');

  const CognitiveSkill(this.label);
  final String label;
}

/// What each standalone game trains. A game not listed here is not part of the journey.
const Map<String, CognitiveSkill> gameSkill = {
  'block_puzzle': CognitiveSkill.spatial,
  'blockfall': CognitiveSkill.spatial,
  'sudoku': CognitiveSkill.logic,
  'solitaire': CognitiveSkill.logic,
  'ball_sort': CognitiveSkill.logic,
  'mahjong': CognitiveSkill.memory,
  'merge': CognitiveSkill.maths,
  'wingy': CognitiveSkill.attention,
  'snake': CognitiveSkill.spatial,
  'bricks': CognitiveSkill.speed,
  'stack': CognitiveSkill.attention,
  'runner': CognitiveSkill.speed,
};

/// Levels in a skill's journey.
const int skillLevels = 8;

/// Score needed for each of the [skillLevels] levels of a game, from its three star scores
/// (`MiniGame.starScores`): a quarter of the first, half, the first, between first and second,
/// the second, between second and third, the third, and half as much again. A game with no star
/// scores gets a plain ladder. Always ascending and at least 1.
List<int> levelThresholds(List<int>? stars) {
  final s = (stars == null || stars.length < 3)
      ? const [100, 400, 1000]
      : stars;
  final a = max(1, s[0]), b = max(a + 1, s[1]), c = max(b + 1, s[2]);
  final raw = [
    a / 4,
    a / 2,
    a.toDouble(),
    (a + b) / 2,
    b.toDouble(),
    (b + c) / 2,
    c.toDouble(),
    c * 1.5,
  ];
  final out = <int>[];
  for (final v in raw) {
    final n = max(1, v.round());
    out.add(out.isEmpty || n > out.last ? n : out.last + 1);
  }
  return out;
}

/// The level (0 to [skillLevels]) a [score] reaches.
int levelFor(int score, List<int> thresholds) {
  var level = 0;
  for (final t in thresholds) {
    if (score >= t) level++;
  }
  return level;
}

/// One skill as the Journey shows it.
class SkillSummary {
  const SkillSummary({
    required this.skill,
    required this.level,
    required this.gameIds,
    required this.plays,
    required this.trendPercent,
  });
  final CognitiveSkill skill;

  /// The highest level any of its games has reached (0 before the first run).
  final int level;
  final List<String> gameIds;
  final int plays;

  /// Change of recent runs against the runs before them, in whole percent; null with too few runs.
  final int? trendPercent;

  /// "Your reaction is up 12% over your last few games", or null with nothing to say.
  String? get trendText {
    final t = trendPercent;
    if (t == null || t == 0) return null;
    final name = skill.label.toLowerCase();
    return t > 0
        ? 'Your $name scores are up $t% over your last few games.'
        : 'Your $name scores are down ${-t}% over your last few games.';
  }
}

abstract final class MindSkills {
  /// Runs a trend needs: the latest [trendWindow] against the [trendWindow] before them.
  static const int trendWindow = 3;

  /// The skills of the games in [starScores] (game id to its star scores), in enum order, with
  /// level and trend from [stats]. A skill with no available game is left out.
  static List<SkillSummary> summaries(
    GameStats stats,
    Map<String, List<int>?> starScores,
  ) {
    final out = <SkillSummary>[];
    for (final skill in CognitiveSkill.values) {
      final ids = [
        for (final id in starScores.keys)
          if (gameSkill[id] == skill) id,
      ];
      if (ids.isEmpty) continue;
      var level = 0;
      var plays = 0;
      final ratios = <(int day, double ratio)>[];
      for (final id in ids) {
        final e = stats.games[id];
        if (e == null) continue;
        final th = levelThresholds(starScores[id]);
        level = max(level, levelFor(e.bestScore, th));
        plays += e.plays;
        for (final r in e.runs) {
          ratios.add((r.day, r.score / th.last));
        }
      }
      ratios.sort((a, b) => a.$1.compareTo(b.$1));
      out.add(
        SkillSummary(
          skill: skill,
          level: level,
          gameIds: ids,
          plays: plays,
          trendPercent: _trend([for (final r in ratios) r.$2]),
        ),
      );
    }
    return out;
  }

  static int? _trend(List<double> ratios) {
    const w = trendWindow;
    if (ratios.length < w * 2) return null;
    double mean(List<double> v) => v.reduce((a, b) => a + b) / v.length;
    final now = mean(ratios.sublist(ratios.length - w));
    final before = mean(
      ratios.sublist(ratios.length - 2 * w, ratios.length - w),
    );
    if (before <= 0) return null;
    return ((now - before) / before * 100).round();
  }
}

/// One game in today's workout.
class WorkoutItem {
  const WorkoutItem({
    required this.gameId,
    required this.skill,
    required this.done,
  });
  final String gameId;
  final CognitiveSkill skill;
  final bool done;
}

class Workout {
  const Workout(this.items);
  final List<WorkoutItem> items;
  bool get complete => items.isNotEmpty && items.every((i) => i.done);
  int get doneCount => items.where((i) => i.done).length;

  /// The first game not yet played today; null when the workout is complete or empty.
  WorkoutItem? get next {
    for (final i in items) {
      if (!i.done) return i;
    }
    return null;
  }
}

abstract final class DailyWorkout {
  /// Games in a workout.
  static const int size = 4;

  /// Today's workout: one game from each of up to [size] different skills (the lowest level and
  /// least recently played skills first), topped up with other games when there are fewer
  /// skills. It depends only on the runs before [today] and on [today] itself, so it stays the
  /// same all day; a game is done when it has a run today.
  static Workout plan(
    GameStats stats, {
    required int today,
    required Iterable<String> gameIds,
    Map<String, List<int>?> starScores = const {},
  }) {
    final ids = [
      for (final id in gameIds)
        if (gameSkill.containsKey(id)) id,
    ]..sort();
    if (ids.isEmpty) return const Workout([]);

    int lastBefore(String id) {
      final runs = stats.games[id]?.runs ?? const <RunRecord>[];
      var d = -1;
      for (final r in runs) {
        if (r.day < today && r.day > d) d = r.day;
      }
      return d;
    }

    int bestBefore(String id) {
      final runs = stats.games[id]?.runs ?? const <RunRecord>[];
      var b = 0;
      for (final r in runs) {
        if (r.day < today && r.score > b) b = r.score;
      }
      return b;
    }

    int playedBefore(String id) =>
        (stats.games[id]?.runs ?? const <RunRecord>[])
            .where((r) => r.day < today)
            .length;

    final rng = Random(today);
    final tie = {for (final id in ids) id: rng.nextInt(1 << 20)};

    final bySkill = <CognitiveSkill, List<String>>{};
    for (final id in ids) {
      (bySkill[gameSkill[id]!] ??= []).add(id);
    }
    int skillLevel(CognitiveSkill s) {
      var l = 0;
      for (final id in bySkill[s]!) {
        l = max(l, levelFor(bestBefore(id), levelThresholds(starScores[id])));
      }
      return l;
    }

    int skillLast(CognitiveSkill s) => bySkill[s]!.map(lastBefore).reduce(max);

    final skills = bySkill.keys.toList()
      ..sort((a, b) {
        final c = skillLevel(a).compareTo(skillLevel(b));
        if (c != 0) return c;
        final d = skillLast(a).compareTo(skillLast(b));
        return d != 0
            ? d
            : tie[bySkill[a]!.first]!.compareTo(tie[bySkill[b]!.first]!);
      });

    // The game of a skill played least recently, then least often.
    String pick(List<String> games) {
      final g = [...games]
        ..sort((a, b) {
          final c = lastBefore(a).compareTo(lastBefore(b));
          if (c != 0) return c;
          final p = playedBefore(a).compareTo(playedBefore(b));
          return p != 0 ? p : tie[a]!.compareTo(tie[b]!);
        });
      return g.first;
    }

    final chosen = <String>[];
    for (final s in skills) {
      if (chosen.length >= size) break;
      chosen.add(pick(bySkill[s]!));
    }
    if (chosen.length < size) {
      // Fewer skills than the workout holds: add the least played other games.
      final rest =
          [
            for (final id in ids)
              if (!chosen.contains(id)) id,
          ]..sort((a, b) {
            final p = playedBefore(a).compareTo(playedBefore(b));
            return p != 0 ? p : tie[a]!.compareTo(tie[b]!);
          });
      chosen.addAll(rest.take(size - chosen.length));
    }
    bool doneToday(String id) => (stats.games[id]?.runs ?? const <RunRecord>[])
        .any((r) => r.day == today);
    return Workout([
      for (final id in chosen)
        WorkoutItem(gameId: id, skill: gameSkill[id]!, done: doneToday(id)),
    ]);
  }
}
