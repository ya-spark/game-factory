import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';

import '../layout.dart';
import '../rules/boosts.dart';
import '../rules/game_state.dart';
import '../rules/piece.dart';
import '../rules/piece_generator.dart';
import '../rules/snap.dart';
import '../rules/theme_rotation.dart';
import '../themes/block_theme.dart';
import 'special_overlay.dart';

/// Flame renderer for the block puzzle. All rules live in [GameState] (pure Dart);
/// this class only draws and translates drags into `state.place(...)`.
class BlockPuzzleGame extends FlameGame {
  BlockPuzzleGame({
    this.bestScore = 0,
    PieceGenerator? generator,
    Color? background,
    this.themeStart = 0,

    /// Test hook: start from a prepared state instead of a fresh game.
    GameState? initialState,
  }) : _generator = generator,
       _background = background ?? const Color(0x00000000) {
    state =
        initialState ??
        GameState.newGame(bestScore: bestScore, generator: generator);
  }

  final int bestScore;
  final PieceGenerator? _generator;
  final Color _background;

  /// Rotation index (see [ThemeRotation]) at which this game started.
  int themeStart;

  late GameState state;
  late PuzzleView view;

  /// Cached cell pictures per (theme, colour).
  final ThemeTileCache tiles = ThemeTileCache();

  /// Called after every legal placement.
  void Function(PlaceOutcome outcome)? onPlaced;

  /// Called once when the game ends (no piece fits).
  void Function()? onGameOver;

  /// Notifies the UI to refresh score displays.
  void Function()? onChanged;

  PuzzleLayout get layout => view.layout;

  /// Current position in the theme rotation: changes every
  /// [ThemeRotation.themeEveryLines] cleared lines.
  int get themeIndex =>
      ThemeRotation.indexFor(themeStart, state.linesClearedTotal);

  BlockTheme get theme => BlockTheme.byIndex(themeIndex);

  @override
  Color backgroundColor() => _background;

  @override
  Future<void> onLoad() async {
    view = PuzzleView();
    await add(view);
  }

  @override
  void onRemove() {
    tiles.dispose();
    super.onRemove();
  }

  void restart() {
    // A new game continues the rotation where this one stopped.
    themeStart = themeIndex;
    state = GameState.newGame(
      bestScore: state.bestScore,
      generator: _generator,
    );
    view.cancelDrag();
    targeting = null;
    targetCell = null;
    onChanged?.call();
  }

  bool revive() {
    final ok = state.revive();
    if (ok) {
      cancelTargeting();
      onChanged?.call();
    }
    return ok;
  }

  // ---- boosts -------------------------------------------------------------

  /// Boost waiting for a tapped cell (Blast or Hammer), or null.
  BoostId? targeting;

  /// Cell under the finger while targeting (drives the preview), or null.
  (int, int)? targetCell;

  void armTargeting(BoostId id) {
    targeting = id;
    targetCell = null;
    view.cancelDrag();
    onChanged?.call();
  }

  void cancelTargeting() {
    if (targeting == null && targetCell == null) return;
    targeting = null;
    targetCell = null;
    onChanged?.call();
  }

  /// Applies the armed boost at [row],[col]. Null when nothing was emptied (nothing is
  /// spent and targeting stays armed).
  BoostResult? applyTargeted(int row, int col) {
    final r = switch (targeting) {
      BoostId.blast => state.useBlast(row, col),
      BoostId.hammer => state.useHammer(row, col),
      _ => null,
    };
    if (r == null) return null;
    targeting = null;
    targetCell = null;
    view.blast(r.cells);
    onChanged?.call();
    return r;
  }

  /// Board boosts that apply at once (Sweep): same visual as a blast.
  BoostResult? applySweep() {
    final r = state.useSweep();
    if (r == null) return null;
    view.blast(r.cells);
    onChanged?.call();
    return r;
  }

  /// Shuffle the tray.
  bool applyShuffle() {
    final ok = state.useShuffle();
    if (ok) {
      view.cancelDrag();
      onChanged?.call();
    }
    return ok;
  }

  /// Undo the last placement; returns the gem coins to take back, or null if disabled.
  int? applyUndo() {
    final coins = state.useUndo();
    if (coins == null) return null;
    view.cancelDrag();
    onChanged?.call();
    return coins;
  }

  void _handlePlace(int slot, int row, int col) {
    final wasOver = state.isGameOver;
    final outcome = state.place(slot, row, col);
    if (outcome == null) return;
    view.flash(outcome.clearedRows, outcome.clearedCols);
    view.blast(outcome.blastCells);
    onPlaced?.call(outcome);
    onChanged?.call();
    if (outcome.gameOver && !wasOver) onGameOver?.call();
  }
}

/// Draws the board + tray and handles drag and drop. Fills the whole game area.
class PuzzleView extends PositionComponent
    with DragCallbacks, HasGameReference<BlockPuzzleGame> {
  late PuzzleLayout layout = PuzzleLayout(1, 1);

  /// Seconds the cross-fade between two themes takes.
  static const double fadeSeconds = 1.5;

  int? _dragSlot;
  Vector2 _finger = Vector2.zero();

  /// Horizontal distance from the press to the piece centre, kept for the whole drag so a
  /// press on the left of a piece keeps the piece to the left of the finger.
  double _grabX = 0;
  List<int> _flashRows = const [];
  List<int> _flashCols = const [];
  double _flashT = 0;
  double _time = 0;

  /// Seconds the Boom block star burst lasts.
  static const double blastSeconds = 0.5;
  List<(int, int)> _blastCells = const [];
  double _blastT = 0;

  /// Theme cross-fade: [_from] fades into [_to]; [_fade] runs 0..1 (1 = settled).
  BlockTheme? _fromTheme;
  BlockTheme? _toTheme;
  double _fade = 1;

  BlockTheme get _from => _fromTheme ?? game.theme;
  BlockTheme get _to => _toTheme ?? game.theme;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
    layout = PuzzleLayout(size.x, size.y);
  }

  void cancelDrag() => _dragSlot = null;

  void flash(List<int> rows, List<int> cols) {
    _flashRows = rows;
    _flashCols = cols;
    _flashT = rows.isEmpty && cols.isEmpty ? 0 : 0.35;
  }

  void blast(List<(int, int)> cells) {
    _blastCells = cells;
    _blastT = cells.isEmpty ? 0 : blastSeconds;
  }

  @override
  void update(double dt) {
    _time += dt;
    if (_blastT > 0) _blastT = max(0, _blastT - dt);
    if (_flashT > 0) _flashT = max(0, _flashT - dt);
    final now = game.theme;
    if (_toTheme == null) {
      _toTheme = now;
    } else if (now.id != _toTheme!.id) {
      // The theme changed: cells already on the board fade into it, input is never blocked.
      _fromTheme = _toTheme;
      _toTheme = now;
      _fade = 0;
    }
    if (_fade < 1) _fade = min(1, _fade + dt / fadeSeconds);
  }

  // ---- input --------------------------------------------------------------

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    final p = event.localPosition;
    final slot = layout.traySlotAt(p.x, p.y);
    if (slot != null &&
        game.targeting == null &&
        game.state.tray[slot] != null &&
        !game.state.isGameOver) {
      _dragSlot = slot;
      _finger = p.clone();
      _grabX = p.x - layout.trayCenter(slot).$1;
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (_dragSlot != null) _finger += event.localDelta;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _drop();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _dragSlot = null;
  }

  void _drop() {
    final slot = _dragSlot;
    _dragSlot = null;
    if (slot == null) return;
    final piece = game.state.tray[slot];
    if (piece == null) return;
    final cell = _dragTopLeftCell(piece);
    if (cell == null) return;
    game._handlePlace(slot, cell.$1, cell.$2);
  }

  /// Screen top-left of the dragged piece: horizontally it keeps the offset of the press from
  /// the piece centre; vertically its bottom edge is always [PuzzleLayout.dragLift] above the
  /// finger, wherever the press landed.
  (double, double) _draggedTopLeft(Piece piece) {
    final cs = layout.cellSize;
    return (
      _finger.x - _grabX - piece.width * cs / 2,
      _finger.y - layout.dragLift - piece.height * cs,
    );
  }

  /// The cell the piece will land on (shared by ghost and drop), or null to cancel.
  (int, int)? _dragTopLeftCell(Piece piece) {
    final (x, y) = _draggedTopLeft(piece);
    final (fy, fx) = layout.topLeftInCells(x, y);
    return snapToLegalCell(game.state.board, piece, fy, fx);
  }

  // ---- drawing ------------------------------------------------------------

  @override
  void render(Canvas canvas) {
    final cs = layout.cellSize;
    final theme = _to;
    final slot = _dragSlot;

    // Board, cells and tray in the theme; during a change the new theme fades in over the old.
    if (_fade < 1) {
      _drawScene(canvas, _from);
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(255, 255, 255, _fade),
      );
      _drawScene(canvas, theme);
      canvas.restore();
    } else {
      _drawScene(canvas, theme);
    }

    // Placement preview while dragging.
    if (slot != null) {
      final piece = game.state.tray[slot];
      if (piece != null) {
        final cell = _dragTopLeftCell(piece);
        if (cell != null) {
          final (r, c) = cell;
          // Rows and columns this drop would clear light up, so the player can judge it
          // before letting go.
          final clears = game.state.board.linesCompletedBy(piece, r, c);
          final glow = Paint()..color = const Color(0x66FFD54F);
          final glowEdge = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xE6FFD54F);
          for (final row in clears.rows) {
            final rect = Rect.fromLTWH(
              layout.boardLeft,
              layout.boardTop + row * cs,
              layout.boardSizePx,
              cs,
            );
            canvas.drawRect(rect, glow);
            canvas.drawRect(rect, glowEdge);
          }
          for (final col in clears.cols) {
            final rect = Rect.fromLTWH(
              layout.boardLeft + col * cs,
              layout.boardTop,
              cs,
              layout.boardSizePx,
            );
            canvas.drawRect(rect, glow);
            canvas.drawRect(rect, glowEdge);
          }
          final ghost = Paint()
            ..color = theme.colorAt(piece.colorIndex).withAlpha(90);
          for (final (dr, dc) in piece.cells) {
            canvas.drawRect(
              Rect.fromLTWH(
                layout.boardLeft + (c + dc) * cs,
                layout.boardTop + (r + dr) * cs,
                cs,
                cs,
              ),
              ghost,
            );
          }
        }
      }
    }

    // Boost targeting: Blast previews its 3x3 area under the finger, Hammer one cell.
    final target = game.targetCell;
    if (game.targeting != null && target != null) {
      final reach = game.targeting == BoostId.blast ? Boosts.blastRadius : 0;
      final fill = Paint()..color = const Color(0x55FFFFFF);
      final edge = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xCCFFFFFF);
      for (var r = target.$1 - reach; r <= target.$1 + reach; r++) {
        for (var c = target.$2 - reach; c <= target.$2 + reach; c++) {
          if (r < 0 || c < 0 || r >= 8 || c >= 8) continue;
          final rect = Rect.fromLTWH(
            layout.boardLeft + c * cs,
            layout.boardTop + r * cs,
            cs,
            cs,
          ).deflate(1);
          canvas.drawRect(rect, fill);
          canvas.drawRect(rect, edge);
        }
      }
    }

    // Gold Rush: a soft golden shimmer over the board (slow sway, no flashing).
    if (game.state.rushLeft > 0) {
      final sway = 0.5 + 0.5 * sin(_time * 1.6);
      final frame = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          layout.boardLeft - 4,
          layout.boardTop - 4,
          layout.boardSizePx + 8,
          layout.boardSizePx + 8,
        ),
        const Radius.circular(16),
      );
      canvas.drawRRect(
        frame,
        Paint()
          ..shader = Gradient.linear(
            Offset(layout.boardLeft, layout.boardTop),
            Offset(
              layout.boardLeft + layout.boardSizePx,
              layout.boardTop + layout.boardSizePx,
            ),
            [
              Color.fromRGBO(255, 214, 90, 0.10 + 0.06 * sway),
              Color.fromRGBO(255, 179, 0, 0.05 + 0.05 * (1 - sway)),
              Color.fromRGBO(255, 214, 90, 0.10 + 0.06 * sway),
            ],
            const [0, 0.5, 1],
          ),
      );
      canvas.drawRRect(
        frame,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Color.fromRGBO(255, 200, 40, 0.45 + 0.2 * sway),
      );
    }

    // Boom blast: a short cartoon star burst on every emptied cell.
    if (_blastT > 0) {
      final t = 1 - _blastT / blastSeconds;
      for (final (r, c) in _blastCells) {
        drawBlast(
          canvas,
          Offset(
            layout.boardLeft + (c + 0.5) * cs,
            layout.boardTop + (r + 0.5) * cs,
          ),
          cs,
          t,
        );
      }
    }

    // Line-clear flash.
    if (_flashT > 0) {
      final p = Paint()
        ..color = Color.fromRGBO(255, 255, 255, _flashT / 0.35 * 0.6);
      for (final r in _flashRows) {
        canvas.drawRect(
          Rect.fromLTWH(
            layout.boardLeft,
            layout.boardTop + r * cs,
            layout.boardSizePx,
            cs,
          ),
          p,
        );
      }
      for (final c in _flashCols) {
        canvas.drawRect(
          Rect.fromLTWH(
            layout.boardLeft + c * cs,
            layout.boardTop,
            cs,
            layout.boardSizePx,
          ),
          p,
        );
      }
    }

    // Dragged piece.
    if (slot != null) {
      final piece = game.state.tray[slot];
      if (piece != null) {
        final (x, y) = _draggedTopLeft(piece);
        _drawPiece(canvas, theme, piece, x, y, cs);
      }
    }
  }

  /// Board backdrop, empty cells, filled cells and the resting tray pieces in [theme].
  void _drawScene(Canvas canvas, BlockTheme theme) {
    final cs = layout.cellSize;
    final board = game.state.board;
    final backdrop = Paint()..color = theme.boardBackdrop;
    final emptyPaint = Paint()..color = theme.emptyCell;
    final outline = Paint()
      ..color = theme.gridLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final frame = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        layout.boardLeft - 4,
        layout.boardTop - 4,
        layout.boardSizePx + 8,
        layout.boardSizePx + 8,
      ),
      const Radius.circular(16),
    );
    canvas.drawRRect(frame, backdrop);
    canvas.drawRRect(frame, outline);
    for (var r = 0; r < board.size; r++) {
      for (var c = 0; c < board.size; c++) {
        final rect = Rect.fromLTWH(
          layout.boardLeft + c * cs,
          layout.boardTop + r * cs,
          cs,
          cs,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(7)),
          emptyPaint,
        );
        if (board.isFilled(r, c)) {
          game.tiles.draw(canvas, theme, board.at(r, c) - 1, rect);
          drawSpecialOverlay(canvas, board.kindAt(r, c), rect);
        }
      }
    }
    for (var i = 0; i < GameState.traySlots; i++) {
      final piece = game.state.tray[i];
      if (piece == null || i == _dragSlot) continue;
      final (cx, cy) = layout.trayCenter(i);
      final tcs = layout.trayCellSize;
      _drawPiece(
        canvas,
        theme,
        piece,
        cx - piece.width * tcs / 2,
        cy - piece.height * tcs / 2,
        tcs,
      );
    }
  }

  void _drawPiece(
    Canvas canvas,
    BlockTheme theme,
    Piece piece,
    double left,
    double top,
    double cs,
  ) {
    for (var i = 0; i < piece.cells.length; i++) {
      final (dr, dc) = piece.cells[i];
      final rect = Rect.fromLTWH(left + dc * cs, top + dr * cs, cs, cs);
      game.tiles.draw(canvas, theme, piece.colorIndex, rect);
      drawSpecialOverlay(canvas, piece.kindAt(i), rect);
    }
  }
}
