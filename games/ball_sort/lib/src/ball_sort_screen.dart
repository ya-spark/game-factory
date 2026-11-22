import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:game_core/game_core.dart';

import 'ball_sort_ids.dart';

import 'ball_sort_daily.dart';
import 'rules/ball_sort_rules.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Best-score thresholds for 1, 2 and 3 stars on the Games tab tile (docs/SPEC.md, 4.4).
const List<int> ballSortStarScores = [300, 500, 700];

const String _g = 'ballsort';

/// Colour, name and pattern of each ball colour. The pattern is a second cue besides the colour,
/// for colour-blind players.
class BallStyle {
  const BallStyle(this.color, this.name, this.pattern);
  final Color color;
  final String name;
  final int pattern;
}

const List<BallStyle> ballStyles = [
  BallStyle(Color(0xFFC62828), 'red', 0), // solid
  BallStyle(Color(0xFF1565C0), 'blue', 1), // horizontal stripes
  BallStyle(Color(0xFF2E7D32), 'green', 2), // dots
  BallStyle(Color(0xFFEF6C00), 'orange', 3), // vertical stripes
  BallStyle(Color(0xFF6A1B9A), 'purple', 4), // cross
  BallStyle(Color(0xFFF9A825), 'yellow', 5), // diagonal stripes
  BallStyle(Color(0xFF00838F), 'teal', 6), // ring
  BallStyle(Color(0xFFEC407A), 'pink', 7), // checker
  BallStyle(Color(0xFF5D4037), 'brown', 8), // triangle
  BallStyle(Color(0xFF607D8B), 'grey', 9), // diamond
];

enum _Phase { menu, play, result }

/// Ball sort: calm and untimed. Levels are generated from a seed and proven solvable. The level
/// reached is kept on the device. Coin-locked in the hub (300 coins).
class BallSortScreen extends StatefulWidget {
  const BallSortScreen({
    super.key,
    this.onScore,
    this.randomFor,
    this.prefs,
    this.firstLevel,
    this.daily,
  });

  /// The daily puzzle: starts straight in the level of the day (no menu, level progress kept).
  final DailyRun? daily;

  /// Told the score of each solved level (the Games tab keeps the best one).
  final void Function(int score)? onScore;

  /// The random source of a level; default `Random(seedForLevel(level))`. Injected in tests.
  final Random Function(int level)? randomFor;
  final SharedPreferences? prefs;

  /// For tests: the first game is this state instead of a generated level.
  final BallSortState? firstLevel;

  @override
  State<BallSortScreen> createState() => _BallSortScreenState();
}

class _BallSortScreenState extends State<BallSortScreen> {
  SharedPreferences? _prefs;
  _Phase _phase = _Phase.menu;
  BallSortGame? _game;
  int _level = 1;
  int? _selected;

  /// The tube under the keyboard cursor; shown once a key has been used.
  int _cursor = 0;
  bool _keyed = false;
  String? _message;
  bool _firstUsed = false;

  ActiveSeconds? _clock;
  int _mistakes = 0;

  @override
  void initState() {
    super.initState();
    final d = widget.daily;
    if (d != null) {
      _clock = ActiveSeconds(base: d.initialSeconds);
      _mistakes = d.initialMistakes;
      _start(ballSortDailyLevels[d.tier], init: true);
    }
    _load();
  }

  @override
  void dispose() {
    _clock?.dispose();
    super.dispose();
  }

  void _leaveDaily() {
    if (_phase == _Phase.play) {
      widget.daily?.onProgress?.call(_clock!.seconds, _mistakes);
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _load() async {
    final p = widget.prefs ?? await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _prefs = p;
      if (widget.daily == null) {
        _level = max(1, p.getInt('ballsort.level') ?? 1);
      }
    });
  }

  void _start(int level, {bool init = false}) {
    BallSortState s;
    final first = _firstUsed ? null : widget.firstLevel;
    _firstUsed = true;
    if (first != null) {
      s = first.copy();
    } else {
      final d = widget.daily;
      final rnd =
          widget.randomFor?.call(level) ??
          Random(d?.seed ?? seedForLevel(level));
      s = generateBallSort(level, rnd).state;
    }
    void apply() {
      _level = level;
      _game = BallSortGame(s, level: level);
      _selected = null;
      _cursor = 0;
      _message = null;
      _phase = _Phase.play;
    }

    // From initState there is nothing to rebuild yet.
    if (init) {
      apply();
    } else {
      setState(apply);
    }
  }

  void _tap(int t) {
    final g = _game!;
    final sel = _selected;
    setState(() {
      _message = null;
      if (sel == null) {
        if (g.state.tubes[t].isNotEmpty) _selected = t;
        return;
      }
      if (sel == t) {
        _selected = null;
        return;
      }
      if (g.move(sel, t) > 0) {
        _selected = null;
        if (g.state.solved) _won();
        return;
      }
      if (g.state.tubes[t].isNotEmpty) {
        _selected = t;
      } else {
        _selected = null;
      }
      _message = 'That ball does not fit there.';
      _mistakes++;
    });
  }

  // ---- keyboard (docs/SPEC.md, Keyboard): left and right move over the tubes, Enter or up lifts and drops,
  // 1 to 9 pick a tube, Esc goes back ----

  void _onKey(GameInput i) {
    final a = i.action;
    switch (_phase) {
      case _Phase.menu:
        if (i.repeat) return;
        if (a == GameAction.exit) {
          Navigator.of(context).maybePop();
        } else if (a == GameAction.action ||
            a == GameAction.pause ||
            a == GameAction.pick1) {
          _start(_level);
        }
      case _Phase.play:
        final n = _game!.state.tubes.length;
        if (a == GameAction.left || a == GameAction.right) {
          setState(() {
            _keyed = true;
            _cursor = (_cursor + (a == GameAction.left ? -1 : 1)) % n;
          });
        } else if (i.repeat) {
          return;
        } else if (a == GameAction.action || a == GameAction.up) {
          setState(() => _keyed = true);
          _tap(_cursor.clamp(0, n - 1));
        } else if (a.pickNumber != null && a.pickNumber! <= n) {
          setState(() {
            _keyed = true;
            _cursor = a.pickNumber! - 1;
          });
          _tap(_cursor);
        } else if (a == GameAction.exit) {
          if (widget.daily != null) {
            _leaveDaily();
          } else {
            setState(() => _phase = _Phase.menu);
          }
        }
      case _Phase.result:
        if (i.repeat) return;
        if (a == GameAction.action || a == GameAction.pause) {
          widget.daily != null ? _leaveDaily() : _start(_level);
        } else if (a == GameAction.exit) {
          widget.daily != null
              ? _leaveDaily()
              : setState(() => _phase = _Phase.menu);
        }
    }
  }

  /// Fixed keys that sit on the buttons: Backspace undo, T add a tube, R restart (menu: start from level 1).
  KeyShortcuts get _shortcuts => {
    LogicalKeyboardKey.keyR: () {
      if (_phase == _Phase.play) {
        _start(_game!.level);
      } else if (_phase == _Phase.menu && _level > 1) {
        _prefs?.setInt('ballsort.level', 1);
        _start(1);
      }
    },
    if (_phase == _Phase.play) ...{
      LogicalKeyboardKey.backspace: () {
        final g = _game!;
        if (g.canUndo) {
          setState(() {
            g.undo();
            _selected = null;
          });
        }
      },
      LogicalKeyboardKey.keyT: () {
        final g = _game!;
        if (g.state.canAddTube) {
          setState(() {
            g.addTube();
            _selected = null;
          });
        }
      },
    },
  };

  List<GameAction> get _hints => switch (_phase) {
    _Phase.play => const [
      GameAction.left,
      GameAction.right,
      GameAction.action,
      GameAction.exit,
    ],
    _ => const [GameAction.action, GameAction.exit],
  };

  void _won() {
    final g = _game!;
    RunReportScope.finished(
      context,
      g.score,
      RunExtras(won: true, mistakes: _mistakes, seconds: _clock?.seconds),
    );
    widget.onScore?.call(g.score);
    if (widget.daily == null) {
      _level = g.level + 1;
      _prefs?.setInt('ballsort.level', _level);
    }
    widget.daily?.onSolved?.call(_clock!.seconds, _mistakes);
    _phase = _Phase.result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ball sort'),
        leadingWidth: KeyedBackButton.width,
        leading: KeyedBackButton(
          key: MindIds.calmControl(_g, 'back'),
          onPressed: () {
            if (widget.daily != null) {
              _leaveDaily();
            } else if (_phase == _Phase.play) {
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
          shortcuts: _shortcuts,
          extraHints: switch (_phase) {
            _Phase.menu when _level > 1 => const [('R', 'level 1')],
            _Phase.play => const [
              ('Backspace', 'undo'),
              ('T', 'tube'),
              ('R', 'restart'),
            ],
            _ => const [],
          },
          child: switch (_phase) {
            _Phase.menu => _menu(context),
            _Phase.play => _play(context),
            _Phase.result => CalmResults(
              game: _g,
              title: 'Level ${_game!.level} sorted',
              score: _game!.score,
              thresholds: ballSortStarScores,
              detail: '${_game!.state.moves} moves',
              againLabel: widget.daily != null ? 'Back to Games' : 'Next level',
              onAgain: widget.daily != null
                  ? _leaveDaily
                  : () => _start(_level),
              onDone: widget.daily != null
                  ? _leaveDaily
                  : () => setState(() => _phase = _Phase.menu),
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
                'Sort the balls so each tube holds one colour.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    key: MindIds.calmControl(_g, 'play'),
                    onPressed: () => _start(_level),
                    child: Text(
                      keyedLabel(
                        context,
                        'Play level $_level',
                        GameAction.action,
                        alsoSpace: true,
                      ),
                    ),
                  ),
                  if (_level > 1)
                    OutlinedButton(
                      key: MindIds.calmControl(_g, 'reset'),
                      onPressed: () {
                        _prefs?.setInt('ballsort.level', 1);
                        _start(1);
                      },
                      child: Text(withKey('Start from level 1', 'R')),
                    ),
                ],
              ),
            ],
          ),
        ),
        const CalmBanner(game: _g, placement: GameBannerSlot.menu),
      ],
    );
  }

  String _describe(int t, List<int> tube) {
    if (tube.isEmpty) return 'Tube ${t + 1}, empty';
    final names = [for (final b in tube) ballStyles[b].name];
    return 'Tube ${t + 1}, ${names.join(', ')}, top ${names.last}';
  }

  Widget _play(BuildContext context) {
    final g = _game!;
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              Text(
                ZenScope.of(context).zen
                    ? 'Level ${g.level}'
                    : 'Level ${g.level}, moves ${g.state.moves}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  for (var t = 0; t < g.state.tubes.length; t++)
                    _tube(scheme, t, g.state.tubes[t]),
                ],
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _message!,
                    key: MindIds.calmControl(_g, 'message'),
                  ),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton(
                    key: MindIds.calmControl(_g, 'undo'),
                    onPressed: g.canUndo
                        ? () => setState(() {
                            g.undo();
                            _selected = null;
                          })
                        : null,
                    child: Text(withKey('Undo', 'Backspace')),
                  ),
                  OutlinedButton(
                    key: MindIds.calmControl(_g, 'addtube'),
                    onPressed: g.state.canAddTube
                        ? () => setState(() {
                            g.addTube();
                            _selected = null;
                          })
                        : null,
                    child: Text(
                      g.state.added
                          ? 'Tube added'
                          : withKey('Add a tube (once)', 'T'),
                    ),
                  ),
                  OutlinedButton(
                    key: MindIds.calmControl(_g, 'restart'),
                    onPressed: () => _start(g.level),
                    child: Text(withKey('Restart level', 'R')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tube(ColorScheme scheme, int t, List<int> tube) {
    const ball = 40.0;
    final selected = _selected == t;
    return Semantics(
      button: true,
      selected: selected,
      label: _describe(t, tube),
      excludeSemantics: true,
      child: GestureDetector(
        key: BallSortIds.ballSortTube(t),
        behavior: HitTestBehavior.opaque,
        onTap: () => _tap(t),
        child: Transform.translate(
          offset: Offset(0, selected ? -8 : 0),
          child: Container(
            width: ball + 20,
            height: ball * tubeCapacity + 20,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
                top: Radius.circular(6),
              ),
              border: Border.all(
                color: selected
                    ? scheme.primary
                    : (_keyed && _cursor == t)
                    ? scheme.tertiary
                    : scheme.outline,
                width: selected || (_keyed && _cursor == t) ? 4 : 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (final b in tube.reversed)
                  SizedBox(
                    width: ball,
                    height: ball,
                    child: CustomPaint(
                      key: Key('ballsort.ball.$b'),
                      painter: BallPainter(b, scheme.onSurface),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A ball: its colour plus a pattern in a contrasting ink, inside a dark outline.
class BallPainter extends CustomPainter {
  BallPainter(this.colour, this.outline);
  final int colour;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final style = ballStyles[colour % ballStyles.length];
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 2;
    final circle = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    canvas.drawPath(circle, Paint()..color = style.color);
    canvas.save();
    canvas.clipPath(circle);
    final ink = style.color.computeLuminance() > 0.35
        ? const Color(0xFF111111)
        : Colors.white;
    final p = Paint()
      ..color = ink
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final f = Paint()..color = ink;
    final left = c.dx - r, top = c.dy - r, d = r * 2;
    switch (style.pattern) {
      case 1:
        for (var k = 1; k < 4; k++) {
          canvas.drawLine(
            Offset(left, top + d * k / 4),
            Offset(left + d, top + d * k / 4),
            p,
          );
        }
      case 2:
        for (final o in const [
          Offset(-0.4, -0.4),
          Offset(0.4, -0.4),
          Offset(0, 0),
          Offset(-0.4, 0.4),
          Offset(0.4, 0.4),
        ]) {
          canvas.drawCircle(c + o * r, 2.6, f);
        }
      case 3:
        for (var k = 1; k < 4; k++) {
          canvas.drawLine(
            Offset(left + d * k / 4, top),
            Offset(left + d * k / 4, top + d),
            p,
          );
        }
      case 4:
        canvas.drawLine(Offset(left, c.dy), Offset(left + d, c.dy), p);
        canvas.drawLine(Offset(c.dx, top), Offset(c.dx, top + d), p);
      case 5:
        for (var k = -1; k <= 1; k++) {
          canvas.drawLine(
            Offset(left, top + d / 2 + k * d / 3),
            Offset(left + d, top + d / 2 + k * d / 3 - d),
            p,
          );
        }
      case 6:
        canvas.drawCircle(c, r * 0.5, p);
      case 7:
        final q = d / 4;
        for (var i = 0; i < 4; i++) {
          for (var j = 0; j < 4; j++) {
            if ((i + j).isEven) {
              canvas.drawRect(
                Rect.fromLTWH(left + i * q, top + j * q, q, q),
                f,
              );
            }
          }
        }
      case 8:
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - r * 0.5)
            ..lineTo(c.dx + r * 0.5, c.dy + r * 0.4)
            ..lineTo(c.dx - r * 0.5, c.dy + r * 0.4)
            ..close(),
          f,
        );
      case 9:
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - r * 0.5)
            ..lineTo(c.dx + r * 0.5, c.dy)
            ..lineTo(c.dx, c.dy + r * 0.5)
            ..lineTo(c.dx - r * 0.5, c.dy)
            ..close(),
          f,
        );
      default:
        break;
    }
    canvas.restore();
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(BallPainter old) =>
      old.colour != colour || old.outline != outline;
}
