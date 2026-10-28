import 'dart:math';

/// Screen geometry for the puzzle view, in plain doubles so it is testable without Flutter.
class PuzzleLayout {
  PuzzleLayout(
    this.width,
    this.height, {
    this.gridSize = 8,
    this.traySlots = 3,
  }) {
    final margin = width * 0.04;
    cellSize = (width - margin * 2) / gridSize;
    boardLeft = margin;
    boardTop = min(height * 0.06, 60);
    final boardBottom = boardTop + cellSize * gridSize;
    // Tray slots share the area under the board.
    trayTop = boardBottom + cellSize * 0.8;
    trayHeight = max(cellSize * 3.2, height - trayTop - margin);
    slotWidth = (width - margin * 2) / traySlots;
    // Pieces in the tray are drawn smaller than board cells.
    trayCellSize = min(cellSize * 0.62, slotWidth / 5.5);
  }

  final double width;
  final double height;
  final int gridSize;
  final int traySlots;

  late final double cellSize;
  late final double boardLeft;
  late final double boardTop;
  late final double trayTop;
  late final double trayHeight;
  late final double slotWidth;
  late final double trayCellSize;

  double get boardSizePx => cellSize * gridSize;

  /// Center of a tray slot.
  (double, double) trayCenter(int slot) =>
      (boardLeft + slotWidth * (slot + 0.5), trayTop + trayHeight / 2);

  /// Which tray slot a point is in, or null.
  int? traySlotAt(double x, double y) {
    if (y < trayTop || y > trayTop + trayHeight) return null;
    final i = ((x - boardLeft) / slotWidth).floor();
    return (i >= 0 && i < traySlots) ? i : null;
  }

  /// Board cell (row, col) under a point, or null when outside the board.
  (int, int)? cellAt(double x, double y) {
    final c = ((x - boardLeft) / cellSize).floor();
    final r = ((y - boardTop) / cellSize).floor();
    if (r < 0 || c < 0 || r >= gridSize || c >= gridSize) return null;
    return (r, c);
  }

  /// Center of a board cell.
  (double, double) cellCenter(int row, int col) =>
      (boardLeft + cellSize * (col + 0.5), boardTop + cellSize * (row + 0.5));

  /// While dragging, the piece floats this far above the finger so it stays visible.
  double get dragLift => cellSize * 1.6;

  /// Finger position that makes a piece of [pieceRows]x[pieceCols] snap with its top-left on
  /// board cell [row],[col]. Used by the integration test bot.
  (double, double) fingerFor(int pieceRows, int pieceCols, int row, int col) =>
      (
        boardLeft + (col + pieceCols / 2) * cellSize,
        boardTop + (row + pieceRows / 2) * cellSize + dragLift,
      );

  /// Snaps a dragged piece's top-left (screen px) to the nearest board cell.
  (int, int) snapTopLeft(double x, double y) => (
    ((y - boardTop) / cellSize).round(),
    ((x - boardLeft) / cellSize).round(),
  );
}
