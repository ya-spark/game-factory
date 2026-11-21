import 'dart:math';

import 'package:game_block_puzzle/src/game/rules/game_state.dart';
import 'package:game_block_puzzle/src/game/rules/piece_generator.dart';
import 'package:game_block_puzzle/src/game/rules/start_board.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'first tray: 2+ Z/J, all 4-cell, none more than twice, all placeable',
    () {
      for (var seed = 0; seed < 100; seed++) {
        final s = StartBoard.generate(Random(seed));
        expect(s.tray.length, 3, reason: 'seed $seed');
        expect(s.tray.every((p) => p.size == 4), isTrue, reason: 'seed $seed');
        final zj = s.tray
            .where((p) => p.id.startsWith('z4') || p.id.startsWith('j4'))
            .length;
        expect(zj, greaterThanOrEqualTo(2), reason: 'seed $seed');
        for (final p in s.tray) {
          expect(
            s.tray.where((q) => q.id == p.id).length,
            lessThanOrEqualTo(2),
          );
          expect(s.board.canPlaceAnywhere(p), isTrue, reason: 'seed $seed');
        }
      }
    },
  );

  test('later trays are unchanged: still dealt by the generator and fit', () {
    for (var seed = 0; seed < 20; seed++) {
      final gen = PieceGenerator(Random(seed));
      final g = GameState.newGame(generator: gen);
      final next = gen.dealTray(g.board);
      expect(next.length, 3);
      expect(next.any((p) => g.board.canPlaceAnywhere(p)), isTrue);
    }
  });
}
