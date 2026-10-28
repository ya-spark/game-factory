import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart' show HSLColor;

import '../layout.dart';
import '../rules/game_state.dart';
import '../rules/piece.dart';
import '../rules/piece_generator.dart';

/// Flame renderer for the block puzzle. All rules live in [GameState] (pure Dart);
/// this class only draws and translates drags into `state.place(...)`.
class BlockPuzzleGame extends FlameGame {
  BlockPuzzleGame({
    this.bestScore = 0,
    PieceGenerator? generator,
    Color? background,

    /// Test hook: start from a prepared state instead of a fresh game.
    GameState? initialState,
  }) : _generator = generator,
       _background = background ?? const Color(0x00000000) {
    state =
        initialState ?? GameState(bestScore: bestScore, generator: generator);
  }

  final int bestScore;
  final PieceGenerator? _generator;
  final Color _background;

  late GameState state;
  late PuzzleView view;

  /// Called after every legal placement.
  void Function(PlaceOutcome outcome)? onPlaced;

  /// Called once when the game ends (no piece fits).
  void Function()? onGameOver;

  /// Notifies the UI to refresh score displays.
  void Function()? onChanged;

  PuzzleLayout get layout => view.layout;

  @override
  Color backgroundColor() => _background;

  @override
  Future<void> onLoad() async {
    view = PuzzleView();
    await add(view);
  }

  void restart() {
    state = GameState(bestScore: state.bestScore, generator: _generator);
    view.cancelDrag();
    onChanged?.call();
  }

  bool revive() {
    final ok = state.revive();
    if (ok) onChanged?.call();
    return ok;
  }

  void _handlePlace(int slot, int row, int col) {
    final wasOver = state.isGameOver;
    final outcome = state.place(slot, row, col);
    if (outcome == null) return;
    view.flash(outcome.clearedRows, outcome.clearedCols);
    onPlaced?.call(outcome);
    onChanged?.call();
    if (outcome.gameOver && !wasOver) onGameOver?.call();
  }
}

/// Draws the board + tray and handles drag and drop. Fills the whole game area.
class PuzzleView extends PositionComponent
    with DragCallbacks, HasGameReference<BlockPuzzleGame> {
  late PuzzleLayout layout = PuzzleLayout(1, 1);

  /// Gem colors, one per piece color index.
  static const List<Color> palette = [
    Color(0xFF2EC4B6), // teal
    Color(0xFFFF6B5E), // coral
    Color(0xFFFFC145), // amber
    Color(0xFF8E7DFF), // violet
    Color(0xFF4CC9F0), // sky
    Color(0xFF9BDE5B), // lime
  ];

  int? _dragSlot;
  Vector2 _finger = Vector2.zero();
  List<int> _flashRows = const [];
  List<int> _flashCols = const [];
  double _flashT = 0;

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

  @override
  void update(double dt) {
    if (_flashT > 0) _flashT = max(0, _flashT - dt);
  }

  // ---- input --------------------------------------------------------------

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    final p = event.localPosition;
    final slot = layout.traySlotAt(p.x, p.y);
    if (slot != null &&
        game.state.tray[slot] != null &&
        !game.state.isGameOver) {
      _dragSlot = slot;
      _finger = p.clone();
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
    final (r, c) = _dragTopLeftCell(piece);
    game._handlePlace(slot, r, c);
  }

  (int, int) _dragTopLeftCell(Piece piece) {
    final cs = layout.cellSize;
    final x = _finger.x - piece.width * cs / 2;
    final y = _finger.y - layout.dragLift - piece.height * cs / 2;
    return layout.snapTopLeft(x, y);
  }

  // ---- drawing ------------------------------------------------------------

  @override
  void render(Canvas canvas) {
    final cs = layout.cellSize;
    final board = game.state.board;
    final gridPaint = Paint()..color = const Color(0xFF0A1A22);
    final emptyPaint = Paint()..color = const Color(0xFF132A34);
    final outline = Paint()
      ..color = const Color(0x332EC4B6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          layout.boardLeft - 4,
          layout.boardTop - 4,
          layout.boardSizePx + 8,
          layout.boardSizePx + 8,
        ),
        const Radius.circular(16),
      ),
      gridPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          layout.boardLeft - 4,
          layout.boardTop - 4,
          layout.boardSizePx + 8,
          layout.boardSizePx + 8,
        ),
        const Radius.circular(16),
      ),
      outline,
    );
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
          _drawBlock(
            canvas,
            rect,
            palette[(board.at(r, c) - 1) % palette.length],
          );
        }
      }
    }

    // Placement preview while dragging.
    final slot = _dragSlot;
    if (slot != null) {
      final piece = game.state.tray[slot];
      if (piece != null) {
        final (r, c) = _dragTopLeftCell(piece);
        if (board.canPlace(piece, r, c)) {
          final ghost = Paint()
            ..color = palette[piece.colorIndex].withAlpha(90);
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

    // Tray.
    for (var i = 0; i < GameState.traySlots; i++) {
      final piece = game.state.tray[i];
      if (piece == null || i == _dragSlot) continue;
      final (cx, cy) = layout.trayCenter(i);
      final tcs = layout.trayCellSize;
      _drawPiece(
        canvas,
        piece,
        cx - piece.width * tcs / 2,
        cy - piece.height * tcs / 2,
        tcs,
      );
    }

    // Dragged piece.
    if (slot != null) {
      final piece = game.state.tray[slot];
      if (piece != null) {
        _drawPiece(
          canvas,
          piece,
          _finger.x - piece.width * cs / 2,
          _finger.y - layout.dragLift - piece.height * cs / 2,
          cs,
        );
      }
    }
  }

  void _drawPiece(
    Canvas canvas,
    Piece piece,
    double left,
    double top,
    double cs,
  ) {
    final color = palette[piece.colorIndex];
    for (final (dr, dc) in piece.cells) {
      _drawBlock(
        canvas,
        Rect.fromLTWH(left + dc * cs, top + dr * cs, cs, cs),
        color,
      );
    }
  }

  /// Glossy rounded "gem": diagonal gradient, soft bottom shade, small specular dot.
  void _drawBlock(Canvas canvas, Rect rect, Color color) {
    final r = rect.deflate(1.5);
    final radius = Radius.circular(r.width * 0.26);
    final rrect = RRect.fromRectAndRadius(r, radius);
    final hsl = HSLColor.fromColor(color);
    final light = hsl
        .withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0))
        .toColor();
    final dark = hsl
        .withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0))
        .toColor();
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = Gradient.linear(
          r.topLeft,
          r.bottomRight,
          [light, color, dark],
          const [0.0, 0.55, 1.0],
        ),
    );
    // Soft bottom edge.
    canvas.drawRRect(
      rrect.shift(Offset.zero),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x22000000),
    );
    // Specular dot.
    canvas.drawCircle(
      Offset(r.left + r.width * 0.3, r.top + r.height * 0.27),
      r.width * 0.09,
      Paint()..color = const Color(0xB3FFFFFF),
    );
  }
}
