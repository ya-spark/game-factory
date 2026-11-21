/// Skill mastery: evidence per skill, the states of the trail, the advance rule and the skip-ahead
/// check. Pure Dart; the day number and `Random` are passed in.
///
/// Only item results move a skill. A game's own score is never evidence. See
/// `docs/VISION-education.md` (section 8) in the studio repo.
library;

import 'dart:math';

import 'models.dart';
import 'progress.dart';
import 'skills.dart';

/// The result of one answer, as evidence about a skill.
class SkillEvidence {
  const SkillEvidence({
    required this.correct,
    required this.day,
    required this.format,
    this.weight = 1.0,
  });

  final bool correct;

  /// Local day number of the answer.
  final int day;

  /// `ItemType.name` of the item.
  final String format;

  /// 1.0, or 0.5 for a 2-option question (half the guesses are right).
  final double weight;

  Map<String, Object?> toJson() => {
    'c': correct ? 1 : 0,
    'd': day,
    'f': format,
    if (weight != 1.0) 'w': weight,
  };

  factory SkillEvidence.fromJson(Map<String, Object?> j) => SkillEvidence(
    correct: (j['c'] as num?)?.toInt() == 1,
    day: (j['d'] as num?)?.toInt() ?? 0,
    format: (j['f'] as String?) ?? 'mcq',
    weight: (j['w'] as num?)?.toDouble() ?? 1.0,
  );
}

/// The advance rule of an app. Defaults follow `docs/VISION-education.md`.
class SkillRules {
  const SkillRules({
    this.window = 10,
    this.minAccuracy = 0.80,
    this.minDays = 2,
    this.minItems = minSkillItems,
    this.revisionGapDays = 3,
    this.decayDays = 42,
    this.timeoutCounts = true,
    this.checkItems = 5,
    this.checkPass = 4,
    this.checkWaitDays = 1,
  });

  /// Latest results looked at.
  final int window;
  final double minAccuracy;

  /// Different days the window must span.
  final int minDays;

  /// Results the window needs before it can pass.
  final int minItems;

  /// A correct answer this many days after becoming secure counts as the revision pass.
  final int revisionGapDays;

  /// A mastered skill not answered for this many days falls back to secure.
  final int decayDays;

  /// Whether a timeout is a wrong answer. Scout never penalises.
  final bool timeoutCounts;

  final int checkItems;
  final int checkPass;
  final int checkWaitDays;

  static const SkillRules scout = SkillRules(
    window: 8,
    minAccuracy: 0.75,
    timeoutCounts: false,
  );
  static const SkillRules ranger = SkillRules();
  static const SkillRules champion = SkillRules(minAccuracy: 0.85);

  /// `scout`, `ranger` or `champion`; anything else gets the Ranger rule.
  factory SkillRules.forProfile(String? name) => switch (name) {
    'scout' => scout,
    'champion' => champion,
    _ => ranger,
  };

  /// The rule for a child of [year]: the three Craft apps cover Years 0 to 6 (Scout), 7 to 10
  /// (Ranger) and 11 to 12 (Champion), so the year picks the same rule the app would. Null or an
  /// unknown year gets Ranger's.
  factory SkillRules.forYear(int? year) => year == null
      ? ranger
      : (year <= 6 ? scout : (year <= 10 ? ranger : champion));

  /// Results kept per skill: never fewer than the window.
  int get keep => max(window, 10);
}

enum SkillState { locked, unseen, practising, secure, mastered }

/// What one child has done on one skill.
class SkillProgress {
  const SkillProgress({
    this.evidence = const [],
    this.formatsCorrect = const {},
    this.secureDay,
    this.revisionDay,
    this.lastDay,
    this.byCheck = false,
    this.checkFailDay,
  });

  /// Latest results, oldest first.
  final List<SkillEvidence> evidence;

  /// Formats with at least one correct answer.
  final Set<String> formatsCorrect;

  /// The day the rule was first met; null until then.
  final int? secureDay;

  /// The day of the revision pass; null until then.
  final int? revisionDay;
  final int? lastDay;

  /// Secure because a skip-ahead check was passed (or a later rung was): shown as such.
  final bool byCheck;
  final int? checkFailDay;

  /// Whether the latest results meet the rule.
  bool metBy(SkillRules r) {
    final w = evidence.length <= r.window
        ? evidence
        : evidence.sublist(evidence.length - r.window);
    if (w.length < r.minItems) return false;
    var total = 0.0, right = 0.0;
    for (final e in w) {
      total += e.weight;
      if (e.correct) right += e.weight;
    }
    if (total <= 0 || right / total < r.minAccuracy) return false;
    return w.map((e) => e.day).toSet().length >= r.minDays;
  }

  /// Weighted accuracy of the window, 0..1; null before any result.
  double? accuracy(SkillRules r) {
    if (evidence.isEmpty) return null;
    final w = evidence.length <= r.window
        ? evidence
        : evidence.sublist(evidence.length - r.window);
    var total = 0.0, right = 0.0;
    for (final e in w) {
      total += e.weight;
      if (e.correct) right += e.weight;
    }
    return total <= 0 ? null : right / total;
  }

  /// State, ignoring prerequisites (the trail adds `locked`). [formatsInRung] is how many
  /// formats the skill's items cover: a second format is only asked for when there is one.
  SkillState stateOf(
    SkillRules r, {
    required int today,
    int formatsInRung = 2,
  }) {
    final secure = metBy(r);
    if (!secure) {
      return byCheck
          ? SkillState.secure
          : (evidence.isEmpty ? SkillState.unseen : SkillState.practising);
    }
    final formatsOk = formatsInRung < 2 || formatsCorrect.length >= 2;
    final fresh = lastDay == null || today - lastDay! <= r.decayDays;
    if (formatsOk && revisionDay != null && fresh) return SkillState.mastered;
    return SkillState.secure;
  }

  /// Adds one result and updates the dates the rule needs.
  SkillProgress add(SkillEvidence e, SkillRules r) {
    final list = [...evidence, e];
    final kept = list.length > r.keep
        ? list.sublist(list.length - r.keep)
        : list;
    var next = SkillProgress(
      evidence: kept,
      formatsCorrect: e.correct
          ? {...formatsCorrect, e.format}
          : formatsCorrect,
      secureDay: secureDay,
      revisionDay: revisionDay,
      lastDay: lastDay == null ? e.day : max(lastDay!, e.day),
      byCheck: byCheck,
      checkFailDay: checkFailDay,
    );
    if (next.secureDay == null && next.metBy(r)) {
      next = next._with(secureDay: e.day);
    }
    if (next.secureDay != null &&
        next.revisionDay == null &&
        e.correct &&
        e.day >= next.secureDay! + r.revisionGapDays) {
      next = next._with(revisionDay: e.day);
    }
    return next;
  }

  SkillProgress _with({
    int? secureDay,
    int? revisionDay,
    bool? byCheck,
    int? checkFailDay,
    int? lastDay,
  }) => SkillProgress(
    evidence: evidence,
    formatsCorrect: formatsCorrect,
    secureDay: secureDay ?? this.secureDay,
    revisionDay: revisionDay ?? this.revisionDay,
    lastDay: lastDay ?? this.lastDay,
    byCheck: byCheck ?? this.byCheck,
    checkFailDay: checkFailDay ?? this.checkFailDay,
  );

  SkillProgress markByCheck(int day) => _with(byCheck: true, lastDay: day);
  SkillProgress markCheckFailed(int day) => _with(checkFailDay: day);

  Map<String, Object?> toJson() => {
    'e': [for (final e in evidence) e.toJson()],
    'f': formatsCorrect.toList()..sort(),
    if (secureDay != null) 's': secureDay,
    if (revisionDay != null) 'r': revisionDay,
    if (lastDay != null) 'l': lastDay,
    if (byCheck) 'k': 1,
    if (checkFailDay != null) 'x': checkFailDay,
  };

  factory SkillProgress.fromJson(Map<String, Object?> j) => SkillProgress(
    evidence: [
      for (final e in (j['e'] as List? ?? const []))
        if (e is Map) SkillEvidence.fromJson(e.cast()),
    ],
    formatsCorrect: {...?(j['f'] as List?)?.cast<String>()},
    secureDay: (j['s'] as num?)?.toInt(),
    revisionDay: (j['r'] as num?)?.toInt(),
    lastDay: (j['l'] as num?)?.toInt(),
    byCheck: (j['k'] as num?)?.toInt() == 1,
    checkFailDay: (j['x'] as num?)?.toInt(),
  );
}

/// Weight and validity of one answer as evidence. Returns null when it must not count at all
/// (a timeout in an app that never penalises).
SkillEvidence? evidenceFor(
  PoolItem p, {
  required bool correct,
  required int day,
  required SkillRules rules,
  bool hinted = false,
  bool timedOut = false,
}) {
  if (timedOut && !rules.timeoutCounts) return null;
  final options = p.item.type == ItemType.mcq
      ? (p.item.json['options'] as List?)?.length
      : null;
  return SkillEvidence(
    correct: correct && !hinted && !timedOut,
    day: day,
    format: p.item.type.name,
    weight: options == 2 ? 0.5 : 1.0,
  );
}

/// The skip-ahead check: a few items of one skill, most of them right.
abstract final class SkipCheck {
  /// Items that are hard to guess: not a 2-option question, preferring other formats and `mcq`
  /// with 3 or more options. Falls back to guessable ones when there are too few.
  static List<PoolItem> pick(
    Iterable<PoolItem> skillItems,
    SkillRules rules,
    Random random,
  ) {
    bool guessable(PoolItem p) =>
        p.item.type == ItemType.mcq &&
        ((p.item.json['options'] as List?)?.length ?? 0) < 3;
    final all = skillItems.toList()..sort((a, b) => a.id.compareTo(b.id));
    final good = [
      for (final p in all)
        if (!guessable(p)) p,
    ]..shuffle(random);
    final rest = [
      for (final p in all)
        if (guessable(p)) p,
    ]..shuffle(random);
    return [...good, ...rest].take(rules.checkItems).toList();
  }

  static bool passed(int correct, SkillRules rules) =>
      correct >= rules.checkPass;

  /// Whether the child may try the check on [skill] on [day] (not twice on the day of a miss).
  static bool canTry(ChildProgress p, Skill skill, int day, SkillRules rules) {
    final f = p.skills[skill.key]?.checkFailDay;
    return f == null || day >= f + rules.checkWaitDays;
  }

  /// A pass unlocks the skill and marks it and every rung before it secure by check. Rungs that
  /// are already secure by evidence keep their evidence. A miss only starts the short wait.
  static ChildProgress apply(
    ChildProgress p,
    Skill skill,
    SkillMap map, {
    required bool passed,
    required int day,
    required SkillRules rules,
  }) {
    final next = {...p.skills};
    if (!passed) {
      next[skill.key] = (next[skill.key] ?? const SkillProgress())
          .markCheckFailed(day);
      return p.copyWith(skills: next);
    }
    for (final key in [skill.key, ...map.ancestorsOf(skill)]) {
      final cur = next[key] ?? const SkillProgress();
      next[key] = cur.markByCheck(day);
    }
    return p.copyWith(skills: next);
  }
}

/// Builds starting evidence for a child whose progress predates skills, from the per-item results
/// already saved: one result per answered item (its last answer, on its last day). Nobody loses
/// progress; "mastered" is never granted by history alone.
ChildProgress migrateToSkills(
  ChildProgress old,
  Iterable<PoolItem> allItems,
  SkillRules rules,
) {
  if (old.skills.isNotEmpty || old.items.isEmpty) return old;
  final byRung = <String, List<MapEntry<PoolItem, ItemResult>>>{};
  for (final p in allItems) {
    final k = p.skillKey;
    final r = old.items[p.id];
    if (k == null || r == null || r.attempts <= 0) continue;
    (byRung[k] ??= []).add(MapEntry(p, r));
  }
  final out = <String, SkillProgress>{};
  for (final e in byRung.entries) {
    final rows = e.value
      ..sort((a, b) {
        final c = (a.value.lastSeenDay ?? 0).compareTo(
          b.value.lastSeenDay ?? 0,
        );
        return c != 0 ? c : a.key.id.compareTo(b.key.id);
      });
    var sp = const SkillProgress();
    for (final row in rows) {
      sp = sp.add(
        SkillEvidence(
          correct: row.value.lastCorrect,
          day: row.value.lastSeenDay ?? 0,
          format: row.key.item.type.name,
          weight:
              row.key.item.type == ItemType.mcq &&
                  ((row.key.item.json['options'] as List?)?.length ?? 0) == 2
              ? 0.5
              : 1.0,
        ),
        rules,
      );
    }
    // History alone never grants mastered: drop the revision pass.
    out[e.key] = SkillProgress(
      evidence: sp.evidence,
      formatsCorrect: sp.formatsCorrect,
      secureDay: sp.secureDay,
      lastDay: sp.lastDay,
    );
  }
  return out.isEmpty ? old : old.copyWith(skills: out);
}
