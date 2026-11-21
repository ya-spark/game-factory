import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:game_block_puzzle/src/core/save/save_data.dart';
import 'package:game_block_puzzle/src/game/rules/game_state.dart';
import 'package:game_block_puzzle/src/game/rules/piece_generator.dart';

void main() {
  GameState play(int moves) {
    final g = GameState.newGame(generator: PieceGenerator(Random(7)));
    for (var i = 0; i < moves && !g.isGameOver; i++) {
      var done = false;
      for (var slot = 0; slot < 3 && !done; slot++) {
        for (var r = 0; r < 8 && !done; r++) {
          for (var c = 0; c < 8 && !done; c++) {
            if (g.canPlace(slot, r, c)) done = g.place(slot, r, c) != null;
          }
        }
      }
    }
    return g;
  }

  test('a running game survives a JSON round trip', () {
    final g = play(6);
    expect(g.isGameOver, isFalse);
    final json = jsonDecode(jsonEncode(g.toJson())) as Map<String, Object?>;
    final back = GameState.fromJson(json, bestScore: g.bestScore)!;
    expect(back.score, g.score);
    expect(back.board.cells, g.board.cells);
    expect(back.board.kinds, g.board.kinds);
    expect(back.linesClearedTotal, g.linesClearedTotal);
    expect(back.piecesPlaced, g.piecesPlaced);
    expect([for (final p in back.tray) p?.id], [for (final p in g.tray) p?.id]);
    expect(
      [for (final p in back.tray) p?.colorIndex],
      [for (final p in g.tray) p?.colorIndex],
    );
  });

  test('a corrupt save gives null instead of throwing', () {
    expect(GameState.fromJson({'board': 3}, bestScore: 0), isNull);
  });

  test('SaveData keeps the game and can clear it', () {
    final g = play(3);
    final d = const SaveData().copyWith(game: g.toJson());
    final back = SaveData.fromJson(
      jsonDecode(jsonEncode(d.toJson())) as Map<String, Object?>,
    );
    expect(back.game, isNotNull);
    expect(back.copyWith(clearGame: true).game, isNull);
  });
}
