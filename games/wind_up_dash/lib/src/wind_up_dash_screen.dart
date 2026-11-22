import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:game_core/game_core.dart';

import 'rules/dash_rules.dart';

/// Best-score thresholds for 1, 2 and 3 stars on the Games tab tile (docs/SPEC.md, 4.6):
/// 1000, 2500 and 5000 units run.
const List<int> dashStarScores = [100, 250, 500];

const String _g = 'wind_up_dash';

/// Wind-up dash: one tap to jump over gaps and blocks. Coin-locked in the hub (300 coins).
class WindUpDashScreen extends StatelessWidget {
  const WindUpDashScreen({super.key, this.onScore, this.seedFor});
  final void Function(int score)? onScore;

  /// The track seed of each round; default a random one. Injected in tests.
  final int Function()? seedFor;

  @override
  Widget build(BuildContext context) {
    return ArcadeFrame(
      id: _g,
      title: 'Wind-up dash',
      howTo:
          'Tap to jump. Clear the gaps and the blocks and run as far as you '
          'can. The track gets faster. Every track is fair: a well-timed jump '
          'always works.',
      starScores: dashStarScores,
      coinsPerPoints: 25,
      hasContinue: true,
      hintActions: const [GameAction.up, GameAction.action],
      hintWords: const {GameAction.up: 'jump', GameAction.action: 'jump'},
      onScore: onScore,
      buildPlay: (context, run, round) => _DashPlay(
        key: ValueKey('wind_up_dash.round.$round'),
        run: run,
        seed: seedFor?.call() ?? Random().nextInt(1 << 30),
      ),
    );
  }
}

class _DashPlay extends StatefulWidget {
  const _DashPlay({super.key, required this.run, required this.seed});
  final ArcadeRun run;
  final int seed;

  @override
  State<_DashPlay> createState() => _DashPlayState();
}

class _DashPlayState extends State<_DashPlay>
    with SingleTickerProviderStateMixin {
  late final DashGame _game = DashGame(seed: widget.seed);
  late final Ticker _ticker = createTicker(_tick);
  final FixedStepper _stepper = FixedStepper(dt: dashStep);
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.run
      ..onContinue = _continue
      ..onInput = _onKey;
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// Up or Enter jumps (docs/KEYBOARD.md; Space and Esc pause, in the frame).
  void _onKey(GameInput i) {
    if (i.repeat) return;
    if (i.action == GameAction.up || i.action == GameAction.action) {
      _game.jump();
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
    while (n-- > 0 && !_game.over) {
      _game.step();
    }
    setState(() {});
    if (_game.over) {
      _ticker.stop();
      widget.run.end(_game.score, canContinue: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = ArcadePalette(context);
    return Column(
      children: [
        ArcadeHud(
          game: _g,
          text: 'Score ${_game.score}   Speed ${dashSpeed(_game.x).round()}',
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: AspectRatio(
                aspectRatio: 100 / 60,
                child: GestureDetector(
                  key: MindIds.arcade(_g, 'field'),
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => _game.jump(),
                  child: Semantics(
                    label: 'Wind-up dash track, score ${_game.score}. Tap to jump.',
                    child: CustomPaint(
                      painter: _DashPainter(_game, pal),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            key: MindIds.arcade(_g, 'jump'),
            onPressed: _game.jump,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              child: Text(withKey('Jump', '↑ / Enter')),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.game, this.pal);
  final DashGame game;
  final ArcadePalette pal;

  static const double _viewW = 100;
  static const double _viewH = 60;
  static const double _groundY = 44;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / _viewW;
    final sy = size.height / _viewH;
    canvas.drawRect(Offset.zero & size, Paint()..color = pal.background);
    final camera = game.x - 25;
    final ground = Paint()..color = pal.line;
    // Ground: one strip, with the gaps cut out.
    var from = camera;
    final to = camera + _viewW;
    for (final h in game.track.hazards) {
      if (h.end < camera) continue;
      if (h.x > to) break;
      if (h.kind == HazardKind.gap) {
        _strip(canvas, from, h.x, sx, sy, camera, ground);
        from = h.end;
      }
    }
    _strip(canvas, from, to, sx, sy, camera, ground);
    for (final h in game.track.hazards) {
      if (h.end < camera) continue;
      if (h.x > to) break;
      if (h.kind == HazardKind.block) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              (h.x - camera) * sx,
              (_groundY - h.height) * sy,
              h.width * sx,
              h.height * sy,
            ),
            const Radius.circular(2),
          ),
          Paint()..color = pal.danger,
        );
      }
    }
    // The car: a rounded square (a shape, not a figure).
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          (game.x - camera - dashWidth / 2) * sx,
          (_groundY - game.y - dashWidth) * sy,
          dashWidth * sx,
          dashWidth * sy,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = pal.primary,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = pal.line,
    );
  }

  void _strip(
    Canvas canvas,
    double a,
    double b,
    double sx,
    double sy,
    double camera,
    Paint paint,
  ) {
    if (b <= a) return;
    canvas.drawRect(
      Rect.fromLTWH(
        (a - camera) * sx,
        _groundY * sy,
        (b - a) * sx,
        (_viewH - _groundY) * sy,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => true;
}
