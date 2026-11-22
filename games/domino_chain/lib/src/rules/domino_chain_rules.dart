/// Domino chain rules (G-13): the levels, how a `series` item becomes a chain of dominoes, rounds
/// (stages) and the scores. Pure Dart: no Flutter, Flame or Android imports; random is injected.
library;

import 'dart:math';

import 'package:game_core/engine/engine.dart';

const String dominoChainId = 'domino_chain';

/// The name the child sees.
const String dominoChainTitle = 'Domino chain';

/// Most chains in one session (3 stages of 2).
const int maxChainsPerSession = 6;

/// Chains in one stage (a round).
const int chainsPerStage = 2;

/// A step text longer than this makes the whole chain `long` (wide dominoes).
const int shortStepMax = 24;

/// Younger: up to 4 dominoes, tap to place is the main way, 2 hints, no timer. Older: up to 7
/// dominoes, 1 hint and a gentle timer. Hard (internal flag only, no text names it): 7 dominoes,
/// a tighter timer, no hints.
enum SeriesLevel {
  younger,
  older,
  hard;

  static SeriesLevel forYear(int year, {bool hard = false}) => year <= 2
      ? SeriesLevel.younger
      : (hard ? SeriesLevel.hard : SeriesLevel.older);

  /// The level for a session: years 0 to 2 are younger.
  static SeriesLevel forSession(QuizSession s, {bool hard = false}) =>
      forYear(s.items.isEmpty ? 3 : s.items.first.year, hard: hard);

  int get maxDominoes => switch (this) {
    SeriesLevel.younger => 4,
    SeriesLevel.older => 7,
    SeriesLevel.hard => 7,
  };

  /// Gentle time per domino in seconds for the whole chain; null means no timer.
  int? get secondsPerDomino => switch (this) {
    SeriesLevel.younger => null,
    SeriesLevel.older => 8,
    SeriesLevel.hard => 5,
  };

  /// Hints per chain (study mode gives 2 at every level).
  int get hints => switch (this) {
    SeriesLevel.younger => 2,
    SeriesLevel.older => 1,
    SeriesLevel.hard => 0,
  };

  bool get isOlder => this != SeriesLevel.younger;

  /// The time for a chain of [n] dominoes: [secondsPerDomino] each, at most 60 s; null: no timer.
  int? timeLimit(int n) {
    final s = secondsPerDomino;
    return s == null ? null : min(60, s * n);
  }
}

/// How a level plays once the mode is known.
class DominoSettings {
  const DominoSettings({
    required this.level,
    required this.study,
    required this.hints,
    required this.secondsPerDomino,
  });

  final SeriesLevel level;
  final bool study;

  /// Hints per chain.
  final int hints;

  /// Null: no timer (younger levels and study mode).
  final int? secondsPerDomino;

  factory DominoSettings.forLevel(SeriesLevel level, {bool study = false}) =>
      DominoSettings(
        level: level,
        study: study,
        hints: study ? 2 : level.hints,
        secondsPerDomino: study ? null : level.secondsPerDomino,
      );

  int? timeLimit(int n) {
    final s = secondsPerDomino;
    return s == null ? null : min(60, s * n);
  }
}

/// The item types the game plays.
bool dominoChainPlays(ItemType t) => t == ItemType.series;

/// Whether [item] can be a chain: a `series` item with at least two steps (the content has 3 to 7).
bool dominoPlayable(ContentItem item) {
  final steps = item.json['steps'];
  return item.type == ItemType.series && steps is List && steps.length >= 2;
}

/// `short` dominoes are tall (every step up to 24 characters); `long` ones are wide.
enum DominoSize { short, long }

/// One chain: one `series` item as dominoes. [steps] are in the right order, [tiles] are the
/// dominoes as they lie in the tray (shuffled, never already in order).
class DominoChain {
  DominoChain._(this.level, this.steps, this.tiles, this.size);

  /// Builds the chain of [item]. A series longer than the level's cap plays a window of
  /// consecutive steps. The same seed gives the same chain.
  factory DominoChain.fromItem(
    ContentItem item,
    SeriesLevel level,
    Random random,
  ) {
    final all = [for (final s in (item.json['steps'] as List)) '$s'];
    final size = min(all.length, level.maxDominoes);
    final start = all.length == size
        ? 0
        : random.nextInt(all.length - size + 1);
    final steps = all.sublist(start, start + size);
    var tiles = [...steps]..shuffle(random);
    // Never hand over an already ordered row (unless every domino reads the same).
    var tries = 0;
    while (sameOrder(tiles, steps) && steps.toSet().length > 1) {
      tiles = [...steps]..shuffle(random);
      if (++tries > 10) {
        tiles = [...steps.sublist(1), steps.first];
        break;
      }
    }
    return DominoChain._(
      level,
      steps,
      tiles,
      steps.any((s) => s.length > shortStepMax)
          ? DominoSize.long
          : DominoSize.short,
    );
  }

  /// A chain from known steps and tray order (tests, tools).
  factory DominoChain.of(
    List<String> steps,
    List<String> tiles, {
    SeriesLevel level = SeriesLevel.younger,
  }) => DominoChain._(
    level,
    steps,
    tiles,
    steps.any((s) => s.length > shortStepMax)
        ? DominoSize.long
        : DominoSize.short,
  );

  static bool sameOrder(List<String> a, List<String> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  final SeriesLevel level;

  /// The right order.
  final List<String> steps;

  /// The dominoes in the tray, shuffled.
  final List<String> tiles;
  final DominoSize size;

  int get total => steps.length;
}

/// How many chains a session plays: one per open item, at most [maxChainsPerSession].
int dominoChainCount(int poolSize) =>
    poolSize <= 0 ? 0 : min(maxChainsPerSession, poolSize);

/// The three backdrops; a stage uses one: playroom floor, toy shelf, window sill.
enum DominoBackdrop { floor, shelf, sill }

/// Where chain [chain] (from 0) sits in a session of [total] chains.
class DominoStage {
  const DominoStage({
    required this.stage,
    required this.indexInStage,
    required this.chains,
    required this.endsStage,
    required this.backdrop,
  });

  /// Stage number from 0.
  final int stage;
  final int indexInStage;

  /// Chains in this stage (the last stage may have 1).
  final int chains;

  /// True on the last chain of a stage: the flag shows the stage stars.
  final bool endsStage;
  final DominoBackdrop backdrop;
}

DominoStage dominoStageFor(int chain, int total) {
  final stage = chain ~/ chainsPerStage;
  final first = stage * chainsPerStage;
  final chains = (total - first).clamp(1, chainsPerStage);
  final i = chain % chainsPerStage;
  return DominoStage(
    stage: stage,
    indexInStage: i,
    chains: chains,
    endsStage: i == chains - 1 || chain == total - 1,
    backdrop: DominoBackdrop.values[stage % DominoBackdrop.values.length],
  );
}

/// Stage stars at the flag: all chains first try = 3, at least half = 2, else 1 (finished).
int dominoStageStars({required int firstTry, required int chains}) {
  if (chains <= 0) return 0;
  if (firstTry >= chains) return 3;
  if (firstTry * 2 >= chains) return 2;
  return 1;
}

/// Stars shown on the flag of one chain: first try 3, second try 2, later 1.
int dominoChainStars(int attempts) =>
    attempts <= 1 ? 3 : (attempts == 2 ? 2 : 1);

/// The game score of a solved chain: 10 for the first try (older levels add 2 per streak step,
/// to 5 steps), 6 for the second try, 3 after that. A chain nobody solved (time up) scores 0.
int dominoChainScore({
  required int attempts,
  required int streak,
  required bool older,
}) {
  if (attempts <= 1) return scoreForAnswer(streak: streak, older: older);
  return attempts == 2 ? 6 : 3;
}

/// Whether the chain counts as correct for the skill system: the first Go was right, no hint was
/// used and the time did not run out. Study mode always counts once the chain is solved.
bool dominoChainCorrect({
  required int attempts,
  required bool hinted,
  required bool timedOut,
  required bool study,
}) => study || (attempts <= 1 && !hinted && !timedOut);

/// True every 10 seconds: the live region reads the time left.
bool announceTimeLeft(int secondsLeft) =>
    secondsLeft > 0 && secondsLeft % 10 == 0;
