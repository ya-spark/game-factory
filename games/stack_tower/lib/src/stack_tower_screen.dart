import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:game_core/game_core.dart';

import 'rules/stack_tower_rules.dart';

/// Best-score thresholds for 1, 2 and 3 stars on the Games tab tile (docs/SPEC.md, 4.5).
const List<int> stackStarScores = [200, 600, 1500];

const String _g = 'stack';

/// Stack tower: tap to drop the sliding block. Coin-locked in the hub (300 coins).
class StackTowerScreen extends StatelessWidget {
  const StackTowerScreen({super.key, this.onScore, this.random});
  final void Function(int score)? onScore;

  /// The random source of the starting side of each block; default a fresh `Random`.
  final Random? random;

  @override
  Widget build(BuildContext context) {
    return ArcadeFrame(
      id: _g,
      title: 'Stack tower',
      howTo:
          'Tap to drop the sliding block on the tower. Any overhang is cut '
          'off, so the tower gets narrower. A perfect drop keeps the width and '
          'builds a streak bonus. The tower speeds up as it grows.',
      starScores: stackStarScores,
      coinsPerPoints: 25,
      hasContinue: true,
      onScore: onScore,
      buildPlay: (context, run, round) => _StackPlay(
        key: ValueKey('stack.round.$round'),
        run: run,
        random: random ?? Random(),
      ),
    );
  }
}

class _StackPlay extends StatefulWidget {
  const _StackPlay({super.key, required this.run, required this.random});
  final ArcadeRun run;
  final Random random;

  @override
  State<_StackPlay> createState() => _StackPlayState();
}

class _StackPlayState extends State<_StackPlay>
    with SingleTickerProviderStateMixin {
  late final StackGame _game = StackGame(random: widget.random);
  late final Ticker _ticker = createTicker(_tick);
  final FixedStepper _stepper = FixedStepper(dt: stackStep);
  Duration _last = Duration.zero;
  String _note = '';

  @override
  void initState() {
    super.initState();
    widget.run.onContinue = _continue;
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _continue() {
    _game.grantContinue();
    _stepper.reset();
    _last = Duration.zero;
    _ticker
      ..stop()
      ..start();
    setState(() => _note = '');
  }

  void _tick(Duration t) {
    final dt = (t - _last).inMicroseconds / 1e6;
    _last = t;
    var n = _stepper.advance(dt);
    while (n-- > 0) {
      _game.step();
    }
    setState(() {});
  }

  void _drop() {
    if (_game.over) return;
    final landed = _game.drop();
    setState(() {
      _note = !landed
          ? 'Missed'
          : _game.streak > 0
          ? 'Perfect x${_game.streak}'
          : '';
    });
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
          text:
              'Score ${_game.score}   Height ${_game.height}   '
              'Streak ${_game.streak}',
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: AspectRatio(
                aspectRatio: 100 / 150,
                child: GestureDetector(
                  key: MindIds.arcade(_g, 'field'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _drop,
                  child: Semantics(
                    label:
                        'Stack tower, height ${_game.height}, score '
                        '${_game.score}. Tap to drop the block. $_note',
                    child: CustomPaint(
                      painter: _StackPainter(_game, pal),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            _note,
            key: MindIds.arcade(_g, 'note'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: FilledButton(
            key: MindIds.arcade(_g, 'drop'),
            onPressed: _drop,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text('Drop'),
            ),
          ),
        ),
      ],
    );
  }
}

class _StackPainter extends CustomPainter {
  _StackPainter(this.game, this.pal);
  final StackGame game;
  final ArcadePalette pal;

  static const double _bh = 6; // block height, world units

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / stackW;
    final sy = size.height / 150;
    canvas.drawRect(Offset.zero & size, Paint()..color = pal.background);
    // The camera keeps the sliding block near the upper third.
    final rise = max(0.0, (game.blocks.length + 1) * _bh - 90);
    double yOf(int i) => 150 - 6 - i * _bh + rise;
    void block(double x, double w, double y, Color c) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x * sx, y * sy, w * sx, (_bh - 0.6) * sy),
          const Radius.circular(2),
        ),
        Paint()..color = c,
      );
    }

    for (var i = 0; i < game.blocks.length; i++) {
      final b = game.blocks[i];
      block(b.x, b.width, yOf(i), i.isEven ? pal.primary : pal.accent);
    }
    if (!game.over) {
      block(game.x, game.width, yOf(game.blocks.length), pal.danger);
    } else if (game.lastCut != null) {
      final c = game.lastCut!;
      block(c.x, c.width, yOf(game.blocks.length), pal.danger);
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = pal.line,
    );
  }

  @override
  bool shouldRepaint(covariant _StackPainter old) => true;
}
