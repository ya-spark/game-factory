import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:game_core/game_core.dart';

import 'rules/snake_rules.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Best-score thresholds for 1, 2 and 3 stars on the Games tab tile (docs/SPEC.md, 4.2):
/// 5, 15 and 30 pieces of food.
const List<int> snakeStarScores = [50, 150, 300];

const String _g = 'snake';
const String _wrapKey = 'arcade.snake.wrap';

/// Snake: swipe or use the arrow buttons. Free with ads in the hub. One life.
class SnakeScreen extends StatefulWidget {
  const SnakeScreen({super.key, this.onScore, this.random, this.prefs});
  final void Function(int score)? onScore;

  /// The random source of the food; default a fresh `Random`. Injected in tests.
  final Random? random;
  final SharedPreferences? prefs;

  @override
  State<SnakeScreen> createState() => _SnakeScreenState();
}

class _SnakeScreenState extends State<SnakeScreen> {
  SharedPreferences? _prefs;
  bool _wrap = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = widget.prefs ?? await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _prefs = p;
      _wrap = p.getBool(_wrapKey) ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ArcadeFrame(
      id: _g,
      title: 'Snake',
      howTo:
          'Swipe to steer. Eat the food to grow. The snake speeds up as it '
          'grows. Do not hit the walls or yourself.',
      starScores: snakeStarScores,
      coinsPerPoints: 20,
      onScore: widget.onScore,
      prefs: widget.prefs,
      menuExtras: (context, changed) => ArcadeSwitch(
        key: MindIds.arcade(_g, 'wrap'),
        label: 'Walls wrap round',
        value: _wrap,
        onChanged: (v) {
          setState(() => _wrap = v);
          _prefs?.setBool(_wrapKey, v);
        },
      ),
      buildPlay: (context, run, round) => _SnakePlay(
        key: ValueKey('snake.round.$round'),
        run: run,
        wrap: _wrap,
        random: widget.random ?? Random(),
      ),
    );
  }
}

class _SnakePlay extends StatefulWidget {
  const _SnakePlay({
    super.key,
    required this.run,
    required this.wrap,
    required this.random,
  });
  final ArcadeRun run;
  final bool wrap;
  final Random random;

  @override
  State<_SnakePlay> createState() => _SnakePlayState();
}

class _SnakePlayState extends State<_SnakePlay>
    with SingleTickerProviderStateMixin {
  late final SnakeGame _game = SnakeGame(
    wrap: widget.wrap,
    random: widget.random,
  );
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  Offset _drag = Offset.zero;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration t) {
    final dt = ((t - _last).inMicroseconds / 1e6).clamp(0.0, 0.25);
    _last = t;
    if (_game.over) return;
    if (_game.update(dt) > 0) {
      setState(() {});
      if (_game.over) {
        _ticker.stop();
        widget.run.end(_game.score);
      }
    }
  }

  void _turn(SnakeDir d) => _game.turn(d);

  void _onPanUpdate(DragUpdateDetails d) {
    _drag += d.delta;
    if (_drag.distance < 24) return;
    if (_drag.dx.abs() > _drag.dy.abs()) {
      _turn(_drag.dx > 0 ? SnakeDir.right : SnakeDir.left);
    } else {
      _turn(_drag.dy > 0 ? SnakeDir.down : SnakeDir.up);
    }
    _drag = Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    final pal = ArcadePalette(context);
    return Column(
      children: [
        ArcadeHud(
          game: _g,
          text: 'Score ${_game.score}   Length ${_game.length}',
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: AspectRatio(
                aspectRatio: _game.cols / _game.rows,
                child: GestureDetector(
                  key: MindIds.arcade(_g, 'field'),
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => _drag = Offset.zero,
                  onPanUpdate: _onPanUpdate,
                  child: Semantics(
                    label:
                        'Snake field, length ${_game.length}, score '
                        '${_game.score}. Use the arrow buttons to steer.',
                    child: CustomPaint(
                      painter: _SnakePainter(_game, pal, _game.length),
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
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _arrow('left', Icons.arrow_back, SnakeDir.left),
              _arrow('up', Icons.arrow_upward, SnakeDir.up),
              _arrow('down', Icons.arrow_downward, SnakeDir.down),
              _arrow('right', Icons.arrow_forward, SnakeDir.right),
            ],
          ),
        ),
      ],
    );
  }

  Widget _arrow(String name, IconData icon, SnakeDir d) =>
      IconButton.filledTonal(
        key: MindIds.arcade(_g, name),
        tooltip: 'Turn $name',
        iconSize: 32,
        constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
        onPressed: () => _turn(d),
        icon: Icon(icon),
      );
}

class _SnakePainter extends CustomPainter {
  _SnakePainter(this.game, this.pal, this.version);
  final SnakeGame game;
  final ArcadePalette pal;
  final int version;

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / game.cols;
    final ch = size.height / game.rows;
    canvas.drawRect(Offset.zero & size, Paint()..color = pal.background);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = pal.line,
    );
    final f = game.food;
    if (f != null) {
      canvas.drawCircle(
        Offset((f.x + 0.5) * cw, (f.y + 0.5) * ch),
        min(cw, ch) * 0.38,
        Paint()..color = pal.accent,
      );
    }
    for (var i = 0; i < game.body.length; i++) {
      final c = game.body[i];
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(c.x * cw + 1, c.y * ch + 1, cw - 2, ch - 2),
        Radius.circular(min(cw, ch) * 0.25),
      );
      canvas.drawRRect(r, Paint()..color = i == 0 ? pal.danger : pal.primary);
    }
  }

  @override
  bool shouldRepaint(covariant _SnakePainter old) => true;
}
