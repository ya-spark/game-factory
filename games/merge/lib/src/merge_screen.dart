import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:game_core/game_core.dart';

import 'merge_ids.dart';
import 'rules/merge_rules.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Best-score thresholds for 1, 2 and 3 stars on the Games tab tile (docs/SPEC.md, 4.6).
const List<int> mergeStarScores = [1000, 3000, 6000];

const String _g = 'merge';

/// Background of each stage (light, so dark text has at least 4.5 to 1 on it).
const List<Color> stageColors = [
  Color(0xFFE8F5E9),
  Color(0xFFC8E6C9),
  Color(0xFFDCEDC8),
  Color(0xFFF0F4C3),
  Color(0xFFFFF9C4),
  Color(0xFFFFECB3),
  Color(0xFFFFE0B2),
  Color(0xFFFFCCBC),
  Color(0xFFF8BBD0),
  Color(0xFFE1BEE7),
  Color(0xFFD1C4E9),
  Color(0xFFB3E5FC),
];

enum _Phase { menu, play, result }

/// Merge: swipe the garden so that two plants of the same stage grow into the next one. Classic
/// ends when no move is left; Relaxed never ends. Coin-locked in the hub (300 coins).
class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key, this.onScore, this.random, this.prefs});

  /// Told the score after each move (the Games tab keeps the best one).
  final void Function(int score)? onScore;

  /// The random source of the spawns. Injected in tests.
  final Random? random;
  final SharedPreferences? prefs;

  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  late final Random _rnd = widget.random ?? Random();
  SharedPreferences? _prefs;
  _Phase _phase = _Phase.menu;
  MergeGame? _game;
  bool _relaxed = false;
  int _bestClassic = 0, _bestRelaxed = 0;
  Offset _drag = Offset.zero;

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
      _bestClassic = p.getInt('merge.best.classic') ?? 0;
      _bestRelaxed = p.getInt('merge.best.relaxed') ?? 0;
    });
  }

  void _start(bool relaxed) {
    final zen = ZenScope.of(context).zen; // Zen: always Relaxed (M5)
    setState(() {
      _relaxed = relaxed || zen;
      _game = MergeGame(_rnd, relaxed: _relaxed);
      _phase = _Phase.play;
    });
  }

  void _swipe(MergeDir d) {
    final g = _game!;
    setState(() {
      if (!g.swipe(d)) return;
      if (g.over) {
        RunReportScope.finished(
          context,
          g.score,
          RunExtras(variant: _relaxed ? 'Relaxed' : 'Classic'),
        );
      }
      widget.onScore?.call(g.score);
      if (!ZenScope.of(context).zen) _saveBest(g);
      if (g.over) _phase = _Phase.result;
    });
  }

  void _saveBest(MergeGame g) {
    if (_relaxed) {
      if (g.score > _bestRelaxed) {
        _bestRelaxed = g.score;
        _prefs?.setInt('merge.best.relaxed', g.score);
      }
    } else if (g.score > _bestClassic) {
      _bestClassic = g.score;
      _prefs?.setInt('merge.best.classic', g.score);
    }
  }

  // ---- keyboard (docs/SPEC.md, Keyboard): arrows slide, Enter or 1 and 2 start, Esc goes back ----

  void _onKey(GameInput i) {
    final a = i.action;
    switch (_phase) {
      case _Phase.menu:
        if (i.repeat) return;
        final zen = ZenScope.of(context).zen;
        if (a == GameAction.exit) {
          Navigator.of(context).maybePop();
        } else if (a == GameAction.action ||
            a == GameAction.pause ||
            a == GameAction.pick1) {
          _start(zen);
        } else if (a == GameAction.pick2) {
          _start(true);
        }
      case _Phase.play:
        switch (a) {
          case GameAction.left:
            _swipe(MergeDir.left);
          case GameAction.right:
            _swipe(MergeDir.right);
          case GameAction.up:
            _swipe(MergeDir.up);
          case GameAction.down:
            _swipe(MergeDir.down);
          case GameAction.exit when !i.repeat:
            setState(() => _phase = _Phase.menu);
          default:
        }
      case _Phase.result:
        if (i.repeat) return;
        if (a == GameAction.action || a == GameAction.pause) {
          _start(_relaxed);
        } else if (a == GameAction.exit) {
          setState(() => _phase = _Phase.menu);
        }
    }
  }

  List<GameAction> get _hints => switch (_phase) {
    _Phase.play => const [
      GameAction.left,
      GameAction.right,
      GameAction.up,
      GameAction.down,
      GameAction.exit,
    ],
    _ => const [GameAction.action, GameAction.exit],
  };

  void _panEnd() {
    final d = _drag;
    _drag = Offset.zero;
    if (max(d.dx.abs(), d.dy.abs()) < 24) return;
    if (d.dx.abs() > d.dy.abs()) {
      _swipe(d.dx > 0 ? MergeDir.right : MergeDir.left);
    } else {
      _swipe(d.dy > 0 ? MergeDir.down : MergeDir.up);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Merge'),
        leadingWidth: KeyedBackButton.width,
        leading: KeyedBackButton(
          key: MindIds.calmControl(_g, 'back'),
          onPressed: () {
            if (_phase == _Phase.play) {
              setState(() => _phase = _Phase.menu);
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: KeyedBody(
          onInput: _onKey,
          spaceGoesOn: _phase != _Phase.play,
          hints: _hints,
          shortcuts: {
            if (_phase == _Phase.play) ...{
              LogicalKeyboardKey.backspace: () {
                final g = _game;
                if (g != null && g.canUndo) setState(g.undo);
              },
              LogicalKeyboardKey.keyN: () => _start(_relaxed),
            },
          },
          extraHints: _phase == _Phase.play
              ? const [('Backspace', 'undo'), ('N', 'new garden')]
              : const [],
          words: const {
            GameAction.left: 'slide left / right',
            GameAction.up: 'slide up',
            GameAction.down: 'slide down',
          },
          child: switch (_phase) {
            _Phase.menu => _menu(context),
            _Phase.play => _play(context),
            _Phase.result => CalmResults(
              game: _g,
              title: _relaxed ? 'Garden finished' : 'No moves left',
              score: _game!.score,
              thresholds: mergeStarScores,
              detail:
                  'Best ${_relaxed ? _bestRelaxed : _bestClassic}. '
                  'Highest plant: ${_game!.highest == 0 ? 'none' : stageNames[_game!.highest - 1]}.',
              onAgain: () => _start(_relaxed),
              onDone: () => setState(() => _phase = _Phase.menu),
            ),
          },
        ),
      ),
    );
  }

  Widget _menu(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Swipe to slide every plant. Two plants of the same stage grow into the '
                'next stage, from Seed up to Garden.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              if (ZenScope.of(context).zen) ...[
                FilledButton(
                  key: MindIds.calmControl(_g, 'relaxed'),
                  onPressed: () => _start(true),
                  child: KeyedText('Play', GameAction.action, alsoSpace: true),
                ),
                const SizedBox(height: 12),
                Text(
                  'Zen: a garden that never ends. When it is stuck, the smallest '
                  'plants are cleared.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ] else ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      key: MindIds.calmControl(_g, 'classic'),
                      onPressed: () => _start(false),
                      child: Text(
                        withKey(
                          'Classic (best $_bestClassic)',
                          'Enter / Space / 1',
                        ),
                      ),
                    ),
                    FilledButton(
                      key: MindIds.calmControl(_g, 'relaxed'),
                      onPressed: () => _start(true),
                      child: Text(withKey('Relaxed (best $_bestRelaxed)', '2')),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Classic ends when no move is left. Relaxed never ends: when the garden '
                  'is stuck, the smallest plants are cleared.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        const CalmBanner(game: _g, placement: GameBannerSlot.menu),
      ],
    );
  }

  Widget _play(BuildContext context) {
    final g = _game!;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            children: [
              if (!ZenScope.of(context).zen)
                Text(
                  'Score ${g.score}, best ${_relaxed ? _bestRelaxed : _bestClassic}',
                  key: MindIds.calmControl(_g, 'score'),
                  style: theme.textTheme.titleMedium,
                ),
              if (_relaxed && g.clears > 0 && !ZenScope.of(context).zen)
                Text(
                  'Cleared the smallest plants ${g.clears} time${g.clears == 1 ? '' : 's'}.',
                ),
              const SizedBox(height: 12),
              GestureDetector(
                key: MindIds.calmControl(_g, 'board'),
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => _drag = Offset.zero,
                onPanUpdate: (d) => _drag += d.delta,
                onPanEnd: (_) => _panEnd(),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6D4C41),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: GridView.count(
                      crossAxisCount: mergeSize,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      children: [
                        for (var i = 0; i < g.cells.length; i++)
                          _cell(i, g.cells[i]),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final (d, name, icon) in const [
                    (MergeDir.up, 'up', Icons.arrow_upward),
                    (MergeDir.left, 'left', Icons.arrow_back),
                    (MergeDir.down, 'down', Icons.arrow_downward),
                    (MergeDir.right, 'right', Icons.arrow_forward),
                  ])
                    IconButton.outlined(
                      key: MindIds.calmControl(_g, name),
                      tooltip: 'Slide $name',
                      onPressed: () => _swipe(d),
                      icon: Icon(icon),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton(
                    key: MindIds.calmControl(_g, 'undo'),
                    onPressed: g.canUndo
                        ? () => setState(() => g.undo())
                        : null,
                    child: Text(withKey('Undo', 'Backspace')),
                  ),
                  OutlinedButton(
                    key: MindIds.calmControl(_g, 'restart'),
                    onPressed: () => _start(_relaxed),
                    child: Text(withKey('New garden', 'N')),
                  ),
                  if (_relaxed)
                    FilledButton(
                      key: MindIds.calmControl(_g, 'finish'),
                      onPressed: () => setState(() => _phase = _Phase.result),
                      child: const Text('Finish'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(int i, int stage) {
    return Semantics(
      label: stage == 0
          ? 'Empty'
          : '${stageNames[stage - 1]}, stage $stage, ${pointsForStage(stage)}',
      excludeSemantics: true,
      child: Container(
        key: MergeIds.mergeCell(i),
        decoration: BoxDecoration(
          color: stage == 0 ? const Color(0xFFBCAAA4) : stageColors[stage - 1],
          borderRadius: BorderRadius.circular(8),
        ),
        child: stage == 0
            ? null
            : Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: PlantPainter(stage)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: FittedBox(
                      child: Text(
                        '${pointsForStage(stage)}',
                        style: const TextStyle(
                          color: Color(0xFF1B1B1B),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// A plant: a ring of petals, one more for each stage (up to 12), around the centre, drawn behind
/// the number in a soft ink so the number stays readable.
class PlantPainter extends CustomPainter {
  PlantPainter(this.stage);
  final int stage;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final paint = Paint()..color = const Color(0x332E7D32);
    final n = stage + 2;
    for (var k = 0; k < n; k++) {
      final a = 2 * pi * k / n;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(a);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, -r * 0.55),
          width: r * 0.4,
          height: r * 0.7,
        ),
        paint,
      );
      canvas.restore();
    }
    canvas.drawCircle(c, r * 0.28, Paint()..color = const Color(0x33F57F17));
  }

  @override
  bool shouldRepaint(PlantPainter old) => old.stage != stage;
}
