import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_block_puzzle/src/game/flame/block_puzzle_game.dart';
import 'package:game_block_puzzle/src/game/rules/board.dart';
import 'package:game_block_puzzle/src/game/rules/game_state.dart';
import 'package:game_block_puzzle/src/game/rules/piece.dart';
import 'package:game_block_puzzle/src/game/rules/piece_generator.dart';

/// Keyboard play (docs/SPEC.md, Keyboard): pick a tray piece, move it with the arrows, place it.
void main() {
  BlockPuzzleGame game() => BlockPuzzleGame(
    initialState: GameState(
      generator: PieceGenerator(Random(1), 0),
      tray: [PieceCatalog.dot, PieceCatalog.dot, PieceCatalog.dot],
    ),
  )..view = PuzzleView();

  test('the cursor moves and stays on the board', () {
    final g = game();
    g.kbMove(-1, 0);
    g.kbMove(-1, 0);
    g.kbMove(-1, 0);
    g.kbMove(-1, 0);
    g.kbMove(0, -1);
    expect(g.kbCell, (0, 2));
    for (var i = 0; i < 20; i++) {
      g.kbMove(1, 1);
    }
    expect(g.kbCell, (7, 7));
    expect(g.kbActive, isTrue);
  });

  test('a tray piece is chosen by number and placed with Enter', () {
    final g = game();
    expect(g.kbSelect(1), isTrue);
    expect(g.kbSlot, 1);
    final before = g.state.piecesPlaced;
    expect(g.kbPlace(), isTrue);
    expect(g.state.piecesPlaced, before + 1);
    expect(g.state.tray[1], isNull);
    expect(g.kbSelect(1), isFalse); // that slot is empty now
    expect(g.state.board.isFilled(g.kbCell.$1, g.kbCell.$2), isTrue);
    // The same cell is taken now: placing again there is refused.
    g.kbSelect(0);
    expect(g.kbPlace(), isFalse);
  });

  test('a piece that does not fit is not placed', () {
    final g = BlockPuzzleGame(
      initialState: GameState(
        generator: PieceGenerator(Random(1), 0),
        board: Board.fromRows([
          '########',
          '########',
          '########',
          '########',
          '########',
          '########',
          '########',
          '.......#',
        ]),
        tray: [PieceCatalog.dot, PieceCatalog.dot, PieceCatalog.dot],
      ),
    )..view = PuzzleView();
    g.kbCell = (0, 0);
    expect(g.kbPlace(), isFalse);
    expect(g.state.piecesPlaced, 0);
  });
}
