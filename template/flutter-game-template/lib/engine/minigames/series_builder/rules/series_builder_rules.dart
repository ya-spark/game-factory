/// Series builder rules: put the steps of a `series` item in order. Pure Dart, random is injected.
library;

import 'dart:math';

import '../../../content/models.dart';

const String seriesBuilderId = 'series_builder';

/// Younger: up to 5 tiles, no timer, no failing; a wrong tile is greyed out and the child tries
/// again. Older: up to 8 tiles and a gentle timer. Hard: up to 10 tiles, tighter limits (Champion).
enum SeriesLevel {
  younger,
  older,
  hard;

  static SeriesLevel forYear(int year, {bool hard = false}) => year <= 2
      ? SeriesLevel.younger
      : (hard ? SeriesLevel.hard : SeriesLevel.older);

  int get maxTiles => switch (this) {
    SeriesLevel.younger => 5,
    SeriesLevel.older => 8,
    SeriesLevel.hard => 10,
  };

  /// Gentle time limit per tile in seconds; null means no timer.
  int? get secondsPerTile => switch (this) {
    SeriesLevel.younger => null,
    SeriesLevel.older => 6,
    SeriesLevel.hard => 4,
  };

  /// Wrong taps allowed per tile before the round does not pass (null: never fails).
  double? get missesPerTile => switch (this) {
    SeriesLevel.younger => null,
    SeriesLevel.older => 0.5,
    SeriesLevel.hard => 0.25,
  };
}

bool seriesBuilderPlays(ItemType t) => t == ItemType.series;

/// One round on one `series` item. The tiles are shuffled; the child taps them in order.
class SeriesRound {
  SeriesRound._(this.level, this.steps, this.tiles);

  factory SeriesRound.fromItem(
    ContentItem item,
    SeriesLevel level,
    Random random,
  ) {
    final all = [for (final s in (item.json['steps'] as List)) '$s'];
    final size = min(all.length, level.maxTiles);
    final start = all.length == size
        ? 0
        : random.nextInt(all.length - size + 1);
    final steps = all.sublist(start, start + size);
    var tiles = [...steps]..shuffle(random);
    // Never hand over an already ordered row (unless every tile reads the same).
    var tries = 0;
    while (_sameOrder(tiles, steps) && steps.toSet().length > 1) {
      tiles = [...steps]..shuffle(random);
      if (++tries > 10) {
        tiles = [...steps.sublist(1), steps.first];
        break;
      }
    }
    return SeriesRound._(level, steps, tiles);
  }

  static bool _sameOrder(List<String> a, List<String> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  final SeriesLevel level;

  /// The right order.
  final List<String> steps;

  /// The tiles as shown, shuffled.
  final List<String> tiles;

  final Set<int> _used = {};
  final Set<int> _greyed = {};
  int _placed = 0;
  int _misses = 0;

  int get placed => _placed;
  int get total => steps.length;
  int get misses => _misses;
  bool get complete => _placed >= steps.length;

  /// The text the next tile must have, or null when done.
  String? get expected => complete ? null : steps[_placed];

  /// The tiles put in place so far, in order.
  List<String> get placedTexts => steps.sublist(0, _placed);

  bool isUsed(int tile) => _used.contains(tile);

  /// Younger level only: a tile that was tried in the wrong place is greyed until the next one fits.
  bool isGreyed(int tile) => _greyed.contains(tile);

  /// Taps [tile]. True when it is the next step. A wrong tile never ends the round.
  bool place(int tile) {
    if (complete || tile < 0 || tile >= tiles.length) return false;
    if (_used.contains(tile) || _greyed.contains(tile)) return false;
    if (tiles[tile] == steps[_placed]) {
      _used.add(tile);
      _placed++;
      _greyed.clear();
      return true;
    }
    _misses++;
    if (level == SeriesLevel.younger) _greyed.add(tile);
    return false;
  }

  int? get timeLimit {
    final s = level.secondsPerTile;
    return s == null ? null : s * total;
  }

  bool passed({int? elapsedSeconds}) {
    if (!complete) return false;
    final per = level.missesPerTile;
    if (per != null && _misses > per * total) return false;
    final limit = timeLimit;
    if (limit != null && elapsedSeconds != null && elapsedSeconds > limit) {
      return false;
    }
    return true;
  }
}
