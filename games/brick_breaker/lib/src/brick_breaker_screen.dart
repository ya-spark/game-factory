import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:game_core/game_core.dart';

import 'rules/brick_breaker_rules.dart';

/// Best-score thresholds for 1, 2 and 3 stars on the Games tab tile (docs/SPEC.md, 4.4).
const List<int> brickStarScores = [300, 1000, 2500];

const String _g = 'bricks';

/// Brick breaker: drag the paddle (or use the arrow buttons), tap to launch. Free with ads.
class BrickBreakerScreen extends StatelessWidget {
  const BrickBreakerScreen({super.key, this.onScore, this.random});
  final void Function(int score)? onScore;

  /// The random source of launches and power-ups; default a fresh `Random`. Injected in tests.
  final Random? random;

  @override
  Widget build(BuildContext context) {
    return ArcadeFrame(
      id: _g,
      title: 'Brick breaker',
      howTo:
          'Drag to move the paddle and keep the ball up. Tap to launch. Break '
          'every brick to clear a level; there are 20. Catch falling power-ups: '
          'a wide paddle and a slow ball.',
      starScores: brickStarScores,
      coinsPerPoints: 50,
      hasContinue: true,
      hintActions: const [GameAction.left, GameAction.right, GameAction.action],
      onScore: onScore,
      buildPlay: (context, run, round) => _BrickPlay(
        key: ValueKey('bricks.round.$round'),
        run: run,
        random: random ?? Random(),
      ),
    );
  }
}

class _BrickPlay extends StatefulWidget {
  const _BrickPlay({super.key, required this.run, required this.random});
  final ArcadeRun run;
  final Random random;

  @override
  State<_BrickPlay> createState() => _BrickPlayState();
}

class _BrickPlayState extends State<_BrickPlay>
    with SingleTickerProviderStateMixin {
  late final BrickGame _game = BrickGame(random: widget.random);
  late final Ticker _ticker = createTicker(_tick);
  final FixedStepper _stepper = FixedStepper(dt: brickStep);
  Duration _last = Duration.zero;
  double _fieldW = brickW;

  @override
  void initState() {
    super.initState();
    widget.run
      ..onContinue = _continue
      ..onInput = _onKey
      ..onRelease = _onKeyUp;
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// Left and right move while held, Enter or up launches (docs/KEYBOARD.md).
  void _onKey(GameInput i) {
    switch (i.action) {
      case GameAction.left:
        _game.setMove(-1);
      case GameAction.right:
        _game.setMove(1);
      case GameAction.action || GameAction.up:
        if (!i.repeat) _game.launch();
      default:
    }
  }

  void _onKeyUp(GameInput i) {
    if (i.action == GameAction.left || i.action == GameAction.right) {
      _game.setMove(0);
    }
  }

  void _continue() {
    _game.grantContinue();
    _stepper.reset();
    _last = Duration.zero;
    _ticker
      ..stop()
      ..start();
    setState(() {});
  }

  void _tick(Duration t) {
    final dt = (t - _last).inMicroseconds / 1e6;
    _last = t;
    var n = _stepper.advance(dt);
    if (_game.over) return;
    while (n-- > 0 && !_game.over) {
      _game.step();
    }
    setState(() {});
    if (_game.over) {
      _ticker.stop();
      widget.run.end(_game.score, canContinue: !_game.won);
    }
  }

  void _drag(double dx) => _game.movePaddleTo(dx / _fieldW * brickW);

  @override
  Widget build(BuildContext context) {
    final pal = ArcadePalette(context);
    return Column(
      children: [
        ArcadeHud(
          game: _g,
          text:
              'Score ${_game.score}   Level ${_game.level}   '
              'Lives ${_game.lives}',
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: AspectRatio(
                aspectRatio: brickW / brickH,
                child: LayoutBuilder(
                  builder: (context, box) {
                    _fieldW = box.maxWidth;
                    return GestureDetector(
                      key: MindIds.arcade(_g, 'field'),
                      behavior: HitTestBehavior.opaque,
                      onTap: _game.launch,
                      onPanStart: (d) => _drag(d.localPosition.dx),
                      onPanUpdate: (d) => _drag(d.localPosition.dx),
                      child: Semantics(
                        label:
                            'Brick breaker field, level ${_game.level}, '
                            '${_game.bricksLeft} bricks left. Drag to move '
                            'the paddle, tap to launch.',
                        child: CustomPaint(
                          painter: _BrickPainter(_game, pal),
                          size: Size.infinite,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _hold('left', Icons.arrow_back, -1),
              FilledButton(
                key: MindIds.arcade(_g, 'launch'),
                onPressed: _game.launch,
                child: const Text('Launch'),
              ),
              _hold('right', Icons.arrow_forward, 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hold(String name, IconData icon, int dir) => Listener(
    onPointerDown: (_) => _game.setMove(dir),
    onPointerUp: (_) => _game.setMove(0),
    onPointerCancel: (_) => _game.setMove(0),
    child: Semantics(
      button: true,
      label: 'Move paddle $name. Hold.',
      excludeSemantics: true,
      onTap: () => _game.movePaddleTo(_game.paddleX + dir * 10),
      child: Container(
        key: MindIds.arcade(_g, name),
        constraints: const BoxConstraints(minWidth: 64, minHeight: 56),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Icon(
          icon,
          size: 32,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    ),
  );
}

class _BrickPainter extends CustomPainter {
  _BrickPainter(this.game, this.pal);
  final BrickGame game;
  final ArcadePalette pal;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / brickW;
    final sy = size.height / brickH;
    canvas.drawRect(Offset.zero & size, Paint()..color = pal.background);
    for (var r = 0; r < game.bricks.length; r++) {
      for (var c = 0; c < brickCols; c++) {
        final hp = game.bricks[r][c];
        if (hp == 0) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              c * brickCellW * sx + 1,
              (brickTop + r * brickCellH) * sy + 1,
              brickCellW * sx - 2,
              brickCellH * sy - 2,
            ),
            const Radius.circular(3),
          ),
          Paint()..color = hp > 1 ? pal.danger : pal.primary,
        );
      }
    }
    for (final p in game.powerUps) {
      final wide = p.kind == PowerUpKind.widePaddle;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(p.x * sx, p.y * sy),
            width: (wide ? 7 : 5) * sx,
            height: 4 * sy,
          ),
          const Radius.circular(4),
        ),
        Paint()..color = pal.accent,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          (game.paddleX - game.paddleW / 2) * sx,
          paddleY * sy,
          game.paddleW * sx,
          paddleH * sy,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = game.wideLeft > 0 ? pal.accent : pal.primary,
    );
    canvas.drawCircle(
      Offset(game.ballX * sx, game.ballY * sy),
      ballR * sx,
      Paint()..color = game.slowLeft > 0 ? pal.accent : pal.danger,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = pal.line,
    );
  }

  @override
  bool shouldRepaint(covariant _BrickPainter old) => true;
}
