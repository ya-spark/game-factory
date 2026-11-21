import 'rules/sudoku_rules.dart';

/// The daily puzzle's tier -> level tables of this game (the hub's DailyPuzzle aliases them).
/// Each game's own existing levels, by tier 0..3.
const List<SudokuLevel> sudokuDailyLevels = [
  SudokuLevel.easy,
  SudokuLevel.medium,
  SudokuLevel.hard,
  SudokuLevel.expert,
];
