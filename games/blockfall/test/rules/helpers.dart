import 'dart:math';

import 'package:game_blockfall/src/game/rules/bag.dart';
import 'package:game_blockfall/src/game/rules/blockfall_game.dart';
import 'package:game_blockfall/src/game/rules/events.dart';
import 'package:game_blockfall/src/game/rules/piece_type.dart';
import 'package:game_blockfall/src/game/rules/powerups.dart';
import 'package:game_blockfall/src/game/rules/well.dart';

/// A game with a fixed repeating piece sequence, no prisms (unless asked) and an optional
/// preloaded well (rows aligned to the bottom).
BlockfallGame mk({
  List<String> rows = const [],
  List<PieceType> seq = const [PieceType.bar],
  int prismInterval = 0,
  int boomInterval = 0,
  int goldInterval = 0,
  Map<PowerUpType, int>? stock,
  Well? well,
}) {
  return BlockfallGame(
    random: Random(1),
    bag: PieceBag.sequence(seq),
    well: well ?? Well.fromRows(rows),
    prismInterval: prismInterval,
    boomInterval: boomInterval,
    goldInterval: goldInterval,
    stock: stock,
  );
}

/// Rotates the bar to vertical (box column 2) and moves it to well column [col].
void verticalBarAt(BlockfallGame g, int col) {
  mustSucceed(g.rotate());
  while (g.currentPiece!.cells.first.col > col) {
    g.moveLeft();
  }
  while (g.currentPiece!.cells.first.col < col) {
    g.moveRight();
  }
}

void mustSucceed(bool ok) {
  if (!ok) throw StateError('expected the input to succeed');
}

List<LinesCleared> clears(BlockfallGame g) =>
    g.drainEvents().whereType<LinesCleared>().toList();

/// Ground row used by tests: ".111111111" (gap in column 0).
const String gap0 = '.111111111';
const String gap3to6 = '111....111';
const String gap4to5 = '1111..1111';
