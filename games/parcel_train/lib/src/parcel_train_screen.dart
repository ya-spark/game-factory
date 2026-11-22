import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:game_core/game_core.dart';

import 'rules/parcel_train_rules.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Best-score thresholds for 1, 2 and 3 stars on the Games tab tile (docs/SPEC.md, 4.2):
/// 5, 15 and 30 pieces of food.
const List<int> trainStarScores = [50, 150, 300];

const String _g = 'parcel_train';
const String _wrapKey = 'arcade.parcel_train.wrap';

/// Parcel train: swipe or use the arrow buttons. Free with ads in the hub. One life.
class ParcelTrainScreen extends StatefulWidget {
  const ParcelTrainScreen({super.key, this.onScore, this.random, this.prefs});
  final void Function(int score)? onScore;

  /// The random source of the food; default a fresh `Random`. Injected in tests.
  final Random? random;
  final SharedPreferences? prefs;

  @override
  State<ParcelTrainScreen> createState() => _ParcelTrainScreenState();
}

class _ParcelTrainScreenState extends State<ParcelTrainScreen> {
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
      title: 'Parcel train',
      howTo:
          'Swipe to steer. Pick up parcels to add wagons. The train speeds up as it '
          'grows. Do not hit the walls or your wagons.',
      starScores: trainStarScores,
      hintActions: const [
        GameAction.left,
        GameAction.up,
        GameAction.down,
        GameAction.right,
      ],
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
      buildPlay: (context, run, round) => _TrainPlay(
        key: ValueKey('parcel_train.round.$round'),
        run: run,
        wrap: _wrap,
        random: widget.random ?? Random(),
      ),
    );
  }
}

class _TrainPlay extends StatefulWidget {
  const _TrainPlay({
    super.key,
    required this.run,
    required this.wrap,
    required this.random,
  });
  final ArcadeRun run;
  final bool wrap;
  final Random random;

  @override
  State<_TrainPlay> createState() => _TrainPlayState();
}

class _TrainPlayState extends State<_TrainPlay>
    with SingleTickerProviderStateMixin {
  late final TrainGame _game = TrainGame(
    wrap: widget.wrap,
    random: widget.random,
  );
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  Offset _drag = Offset.zero;

  @override
  void initState() {
    super.initState();
    widget.run.onInput = _onKey;
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

  void _turn(TrainDir d) => _game.turn(d);

  /// The arrows (and W A S D) steer (docs/KEYBOARD.md).
  void _onKey(GameInput i) {
    switch (i.action) {
      case GameAction.left:
        _turn(TrainDir.left);
      case GameAction.right:
        _turn(TrainDir.right);
      case GameAction.up:
        _turn(TrainDir.up);
      case GameAction.down:
        _turn(TrainDir.down);
      default:
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    _drag += d.delta;
    if (_drag.distance < 24) return;
    if (_drag.dx.abs() > _drag.dy.abs()) {
      _turn(_drag.dx > 0 ? TrainDir.right : TrainDir.left);
    } else {
      _turn(_drag.dy > 0 ? TrainDir.down : TrainDir.up);
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
                        'Parcel train field, length ${_game.length}, score '
                        '${_game.score}. Use the arrow buttons to steer.',
                    child: CustomPaint(
                      painter: _TrainPainter(_game, pal, _game.length),
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
              _arrow('left', Icons.arrow_back, TrainDir.left),
              _arrow('up', Icons.arrow_upward, TrainDir.up),
              _arrow('down', Icons.arrow_downward, TrainDir.down),
              _arrow('right', Icons.arrow_forward, TrainDir.right),
            ],
          ),
        ),
      ],
    );
  }

  Widget _arrow(String name, IconData icon, TrainDir d) =>
      IconButton.filledTonal(
        key: MindIds.arcade(_g, name),
        tooltip: 'Turn $name',
        iconSize: 32,
        constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
        onPressed: () => _turn(d),
        icon: Icon(icon),
      );
}

class _TrainPainter extends CustomPainter {
  _TrainPainter(this.game, this.pal, this.version);
  final TrainGame game;
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
  bool shouldRepaint(covariant _TrainPainter old) => true;
}
