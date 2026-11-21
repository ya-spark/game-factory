import 'dart:math';

import '../../game/tips.dart';

/// Deals tips from a shuffled bag (never the same tip twice in a row) and picks the tip of
/// the day from the date. Pure Dart.
class TipService {
  TipService({Random? random, List<String>? tips})
    : _random = random ?? Random(),
      tips = tips ?? gameTips;

  final Random _random;
  final List<String> tips;
  final List<String> _bag = [];
  String? _last;

  /// Next tip from the bag; the bag is reshuffled when empty.
  String next() {
    if (_bag.isEmpty) {
      _bag.addAll(tips);
      _bag.shuffle(_random);
      // The first tip of a new bag (dealt from the end) must differ from the last one.
      if (tips.length > 1 && _bag.last == _last) {
        final i = _random.nextInt(_bag.length - 1);
        final t = _bag[i];
        _bag[i] = _bag.last;
        _bag[_bag.length - 1] = t;
      }
    }
    return _last = _bag.removeLast();
  }

  /// The same tip all day, a different one each day.
  String tipOfTheDay(int dayIndex) => tips[dayIndex % tips.length];
}
