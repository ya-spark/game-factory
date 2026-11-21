import 'package:flutter/widgets.dart';

/// Sudoku's own test IDs (the shared ones are `MindIds` and `GameIds` in game_core).
abstract final class SudokuIds {
  static Key sudokuCell(int i) => Key('sudoku.cell.$i');
  static Key sudokuDigit(int d) => Key('sudoku.digit.$d');
}
