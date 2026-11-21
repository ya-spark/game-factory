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
    final topPad = min(height * 0.06, 60);
    // Vertical budget in cells: board, gap, piece tray, and the free strip under the
    // pieces. The strip is where thumbs rest to start a drag, so it is never squeezed out:
    // on short screens the whole board shrinks instead.
    const needed = 8 + 0.5 + 3.2 + bottomGapCells;
    cellSize = min(
      (width - margin * 2) / gridSize,
      (height - topPad - margin) / (needed - 8 + gridSize),
    );
    // The board sits [boardDropCells] below vertical centre, so the top rows stay within thumb
    // reach, but never so low that the tray pieces leave the screen.
    final maxTop =
        height - margin - cellSize * (needed - 8 - bottomGapCells + gridSize);
    boardTop = max(
      topPad,
      min(
        (height - cellSize * gridSize) / 2 + cellSize * boardDropCells,
        maxTop,
      ),
    ).toDouble();
    boardLeft = (width - cellSize * gridSize) / 2;
    final boardBottom = boardTop + cellSize * gridSize;
    // Tray slots share the area under the board.
    trayTop = boardBottom + cellSize * 0.5;
    trayHeight = max(
      cellSize * (3.2 + bottomGapCells),
      height - trayTop - margin,
    );
    slotWidth = cellSize * gridSize / traySlots;
    // Pieces in the tray are drawn smaller than board cells.
    trayCellSize = min(cellSize * 0.62, slotWidth / 5.5);
  }

  /// How far below vertical centre the board sits, in board cells.
  static const double boardDropCells = 1.5;

  /// Free space kept under the tray pieces, in board cells.
  static const double bottomGapCells = 0.7;

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
  (double, double) trayCenter(int slot) => (
    boardLeft + slotWidth * (slot + 0.5),
    trayTop + (trayHeight - cellSize * bottomGapCells) / 2,
  );

  /// Which tray slot a point is in, or null. Generous on purpose: a press anywhere from just
  /// above the tray down to the bottom of the screen, across the full width, picks the slot
  /// under it (thumbs press below the piece, not on it).
  int? traySlotAt(double x, double y) {
    if (y < trayTop - cellSize * 0.25 || y > height) return null;
    final i = ((x - boardLeft) / slotWidth).floor().clamp(0, traySlots - 1);
    return i;
  }

  /// The dragged piece's bottom edge floats this far above the finger, whatever the press point.
  double get dragLift => cellSize * 2.5;

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

  /// Finger position that makes a piece of [pieceRows]x[pieceCols] snap with its top-left on
  /// board cell [row],[col], for a drag that started on the piece centre (the piece bottom floats [dragLift] above it). Used by the test bot.
  (double, double) fingerFor(int pieceRows, int pieceCols, int row, int col) =>
      (
        boardLeft + (col + pieceCols / 2) * cellSize,
        boardTop + (row + pieceRows) * cellSize + dragLift,
      );

  /// A dragged piece's top-left (screen px) in unrounded board cell units: (row, col).
  (double, double) topLeftInCells(double x, double y) =>
      ((y - boardTop) / cellSize, (x - boardLeft) / cellSize);
}
