/// The trail: the rungs of one subject and year with their state, and the choice of the next
/// step. Pure Dart; the day and the `Random` are passed in.
library;

import 'dart:math';

import '../minigames/minigame.dart';
import 'mastery.dart';
import 'models.dart';
import 'progress.dart';
import 'skills.dart';

/// One rung as the trail shows it.
class TrailNode {
  const TrailNode({
    required this.skill,
    required this.state,
    required this.openItems,
    required this.accuracy,
  });

  final Skill skill;

  /// `locked` while a prerequisite rung is not secure and the rung has no evidence of its own.
  final SkillState state;

  /// Items of this rung open to the child today.
  final int openItems;

  /// Weighted accuracy of the latest results, 0..1; null before the first answer.
  final double? accuracy;

  bool get isLocked => state == SkillState.locked;

  /// Nothing of this rung has been released yet (the daily release opens items as you go).
  bool get opensAsYouGo => openItems == 0;

  /// Whether practice can start now.
  bool get canPractise => !isLocked && openItems >= minRoundItems;

  /// 0 to 3 stars: practising 1, secure 2, mastered 3. Progress only; never spent.
  int get stars => switch (state) {
    SkillState.locked || SkillState.unseen => 0,
    SkillState.practising => 1,
    SkillState.secure => 2,
    SkillState.mastered => 3,
  };

  String get key => skill.key;
}

/// Fewest open items a round on a rung needs.
const int minRoundItems = 4;

abstract final class Trail {
  /// The rungs of [subject] in [year], in teaching order, with their state.
  static List<TrailNode> build({
    required String subject,
    required int year,
    required SkillMap skills,
    required ChildProgress progress,
    required Iterable<PoolItem> open,
    required SkillRules rules,
    required int today,
  }) {
    final rungs = skills.skillsFor(subject, year);
    final openCount = <String, int>{};
    final formats = <String, Set<ItemType>>{};
    for (final p in open) {
      final k = p.skillKey;
      if (k == null) continue;
      openCount[k] = (openCount[k] ?? 0) + 1;
      (formats[k] ??= {}).add(p.item.type);
    }
    final base = <String, SkillState>{};
    SkillState own(Skill s) {
      final sp = progress.skills[s.key] ?? const SkillProgress();
      return sp.stateOf(
        rules,
        today: today,
        formatsInRung: formats[s.key]?.length ?? 2,
      );
    }

    for (final s in rungs) {
      base[s.key] = own(s);
    }
    bool met(String key) {
      final st = base[key] ?? own(skills.byKey(key)!);
      return st == SkillState.secure || st == SkillState.mastered;
    }

    return [
      for (final s in rungs)
        TrailNode(
          skill: s,
          state: _stateWithLock(s, base[s.key]!, met),
          openItems: openCount[s.key] ?? 0,
          accuracy: progress.skills[s.key]?.accuracy(rules),
        ),
    ];
  }

  static SkillState _stateWithLock(
    Skill s,
    SkillState own,
    bool Function(String key) met,
  ) {
    if (own != SkillState.unseen) return own;
    return s.requires.every(met) ? own : SkillState.locked;
  }

  /// The rung Auto offers: the first unlocked rung that is not yet secure and has enough open
  /// items; else the secure rung with the lowest accuracy to keep fresh. Null when none.
  static TrailNode? autoRung(List<TrailNode> nodes) {
    for (final n in nodes) {
      if (n.canPractise &&
          (n.state == SkillState.unseen || n.state == SkillState.practising)) {
        return n;
      }
    }
    TrailNode? weakest;
    for (final n in nodes) {
      if (n.canPractise && n.state == SkillState.secure) {
        if (weakest == null || (n.accuracy ?? 1) < (weakest.accuracy ?? 1)) {
          weakest = n;
        }
      }
    }
    return weakest;
  }
}

/// A round chosen by the trail: one rung, the game that plays it and the items.
class TrailRound {
  const TrailRound({
    required this.skill,
    required this.game,
    required this.items,
  });
  final Skill skill;
  final MiniGame game;

  /// Items of the rung, with a few revision items added.
  final List<PoolItem> items;
}

/// How a round is chosen. Auto picks the rung and the game; the child may pick either.
abstract final class NextStep {
  /// Items in one round, and revision items added to it.
  static const int roundSize = 10;
  static const int revisionMax = 2;

  /// Games that can play at least [minRoundItems] of the rung's open items, in the registry's
  /// order, free or unlocked ones first.
  static List<MiniGame> gamesFor({
    required MiniGameRegistry registry,
    required Iterable<PoolItem> rungItems,
    required int year,
    required MiniGameMode mode,
    required Set<String> unlocked,
  }) {
    final items = rungItems.toList();
    final out = <MiniGame>[];
    for (final e in registry.entries) {
      final g = e.game;
      if (g.standalone) continue;
      if (!(e.modes ?? g.modes).contains(mode)) continue;
      if (year < e.minYear || year > e.maxYear) continue;
      final n = items.where(g.canPlay).length;
      if (n < (g.minPool < minRoundItems ? g.minPool : minRoundItems)) continue;
      out.add(g);
    }
    out.sort((a, b) {
      final pa = MiniGameRegistry.isPlayable(a, unlocked) ? 0 : 1;
      final pb = MiniGameRegistry.isPlayable(b, unlocked) ? 0 : 1;
      return pa.compareTo(pb);
    });
    return out;
  }

  /// Auto's game: of the playable games, the one the child has played least on this device
  /// (fewest passes), ties broken at random, never a locked one.
  static MiniGame? autoGame(
    List<MiniGame> candidates,
    ChildProgress progress,
    Set<String> unlocked,
    Random random,
  ) {
    final free = [
      for (final g in candidates)
        if (MiniGameRegistry.isPlayable(g, unlocked)) g,
    ];
    if (free.isEmpty) return null;
    int played(MiniGame g) => progress.games[g.id]?.passed ?? 0;
    final least = free.map(played).reduce(min);
    final tied = [
      for (final g in free)
        if (played(g) == least) g,
    ];
    return tied[random.nextInt(tied.length)];
  }

  /// Builds the round for [node] with [game]: up to [roundSize] items of the rung the game can
  /// play (items not seen lately first) plus up to [revisionMax] due review items it can play.
  static TrailRound? round({
    required TrailNode node,
    required MiniGame game,
    required Iterable<PoolItem> open,
    required ChildProgress progress,
    required int today,
    required Random random,
    bool spaced = true,
  }) {
    final rung = [
      for (final p in open)
        if (p.skillKey == node.key && game.canPlay(p)) p,
    ];
    if (rung.isEmpty) return null;
    final picked = ItemSelector.select(
      open: rung,
      subject: node.skill.subject,
      year: node.skill.year,
      count: roundSize,
      random: random,
      recent: progress.recent,
    );
    final have = {for (final p in picked) p.id};
    final review = [
      for (final p in progress.reviewItems(open, today: today, spaced: spaced))
        if (!have.contains(p.id) &&
            p.subject == node.skill.subject &&
            p.year == node.skill.year &&
            game.canPlay(p))
          p,
    ].take(revisionMax);
    return TrailRound(
      skill: node.skill,
      game: game,
      items: [...picked, ...review],
    );
  }

  /// Auto: the rung and the game together. Null when nothing can be played.
  static TrailRound? auto({
    required List<TrailNode> nodes,
    required MiniGameRegistry registry,
    required Iterable<PoolItem> open,
    required ChildProgress progress,
    required MiniGameMode mode,
    required Set<String> unlocked,
    required int today,
    required Random random,
  }) {
    final node = Trail.autoRung(nodes);
    if (node == null) return null;
    return forRung(
      node: node,
      registry: registry,
      open: open,
      progress: progress,
      mode: mode,
      unlocked: unlocked,
      today: today,
      random: random,
    );
  }

  /// A round on [node] with a game chosen by Auto.
  static TrailRound? forRung({
    required TrailNode node,
    required MiniGameRegistry registry,
    required Iterable<PoolItem> open,
    required ChildProgress progress,
    required MiniGameMode mode,
    required Set<String> unlocked,
    required int today,
    required Random random,
  }) {
    final rungItems = [
      for (final p in open)
        if (p.skillKey == node.key) p,
    ];
    final games = gamesFor(
      registry: registry,
      rungItems: rungItems,
      year: node.skill.year,
      mode: mode,
      unlocked: unlocked,
    );
    final game = autoGame(games, progress, unlocked, random);
    if (game == null) return null;
    return round(
      node: node,
      game: game,
      open: open,
      progress: progress,
      today: today,
      random: random,
    );
  }

  /// "Pick a game": the rung the game serves best, the first unlocked rung that is not secure
  /// and has enough items the game can play. Null when it can serve none.
  static TrailNode? rungForGame(
    List<TrailNode> nodes,
    MiniGame game,
    Iterable<PoolItem> open,
  ) {
    final count = <String, int>{};
    for (final p in open) {
      final k = p.skillKey;
      if (k != null && game.canPlay(p)) count[k] = (count[k] ?? 0) + 1;
    }
    final need = game.minPool < minRoundItems ? game.minPool : minRoundItems;
    for (final n in nodes) {
      if (!n.isLocked &&
          (n.state == SkillState.unseen || n.state == SkillState.practising) &&
          (count[n.key] ?? 0) >= need) {
        return n;
      }
    }
    for (final n in nodes) {
      if (!n.isLocked && (count[n.key] ?? 0) >= need) return n;
    }
    return null;
  }

  /// The skip-ahead check items for [node]: `mcq` with 3 or more options (a real answer without
  /// a game), at least [SkillRules.checkItems] of them, else null (the check is not offered).
  static List<PoolItem>? checkItems(
    TrailNode node,
    Iterable<PoolItem> open,
    SkillRules rules,
    Random random,
  ) {
    final items = [
      for (final p in open)
        if (p.skillKey == node.key &&
            p.item.type == ItemType.mcq &&
            ((p.item.json['options'] as List?)?.length ?? 0) >= 3)
          p,
    ];
    if (items.length < rules.checkItems) return null;
    return SkipCheck.pick(items, rules, random);
  }
}
