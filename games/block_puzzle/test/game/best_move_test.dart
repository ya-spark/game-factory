import 'package:game_block_puzzle/src/game/rules/best_move.dart';
import 'package:game_block_puzzle/src/game/rules/board.dart';
import 'package:game_block_puzzle/src/game/rules/piece.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Row 7 is full except columns 0 and 1.
  Board almostRow() => Board.fromRows([
    '........',
    '........',
    '........',
    '........',
    '........',
    '........',
    '........',
    '..######',
  ]);

  test('linesCompletedBy reports the row a drop would clear', () {
    final bar2 = PieceCatalog.byId('bar2_0');
    final lines = almostRow().linesCompletedBy(bar2, 7, 0);
    expect(lines.rows, [7]);
    expect(lines.cols, isEmpty);
    expect(almostRow().linesCompletedBy(bar2, 5, 0).rows, isEmpty);
  });

  test('the solver clears the line with the bar and uses every piece', () {
    final best = BestMoveSolver.solve(almostRow(), [
      PieceCatalog.byId('dot_0'),
      PieceCatalog.byId('bar2_0'),
    ])!;
    expect(best.lines, 1);
    expect(best.steps.length, 2);
  });

  test('null when nothing fits', () {
    final full = Board.fromRows(List.filled(8, '########'));
    expect(BestMoveSolver.solve(full, [PieceCatalog.byId('dot_0')]), isNull);
  });
}
