/// Question format limits (envelope) and the derived size class. Pure Dart.
///
/// The envelope is the shape every item of a format may be relied on to have, so games can
/// play any item without checking. The validator enforces it as errors. The numbers are in
/// `docs/FORMAT-CONSTRAINTS.md` in the studio repo; this file is the one place they live.
library;

import 'models.dart';

/// Limits that apply to every format.
abstract final class CommonLimits {
  static const int promptMax = 300;
  static const int explanationMax = 250;
  static const int imageAltMax = 120;
}

/// Limits of `mcq`: true or false is the 2-option case, and exactly one option is correct.
abstract final class McqLimits {
  static const int optionsMin = 2;
  static const int optionsMax = 4;
  static const int optionMax = 150;
}

abstract final class SeriesLimits {
  static const int stepsMin = 3;
  static const int stepsMax = 8;
  static const int stepMax = 80;
}

abstract final class PairsLimits {
  static const int pairsMin = 3;
  static const int pairsMax = 6;
  static const int sideMax = 60;
}

abstract final class CategoryLimits {
  static const int categoriesMin = 2;
  static const int categoriesMax = 4;
  static const int categoryNameMax = 30;
  static const int itemsMin = 3;
  static const int itemsMax = 12;
  static const int itemMax = 80;
}

abstract final class WordLimits {
  static const int lettersMin = 3;
  static const int lettersMax = 14;
  static const int hintMax = 100;
  static const int poolMax = 20;
}

abstract final class NumericLimits {
  static const int digitsMax = 8;
  static const int decimalsMax = 3;
  static const int unitMax = 20;
}

abstract final class ClozeLimits {
  static const int gapsMin = 1;
  static const int gapsMax = 3;
  static const int formsMin = 1;
  static const int formsMax = 6;
  static const int formMax = 20;
  static const int textMax = 200;
}

/// Thresholds of the `short` size class, the same in every app.
abstract final class ShortLimits {
  static const int prompt = 150;
  static const int mcqOption = 30;
  static const int tile = 24;
}

/// How much text an item carries. Derived from the item, never authored and never stored in
/// packs. Action games take `short` only; card-style games take both.
enum SizeClass { short, long }

/// Characters in [s] (code points, so a symbol counts once).
int textLength(String s) => s.runes.length;

extension ItemSize on ContentItem {
  /// `short` when the prompt is at most [ShortLimits.prompt] characters, every `mcq` option at
  /// most [ShortLimits.mcqOption] and every tile (series step, pair side, category item) at
  /// most [ShortLimits.tile]; otherwise `long`.
  SizeClass get sizeClass => sizeClassOfJson(json);
}

/// [sizeClassOfJson] works on the item's JSON, so the validator and tools can use it too.
SizeClass sizeClassOfJson(Map<String, dynamic> j) {
  bool over(Object? v, int max) => v is String && textLength(v) > max;
  bool anyOver(Object? list, int max) =>
      list is List && list.any((e) => over(e, max));

  if (over(j['prompt'], ShortLimits.prompt) ||
      over(j['text'], ShortLimits.prompt) ||
      over(j['hint'], ShortLimits.prompt)) {
    return SizeClass.long;
  }
  switch (ItemType.parse(j['type'])) {
    case ItemType.mcq:
      if (anyOver(j['options'], ShortLimits.mcqOption)) return SizeClass.long;
    case ItemType.series:
      if (anyOver(j['steps'], ShortLimits.tile)) return SizeClass.long;
    case ItemType.pairs:
      final pairs = j['pairs'];
      if (pairs is List &&
          pairs.any(
            (p) =>
                p is Map &&
                (over(p['left'], ShortLimits.tile) ||
                    over(p['right'], ShortLimits.tile)),
          )) {
        return SizeClass.long;
      }
    case ItemType.category:
      final items = j['items'];
      if (items is List &&
          items.any((p) => p is Map && over(p['text'], ShortLimits.tile))) {
        return SizeClass.long;
      }
    case ItemType.word:
    case ItemType.numeric:
    case ItemType.cloze:
    case null:
      break;
  }
  return SizeClass.short;
}
