import 'dart:math';

import 'piece_type.dart';

/// 7-bag randomizer: every bag is a shuffled permutation of the 7 piece types.
/// All randomness comes from the injected [Random], so a seed gives a fixed order.
class PieceBag {
  PieceBag(Random random) : _random = random, _fixed = null;

  /// Test helper: repeats [sequence] forever instead of shuffling.
  PieceBag.sequence(List<PieceType> sequence)
    : _random = null,
      _fixed = List.of(sequence);

  final Random? _random;
  final List<PieceType>? _fixed;
  int _fixedIndex = 0;

  /// Next group of pieces to append to the queue (a whole bag).
  List<PieceType> nextBag() {
    final fixed = _fixed;
    if (fixed != null) {
      final out = <PieceType>[];
      for (var i = 0; i < PieceType.values.length; i++) {
        out.add(fixed[_fixedIndex++ % fixed.length]);
      }
      return out;
    }
    return List.of(PieceType.values)..shuffle(_random);
  }
}
