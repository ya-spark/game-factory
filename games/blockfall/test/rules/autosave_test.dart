import 'dart:convert';

import 'package:game_blockfall/src/game/rules/blockfall_game.dart';
import 'package:game_blockfall/src/game/rules/powerups.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final stock = {for (final t in PowerUpType.values) t: 1};

  test('a running game survives a JSON round trip', () {
    final g = BlockfallGame.seeded(3);
    for (var i = 0; i < 4; i++) {
      g.hardDrop();
      g.tick(0.05);
    }
    expect(g.isGameOver, isFalse);
    final json = jsonDecode(jsonEncode(g.toJson())) as Map<String, Object?>;
    final back = BlockfallGame.restore(json, stock: stock)!;
    expect(back.isGameOver, isFalse);
    expect(back.score, g.score);
    expect(back.lines, g.lines);
    expect(back.piecesPlaced, g.piecesPlaced);
    for (var r = 0; r < 22; r++) {
      for (var c = 0; c < 10; c++) {
        expect(back.well.colorAt(r, c), g.well.colorAt(r, c));
        expect(back.well.kindAt(r, c), g.well.kindAt(r, c));
      }
    }
    expect(back.currentPiece!.spec!.type, g.currentPiece!.spec!.type);
    expect(back.currentPiece!.row, g.currentPiece!.row);
    expect(
      [for (final s in back.next) s.type],
      [for (final s in g.next) s.type],
    );
    expect(back.holdPiece?.type, g.holdPiece?.type);
  });

  test('a corrupt save gives null instead of throwing', () {
    expect(BlockfallGame.restore({'well': 1}, stock: stock), isNull);
  });
}
