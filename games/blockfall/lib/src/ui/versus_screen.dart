import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:game_core/game_core.dart';

import '../game/flame/blockfall_flame_game.dart' show previewCells;
import '../game/rules/active_piece.dart';
import '../game/rules/blockfall_game.dart';
import '../game/rules/blockfall_versus.dart';
import '../game/rules/well.dart';
import '../game/themes/block_theme.dart';
import 'test_ids.dart';

/// Blockfall, versus (docs/SPEC.md, "Two players"): two wells side by side with the same pieces,
/// garbage rows sent to the other well, the last one standing wins. Player 2 is on the left with
/// the left-hand keys, player 1 on the right with the arrows. Nothing is recorded: no score, coins
/// or progress, and no profile is needed.
class BlockfallVersusScreen extends StatefulWidget {
  const BlockfallVersusScreen({
    super.key,
    required this.onExit,
    this.theme,
    this.seed,
    this.newGame,
  });

  final VoidCallback onExit;

  /// The block look (default: the first theme).
  final BlockTheme? theme;

  /// Fixes the piece order (tests); null draws a new one for every game.
  final int? seed;

  /// Builds the game for each round (tests inject their own); null makes a seeded one.
  final BlockfallVersus Function()? newGame;

  @override
  State<BlockfallVersusScreen> createState() => _VersusState();
}

enum _Phase { intro, play, over }

class _VersusState extends State<BlockfallVersusScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker = createTicker(_tick);
  final ValueNotifier<int> _frame = ValueNotifier(0);
  late BlockfallVersus _v = _newGame();
  _Phase _phase = _Phase.intro;
  Duration? _last;
  bool _paused = false;
  int _round = 0;

  BlockTheme get _theme => widget.theme ?? BlockTheme.byIndex(0);

  BlockfallVersus _newGame() =>
      widget.newGame?.call() ??
      BlockfallVersus(
        seed: widget.seed != null
            ? widget.seed! + _round
            : Random().nextInt(1 << 30),
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  // ---- flow ----

  void _start() {
    _round++;
    _v = _newGame();
    setState(() {
      _phase = _Phase.play;
      _paused = false;
      _last = null;
    });
    if (!_ticker.isActive) _ticker.start();
  }

  void _tick(Duration d) {
    final last = _last;
    final dt = last == null ? 0.0 : min(0.1, (d - last).inMicroseconds / 1e6);
    _last = d;
    if (_phase != _Phase.play || _paused) return;
    _v.tick(dt);
    _frame.value++;
    if (_v.isOver) {
      _ticker.stop();
      setState(() => _phase = _Phase.over);
    }
  }

  void _pause() {
    if (_phase != _Phase.play || _paused) return;
    setState(() {
      _paused = true;
      _v.pause();
    });
  }

  void _togglePause() {
    if (_phase != _Phase.play) return;
    if (_paused) {
      setState(() {
        _paused = false;
        _v.resume();
        _last = null;
      });
    } else {
      _pause();
    }
  }

  // ---- keys (docs/KEYBOARD.md) ----

  void _onInput(GameInput i) {
    if (i.action == GameAction.exit) {
      if (i.repeat) return;
      _phase == _Phase.play ? _togglePause() : widget.onExit();
      return;
    }
    if (i.action == GameAction.pause && _phase == _Phase.play) {
      if (!i.repeat) _togglePause();
      return;
    }
    if (_paused) return;
    if (_phase != _Phase.play) {
      // Enter or Space starts and plays again; Space only pauses in play (U2).
      final goOn =
          i.action == GameAction.action || i.action == GameAction.pause;
      if (goOn && !i.repeat) _start();
      return;
    }
    final p = i.player;
    switch (i.action) {
      case GameAction.left:
        _v.moveLeft(p);
      case GameAction.right:
        _v.moveRight(p);
      case GameAction.up:
        if (!i.repeat) _v.rotate(p);
      case GameAction.down:
        if (!i.repeat) _v.softDrop(p, true);
      case GameAction.action:
        if (!i.repeat) _v.hardDrop(p);
      case GameAction.pick1:
        if (!i.repeat) _v.hold(p);
      default:
        return;
    }
    _frame.value++;
    if (_v.isOver) {
      _ticker.stop();
      setState(() => _phase = _Phase.over);
    }
  }

  void _onRelease(GameInput i) {
    if (i.action == GameAction.down) _v.softDrop(i.player, false);
  }

  // ---- look ----

  Color _color(ColorScheme cs, int p) => p == 1 ? cs.primary : cs.secondary;
  IconData _marker(int p) => p == 1 ? Icons.circle : Icons.square;

  @override
  Widget build(BuildContext context) {
    final wide = WindowClass.ofContext(context) != WindowClass.compact;
    return Scaffold(
      key: TestIds.versusScreen,
      backgroundColor: _theme.backgroundTop,
      body: SafeArea(
        child: GameKeyboard(
          twoPlayer: true,
          onInput: _onInput,
          onRelease: _onRelease,
          child: GameFrame(
            showAds: _phase != _Phase.play || _paused,
            phoneBanner: null,
            maxWidth: 980,
            child: Column(
              children: [
                GameTopBar(
                  title: 'Blockfall: versus',
                  onExit: widget.onExit,
                  exitKey: TestIds.versusExit,
                  onPause: _phase == _Phase.play ? _togglePause : null,
                  pauseKey: TestIds.versusPause,
                  paused: _paused,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      switch (_phase) {
                        _Phase.intro => _intro(context),
                        _Phase.play => _play(context),
                        _Phase.over => _over(context),
                      },
                      if (_paused)
                        PauseOverlay(
                          overlayKey: TestIds.versusPaused,
                          resumeKey: TestIds.versusResume,
                          onResume: _togglePause,
                          onLeave: widget.onExit,
                          leaveKey: TestIds.versusLeave,
                        ),
                    ],
                  ),
                ),
                if (wide && _phase != _Phase.over) _hints(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hints(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget row(int p) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_marker(p), size: 14, color: _color(cs, p)),
        const SizedBox(width: 6),
        Flexible(
          child: KeyHints(
            player: p,
            style: TextStyle(color: _theme.hudSubtle, fontSize: 12),
            words: const {
              GameAction.up: 'rotate',
              GameAction.down: 'soft drop',
              GameAction.action: 'hard drop',
              GameAction.pick1: 'hold',
            },
            actions: const [
              GameAction.left,
              GameAction.right,
              GameAction.up,
              GameAction.down,
              GameAction.action,
              GameAction.pick1,
            ],
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 24,
        runSpacing: 6,
        children: [row(2), row(1)],
      ),
    );
  }

  TextStyle get _hud => TextStyle(color: _theme.hudText, fontSize: 18);

  Widget _intro(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final keys = GameKeysScope.of(context);
    String set(int p) => [
      GameAction.left,
      GameAction.right,
      GameAction.up,
      GameAction.down,
      GameAction.action,
      GameAction.pick1,
    ].map((a) => keyLabel(keys.primaryOf(KeySlot(a, p)))).join(' ');
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Versus',
                style: _hud.copyWith(fontSize: 32, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                'Two wells, the same pieces. Clear two or more lines to send garbage rows to the '
                'other well. Garbage rises after the other player\'s next piece lands, and a clear '
                'of yours can cancel it first. The last one standing wins.',
                style: _hud,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              for (final p in [1, 2])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Icon(_marker(p), color: _color(cs, p), size: 18),
                      Text('Player $p: ${set(p)}', style: _hud),
                    ],
                  ),
                ),
              Text(
                'left, right, rotate, soft drop, hard drop, hold',
                style: _hud.copyWith(fontSize: 13, color: _theme.hudSubtle),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: TestIds.versusStart,
                onPressed: _start,
                child: const Text('Start (Enter)'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _play(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // Two sides, each a well (10 cells wide) and a column for hold and next (about 4.4 cells).
        const sideCells = 10 + 0.4 + 4.4;
        const header = 44.0;
        final byWidth = (box.maxWidth - 24) / (2 * sideCells + 1.2);
        final byHeight = (box.maxHeight - header) / Well.visibleRows;
        final cell = max(8.0, min(byWidth, byHeight));
        return Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _side(context, 2, cell),
              SizedBox(width: cell * 1.2),
              _side(context, 1, cell),
            ],
          ),
        );
      },
    );
  }

  Widget _side(BuildContext context, int p, double cell) {
    final cs = Theme.of(context).colorScheme;
    final g = _v.game(p);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 36,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_marker(p), size: 16, color: _color(cs, p)),
              const SizedBox(width: 6),
              Text(
                'Player $p',
                style: _hud.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The garbage waiting for this player: a bar on the well's outer side.
            ValueListenableBuilder<int>(
              valueListenable: _frame,
              builder: (_, _, _) {
                final n = _v.pendingFor(p);
                return Semantics(
                  label: n == 0
                      ? 'Player $p: no garbage coming'
                      : 'Player $p: $n garbage ${n == 1 ? 'row' : 'rows'} coming',
                  excludeSemantics: true,
                  child: SizedBox(
                    key: p == 1
                        ? TestIds.versusP1Garbage
                        : TestIds.versusP2Garbage,
                    width: cell * 0.4,
                    height: cell * Well.visibleRows,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: cell * 0.4,
                        height: min(n, Well.visibleRows) * cell,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5A4D),
                          borderRadius: BorderRadius.circular(cell * 0.15),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Semantics(
              label: 'Player $p well',
              child: CustomPaint(
                key: p == 1 ? TestIds.versusP1Well : TestIds.versusP2Well,
                size: Size(cell * Well.cols, cell * Well.visibleRows),
                painter: _WellPainter(g, _theme, cell, _frame),
              ),
            ),
            SizedBox(
              width: cell * 4.4,
              child: Padding(
                padding: EdgeInsets.only(left: cell * 0.3),
                child: ValueListenableBuilder<int>(
                  valueListenable: _frame,
                  builder: (_, _, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HOLD',
                        style: _hud.copyWith(
                          fontSize: 11,
                          color: _theme.hudSubtle,
                        ),
                      ),
                      _PiecePreview(
                        key: p == 1
                            ? TestIds.versusP1Hold
                            : TestIds.versusP2Hold,
                        spec: g.holdPiece,
                        theme: _theme,
                        cell: cell * 0.7,
                      ),
                      SizedBox(height: cell * 0.4),
                      Text(
                        'NEXT',
                        style: _hud.copyWith(
                          fontSize: 11,
                          color: _theme.hudSubtle,
                        ),
                      ),
                      for (final s in g.next)
                        _PiecePreview(spec: s, theme: _theme, cell: cell * 0.7),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _over(BuildContext context) {
    final w = _v.winner ?? 0;
    final headline = w == 0 ? 'A draw!' : 'Player $w wins!';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              liveRegion: true,
              container: true,
              child: Text(
                headline,
                key: TestIds.versusWinner,
                style: _hud.copyWith(fontSize: 32, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text('Played ${_v.elapsed.round()} seconds', style: _hud),
            const SizedBox(height: 24),
            FilledButton(
              key: TestIds.versusAgain,
              onPressed: _start,
              child: const Text('Play again'),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: TestIds.versusLeave,
              onPressed: widget.onExit,
              child: const Text('Leave'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One well: the panel, grid, locked cells, the ghost and the falling piece.
class _WellPainter extends CustomPainter {
  _WellPainter(this.game, this.theme, this.cell, Listenable repaint)
    : super(repaint: repaint);

  final BlockfallGame game;
  final BlockTheme theme;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final panel = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(cell * 0.3),
    );
    canvas.drawRRect(panel, Paint()..color = theme.wellColor);
    final grid = Paint()
      ..color = theme.gridLine
      ..strokeWidth = 1;
    for (var c = 1; c < Well.cols; c++) {
      canvas.drawLine(Offset(c * cell, 0), Offset(c * cell, size.height), grid);
    }
    for (var r = 1; r < Well.visibleRows; r++) {
      canvas.drawLine(Offset(0, r * cell), Offset(size.width, r * cell), grid);
    }
    Rect at(int row, int col) =>
        Rect.fromLTWH(col * cell, (row - Well.hiddenRows) * cell, cell, cell);
    final well = game.well;
    for (var r = Well.hiddenRows; r < Well.totalRows; r++) {
      for (var c = 0; c < Well.cols; c++) {
        final color = well.colorAt(r, c);
        if (color != 0) theme.paintCell(canvas, at(r, c), color);
      }
    }
    final active = game.currentPiece;
    if (active != null && !game.isGameOver) {
      final ghost = game.ghostPiece;
      if (ghost != null && ghost.row != active.row) {
        for (final c in ghost.cells) {
          if (c.row >= Well.hiddenRows) {
            theme.paintGhost(canvas, at(c.row, c.col), active.type!.colorId);
          }
        }
      }
      for (final c in active.cells) {
        if (c.row >= Well.hiddenRows) {
          theme.paintCell(canvas, at(c.row, c.col), active.type!.colorId);
        }
      }
    }
    canvas.drawRRect(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = theme.hudSubtle.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(_WellPainter old) =>
      old.game != game || old.theme != theme || old.cell != cell;
}

/// A small piece for the hold box and the next queue.
class _PiecePreview extends StatelessWidget {
  const _PiecePreview({
    super.key,
    required this.spec,
    required this.theme,
    required this.cell,
  });

  final PieceSpec? spec;
  final BlockTheme theme;
  final double cell;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: cell * 4,
      height: cell * 2.4,
      child: spec == null
          ? null
          : CustomPaint(painter: _PreviewPainter(spec!, theme, cell)),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.spec, this.theme, this.cell);
  final PieceSpec spec;
  final BlockTheme theme;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final p = previewCells(spec.type, null);
    final left = (size.width - p.cols * cell) / 2;
    final top = (size.height - p.rows * cell) / 2;
    for (final (c, r) in p.cells) {
      theme.paintCell(
        canvas,
        Rect.fromLTWH(left + c * cell, top + r * cell, cell, cell),
        spec.type.colorId,
      );
    }
  }

  @override
  bool shouldRepaint(_PreviewPainter old) =>
      old.spec.type != spec.type || old.cell != cell || old.theme != theme;
}
