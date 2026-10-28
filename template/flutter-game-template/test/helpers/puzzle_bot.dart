import 'package:flame/game.dart';
import 'package:flutter_game_template/game/flame/block_puzzle_game.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drives the block puzzle through real pointer gestures (used by widget and integration tests).
class PuzzleBot {
  PuzzleBot(this.tester);
  final WidgetTester tester;

  BlockPuzzleGame get game => tester
      .widget<GameWidget<BlockPuzzleGame>>(find.byKey(TestIds.gameWidget))
      .game!;

  Future<void> waitForGame() async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (game.isLoaded && game.size.x > 10) return;
    }
    throw StateError('Game did not load');
  }

  /// First legal (slot, row, col) in reading order, or null.
  (int, int, int)? firstLegalMove() {
    final s = game.state;
    for (var slot = 0; slot < 3; slot++) {
      for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
          if (s.canPlace(slot, r, c)) return (slot, r, c);
        }
      }
    }
    return null;
  }

  /// Drags a tray piece onto the board. Returns true if the score/board changed.
  Future<bool> drag(int slot, int row, int col) async {
    final piece = game.state.tray[slot]!;
    final origin = tester.getTopLeft(find.byKey(TestIds.gameWidget));
    final layout = game.layout;
    final (sx, sy) = layout.trayCenter(slot);
    final (fx, fy) = layout.fingerFor(piece.height, piece.width, row, col);
    final before = game.state.piecesPlaced;
    await tester.dragFrom(origin + Offset(sx, sy), Offset(fx - sx, fy - sy));
    await tester.pump(const Duration(milliseconds: 50));
    return game.state.piecesPlaced == before + 1;
  }

  /// Plays up to [moves] legal moves; returns how many were made.
  Future<int> playMoves(int moves) async {
    var made = 0;
    for (var i = 0; i < moves; i++) {
      final m = firstLegalMove();
      if (m == null || game.state.isGameOver) break;
      if (await drag(m.$1, m.$2, m.$3)) made++;
    }
    return made;
  }
}
