/// Sort into bins rules: put each item into the right group. Pure Dart, random is injected.
library;

import 'dart:math';

import '../../../content/models.dart';

const String sortBinsId = 'sort_bins';

/// Younger: 2 big bins, no timer, no failing. Older: 3 bins and a gentle timer.
/// Hard: the older level with 4 bins and a harder setting (Craft Champion).
enum SortLevel {
  younger,
  older,
  hard;

  static SortLevel forYear(int year, {bool hard = false}) =>
      year <= 2 ? SortLevel.younger : (hard ? SortLevel.hard : SortLevel.older);

  int get maxBins => switch (this) {
    SortLevel.younger => 2,
    SortLevel.older => 3,
    SortLevel.hard => 4,
  };

  int get maxItems => switch (this) {
    SortLevel.younger => 6,
    SortLevel.older => 10,
    SortLevel.hard => 12,
  };

  /// Gentle time limit per item in seconds; null means no timer.
  int? get secondsPerItem => switch (this) {
    SortLevel.younger => null,
    SortLevel.older => 8,
    SortLevel.hard => 5,
  };

  /// Wrong drops allowed per item before the round does not pass (null: never fails).
  double? get missesPerItem => switch (this) {
    SortLevel.younger => null,
    SortLevel.older => 0.5,
    SortLevel.hard => 0.25,
  };
}

bool sortBinsPlays(ItemType t) => t == ItemType.category;

class SortEntry {
  const SortEntry(this.text, this.bin);
  final String text;

  /// Index into [SortRound.bins].
  final int bin;
}

/// One round on one `category` item.
class SortRound {
  SortRound._(this.level, this.bins, this.entries);

  factory SortRound.fromItem(ContentItem item, SortLevel level, Random random) {
    final cats = [for (final c in (item.json['categories'] as List)) '$c'];
    final raw = [
      for (final e in (item.json['items'] as List))
        ((e as Map)['text'].toString(), e['category'].toString()),
    ];
    final order = [...cats]..shuffle(random);
    final bins = order.take(level.maxBins).toList();
    final entries = <SortEntry>[
      for (final e in raw)
        if (bins.contains(e.$2)) SortEntry(e.$1, bins.indexOf(e.$2)),
    ]..shuffle(random);
    return SortRound._(level, bins, entries.take(level.maxItems).toList());
  }

  final SortLevel level;
  final List<String> bins;
  final List<SortEntry> entries;

  int _index = 0;
  int _misses = 0;

  int get index => _index;
  int get total => entries.length;
  int get misses => _misses;
  bool get complete => _index >= entries.length;
  SortEntry? get current => complete ? null : entries[_index];

  /// Drops the current item into [bin]. True when right; a wrong drop leaves the item to try again.
  bool drop(int bin) {
    final c = current;
    if (c == null) return false;
    if (c.bin == bin) {
      _index++;
      return true;
    }
    _misses++;
    return false;
  }

  int? get timeLimit {
    final s = level.secondsPerItem;
    return s == null ? null : s * total;
  }

  bool passed({int? elapsedSeconds}) {
    if (!complete) return false;
    final per = level.missesPerItem;
    if (per != null && _misses > per * total) return false;
    final limit = timeLimit;
    if (limit != null && elapsedSeconds != null && elapsedSeconds > limit) {
      return false;
    }
    return true;
  }
}
