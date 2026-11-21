/// Memory match rules: flip cards to find pairs. Pure Dart, the random source is injected.
library;

import 'dart:math';

import '../../../content/models.dart';

const String memoryMatchId = 'memory_match';

/// Younger: pictures or words, no timer, no failing. Older: a gentle timer.
/// Hard: the older level with a harder setting (Craft Champion).
enum MatchLevel {
  younger,
  older,
  hard;

  /// Years 0 to 2 are younger, the rest older (the same split as the interface levels).
  static MatchLevel forYear(int year, {bool hard = false}) => year <= 2
      ? MatchLevel.younger
      : (hard ? MatchLevel.hard : MatchLevel.older);

  /// The most pairs on one board.
  int get maxPairs => switch (this) {
    MatchLevel.younger => 3,
    MatchLevel.older => 6,
    MatchLevel.hard => 8,
  };

  /// A gentle time limit per pair in seconds; null means no timer.
  int? get secondsPerPair => switch (this) {
    MatchLevel.younger => null,
    MatchLevel.older => 20,
    MatchLevel.hard => 12,
  };

  /// Wrong flips allowed per pair before the round does not count as passed (null: never fails).
  double? get missesPerPair => switch (this) {
    MatchLevel.younger => null,
    MatchLevel.older => 2,
    MatchLevel.hard => 1,
  };
}

/// One card. Cards of a pair share [pairIndex]; [text] is what the card shows.
class MatchCard {
  const MatchCard({
    required this.pairIndex,
    required this.text,
    required this.isLeft,
  });
  final int pairIndex;
  final String text;
  final bool isLeft;
}

enum FlipOutcome { ignored, firstFlip, match, mismatch }

/// Items Memory match can play.
bool memoryMatchPlays(ItemType t) => t == ItemType.pairs;

/// The pairs of a `pairs` item as (left, right).
List<(String, String)> pairsOf(ContentItem item) => [
  for (final p in (item.json['pairs'] as List))
    ((p as Map)['left'].toString(), p['right'].toString()),
];

/// One board. Flip two cards; a mismatch stays face up until [hideMismatch] is called, so
/// the view can show it for a moment.
class MemoryMatchBoard {
  MemoryMatchBoard._(this.level, this.cards, this.pairCount);

  /// Builds a board from [item]: up to `level.maxPairs` pairs, shuffled.
  factory MemoryMatchBoard.fromItem(
    ContentItem item,
    MatchLevel level,
    Random random,
  ) {
    final all = pairsOf(item)..shuffle(random);
    final chosen = all.take(level.maxPairs).toList();
    final cards = <MatchCard>[
      for (var i = 0; i < chosen.length; i++) ...[
        MatchCard(pairIndex: i, text: chosen[i].$1, isLeft: true),
        MatchCard(pairIndex: i, text: chosen[i].$2, isLeft: false),
      ],
    ]..shuffle(random);
    return MemoryMatchBoard._(level, cards, chosen.length);
  }

  final MatchLevel level;
  final List<MatchCard> cards;
  final int pairCount;

  final Set<int> _matched = {};
  final List<int> _open = [];
  int _misses = 0;
  int _moves = 0;

  /// Columns that suit the number of cards.
  int get columns => cards.length <= 6 ? 2 : (cards.length <= 12 ? 3 : 4);

  Set<int> get matched => Set.unmodifiable(_matched);
  List<int> get faceUp => List.unmodifiable(_open);
  int get misses => _misses;
  int get moves => _moves;
  bool get complete => _matched.length == cards.length;
  bool get waitingToHide => _open.length == 2;

  bool isFaceUp(int i) => _matched.contains(i) || _open.contains(i);

  FlipOutcome flip(int i) {
    if (i < 0 || i >= cards.length) return FlipOutcome.ignored;
    if (_matched.contains(i) || _open.contains(i) || _open.length >= 2) {
      return FlipOutcome.ignored;
    }
    _open.add(i);
    if (_open.length == 1) return FlipOutcome.firstFlip;
    _moves++;
    final a = cards[_open[0]], b = cards[_open[1]];
    if (a.pairIndex == b.pairIndex) {
      _matched.addAll(_open);
      _open.clear();
      return FlipOutcome.match;
    }
    _misses++;
    return FlipOutcome.mismatch;
  }

  /// Turns a mismatched pair face down again.
  void hideMismatch() {
    if (_open.length == 2) _open.clear();
  }

  /// The time limit for this board in seconds, or null.
  int? get timeLimit {
    final s = level.secondsPerPair;
    return s == null ? null : s * pairCount;
  }

  /// Whether the round counts as passed. Younger never fails. Older and hard fail when
  /// there are too many wrong flips or the gentle time limit ran out.
  bool passed({int? elapsedSeconds}) {
    if (!complete) return false;
    final perPair = level.missesPerPair;
    if (perPair != null && _misses > perPair * pairCount) return false;
    final limit = timeLimit;
    if (limit != null && elapsedSeconds != null && elapsedSeconds > limit) {
      return false;
    }
    return true;
  }
}
