/// One round of any minigame: items from the selector, answers recorded per child, stars and
/// capped coins awarded the same way for every game. Pure Dart.
library;

import 'dart:math';

import '../content/mastery.dart';
import '../content/models.dart';
import '../content/progress.dart';
import '../rewards/rewards.dart';

/// What one answer earned.
class AnswerResult {
  const AnswerResult({
    required this.correct,
    required this.firstPass,
    required this.stars,
    required this.coins,
    required this.topicCompleted,
    required this.explanation,
  });
  final bool correct;

  /// The first time this child passed this item.
  final bool firstPass;
  final int stars;

  /// Coins to add to the wallet (already cut to the weekly cap).
  final int coins;
  final bool topicCompleted;
  final String explanation;
}

/// A round's summary.
class SessionReport {
  const SessionReport({
    required this.answered,
    required this.correct,
    required this.stars,
    required this.coins,
  });
  final int answered;
  final int correct;
  final int stars;
  final int coins;
}

class QuizSession {
  QuizSession({
    required this.items,
    required this.progress,
    required Iterable<LoadedPack> packs,
    required this.rewardsConfig,
    required this.today,
    this.streakDays = 0,
    this.gameId,
    this.rules = SkillRules.ranger,
  }) : _topicSizes = _sizes(packs);

  /// Starts a round, or returns null when fewer than [minPool] matching items are open.
  static QuizSession? start({
    required List<PoolItem> open,
    required ChildProgress progress,
    required Iterable<LoadedPack> packs,
    required RewardsConfig rewardsConfig,
    required String subject,
    required int year,
    required int today,
    required Random random,
    Set<ItemType>? types,
    bool Function(PoolItem item)? accepts,
    String? skillKey,
    SkillRules? rules,
    String? topic,
    int count = 10,
    int minPool = 4,
    int streakDays = 0,
    String? gameId,
  }) {
    final matching = [
      for (final p in open)
        if (p.subject == subject &&
            p.year == year &&
            (topic == null || p.topic == topic) &&
            (types == null || types.contains(p.item.type)) &&
            (accepts == null || accepts(p)) &&
            (skillKey == null || p.skillKey == skillKey))
          p,
    ];
    if (matching.length < minPool) return null;
    final picked = ItemSelector.select(
      open: matching,
      subject: subject,
      year: year,
      topic: topic,
      count: count,
      random: random,
      recent: progress.recent,
    );
    return QuizSession(
      items: picked,
      progress: progress,
      packs: packs,
      rewardsConfig: rewardsConfig,
      today: today,
      streakDays: streakDays,
      gameId: gameId,
      rules: rules ?? SkillRules.forYear(year),
    );
  }

  /// The advance rule of the app, used for skill evidence.
  final SkillRules rules;

  /// The minigame being played, for its per-game stats.
  final String? gameId;
  final List<PoolItem> items;
  final RewardsConfig rewardsConfig;

  /// Local day number, for the daily and weekly goals.
  final int today;
  final int streakDays;
  final Map<String, int> _topicSizes;

  /// The child's progress including every answer so far. Save it after each answer.
  ChildProgress progress;

  int _index = 0;
  int _answered = 0;
  int _correct = 0;
  int _stars = 0;
  int _coins = 0;

  static Map<String, int> _sizes(Iterable<LoadedPack> packs) {
    final m = <String, int>{};
    for (final lp in packs) {
      final p = lp.pack;
      for (final it in p.items) {
        final k = topicKey(p.subject, p.year, it.topicOr(p.topic) ?? p.topic);
        m[k] = (m[k] ?? 0) + 1;
      }
    }
    return m;
  }

  int get index => _index;
  int get total => items.length;
  bool get finished => _index >= items.length;
  PoolItem? get current => finished ? null : items[_index];

  /// Records the answer to the current item and moves on. Throws when [finished].
  /// [truth] is whether the child really knew the answer, when the game scores something else
  /// (a younger level that never loses a round): skill evidence uses it, never the game's score.
  /// [skillEvidence] false adds no skill evidence for this answer (light-evidence games).
  AnswerResult answer({
    required bool correct,
    bool? truth,
    bool hinted = false,
    bool timedOut = false,
    bool skillEvidence = true,
  }) {
    final p = current;
    if (p == null) throw StateError('The round is finished');
    final firstPass = correct && !(progress.items[p.id]?.passed ?? false);
    final tk0 = topicKey(p.subject, p.year, p.topic);
    final newTopic = !progress.topics.containsKey(tk0);
    final earlier = progress.items[p.id];
    final revised =
        correct &&
        earlier != null &&
        (!earlier.lastCorrect || earlier.isDue(today));
    var next = progress.record(
      p,
      correct: correct,
      gameId: gameId,
      day: today,
      rules: rules,
      hinted: hinted,
      timedOut: timedOut,
    );
    if (truth != null && truth != correct) {
      // The item record and topic counts follow what the game scored, as before; the skill
      // evidence follows what the child really knew.
      next = next.copyWith(
        skills: progress
            .record(
              p,
              correct: truth,
              gameId: gameId,
              day: today,
              rules: rules,
              hinted: hinted,
              timedOut: timedOut,
            )
            .skills,
      );
    }
    // A game with light evidence (Judge bot: two choices) records the item as usual but adds no
    // skill evidence for this answer.
    if (!skillEvidence) next = next.copyWith(skills: progress.skills);
    var stars = 0;
    var coins = 0;
    var topicDone = false;
    if (firstPass) {
      final tk = topicKey(p.subject, p.year, p.topic);
      final size = _topicSizes[tk] ?? 0;
      topicDone = size > 0 && (next.topics[tk]?.passed ?? 0) >= size;
      final g = RewardsEngine.onFirstPass(
        next.rewards,
        rewardsConfig,
        day: today,
        topicKey: tk,
        topicDone: topicDone,
        streakDays: streakDays,
      );
      next = next.copyWith(rewards: g.state);
      stars = g.stars;
      coins = g.coins;
    }
    final c = RewardsEngine.onAnswer(
      next.rewards,
      rewardsConfig,
      day: today,
      newTopic: newTopic,
      revised: revised,
    );
    next = next.copyWith(rewards: c.state);
    coins += c.coins;
    progress = next;
    _index++;
    _answered++;
    if (correct) _correct++;
    _stars += stars;
    _coins += coins;
    return AnswerResult(
      correct: correct,
      firstPass: firstPass,
      stars: stars,
      coins: coins,
      topicCompleted: topicDone,
      explanation: p.item.explanation,
    );
  }

  SessionReport get report => SessionReport(
    answered: _answered,
    correct: _correct,
    stars: _stars,
    coins: _coins,
  );
}
