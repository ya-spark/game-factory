import 'dart:math';

import 'package:flutter/material.dart';

import 'package:game_core/game_core.dart';

import 'mahjong_ids.dart';

import 'mahjong_daily.dart';
import 'rules/mahjong_rules.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Best-score thresholds for 1, 2 and 3 stars on the Games tab tile (docs/SPEC.md, 4.5).
const List<int> mahjongStarScores = [300, 500, 700];

const String _g = 'mahjong';

/// Names of the four suits, each with its own shape and ink colour (original, not mahjong art).
const List<String> suitNames = ['Ember', 'Leaf', 'Wave', 'Star'];
const List<Color> _suitInk = [
  Color(0xFFB71C1C),
  Color(0xFF1B5E20),
  Color(0xFF0D47A1),
  Color(0xFF4A148C),
];

String faceName(int face) => '${suitNames[suitOf(face)]} ${rankOf(face)}';

enum _Phase { menu, play, result }

/// Mahjong solitaire: calm and untimed. Take free matching pairs off the layout. Free with ads.
class MahjongScreen extends StatefulWidget {
  const MahjongScreen({
    super.key,
    this.onScore,
    this.random,
    this.daily,
    this.prefs,
  });

  /// For tests: the saved menu choices (tier, Hints switch).
  final SharedPreferences? prefs;

  /// The daily puzzle: starts straight in the layout of the day (no menu).
  final DailyRun? daily;

  /// Told the score of each cleared table (the Games tab keeps the best one).
  final void Function(int score)? onScore;

  /// The random source of the deals. Injected in tests.
  final Random? random;

  @override
  State<MahjongScreen> createState() => _MahjongScreenState();
}

class _MahjongScreenState extends State<MahjongScreen> {
  late final Random _rnd =
      widget.random ??
      (widget.daily == null ? Random() : Random(widget.daily!.seed));
  ActiveSeconds? _clock;
  int _mistakes = 0;
  _Phase _phase = _Phase.menu;
  MahjongGame? _game;
  int _layout = 0;
  MahjongTier _tier = MahjongTier.easy;
  bool _hintsOn = true;
  SharedPreferences? _prefs;
  int? _selected;

  /// The tile under the keyboard cursor; shown once a key has been used.
  int? _cursor;
  bool _keyed = false;
  (int, int)? _hint;
  String? _message;

  @override
  void initState() {
    super.initState();
    final d = widget.daily;
    if (d != null) {
      _clock = ActiveSeconds(base: d.initialSeconds);
      _mistakes = d.initialMistakes;
      _tier = mahjongDailyTiers[d.tier];
      final layout = mahjongLayoutsOf(_tier)[mahjongDailyRank[d.tier]];
      _layout = _tier.layouts.indexOf(layout);
      _game = MahjongGame(layout, Random(d.seed), tier: _tier);
      _phase = _Phase.play;
    }
    _load();
  }

  Future<void> _load() async {
    final p = widget.prefs ?? await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _prefs = p;
      _hintsOn = p.getBool('mahjong.hints') ?? true;
      if (widget.daily == null) {
        _tier = MahjongTier.byName(p.getString('mahjong.tier')) ?? _tier;
      }
    });
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

  void _start(int layout) {
    setState(() {
      _layout = layout;
      _game = MahjongGame(_tier.layouts[layout], _rnd, tier: _tier);
      _selected = null;
      _cursor = null;
      _hint = null;
      _message = null;
      _phase = _Phase.play;
    });
  }

  // ---- keyboard (docs/SPEC.md, Keyboard): arrows step over the free tiles, Enter takes or drops the tile,
  // 1 hint, 2 undo, 3 shuffle, Esc goes back ----

  /// The free tiles in reading order (top to bottom, left to right, lowest layer first).
  List<int> _freeTiles(MahjongGame g) {
    final pos = g.positions;
    final l = [
      for (var i = 0; i < pos.length; i++)
        if (!g.removed(i) && g.isFree(i)) i,
    ];
    l.sort((a, b) {
      final pa = pos[a], pb = pos[b];
      final c = pa.y.compareTo(pb.y);
      if (c != 0) return c;
      final d = pa.x.compareTo(pb.x);
      return d != 0 ? d : pa.z.compareTo(pb.z);
    });
    return l;
  }

  void _step(int dir) {
    final g = _game!;
    final free = _freeTiles(g);
    if (free.isEmpty) return;
    final at = _cursor == null ? -1 : free.indexOf(_cursor!);
    final next = at < 0
        ? (dir > 0 ? 0 : free.length - 1)
        : (at + dir) % free.length;
    setState(() {
      _keyed = true;
      _cursor = free[next];
    });
  }

  void _onKey(GameInput i) {
    final a = i.action;
    switch (_phase) {
      case _Phase.menu:
        if (i.repeat) return;
        if (a == GameAction.exit) {
          Navigator.of(context).maybePop();
        } else if (a == GameAction.action || a.pickNumber != null) {
          final n = (a.pickNumber ?? 1) - 1;
          if (n < _tier.layouts.length) _start(n);
        }
      case _Phase.play:
        final g = _game!;
        switch (a) {
          case GameAction.left || GameAction.up:
            _step(-1);
          case GameAction.right || GameAction.down:
            _step(1);
          case GameAction.action when !i.repeat:
            final c = _cursor;
            if (c == null || g.removed(c)) {
              _step(1);
            } else {
              setState(() => _keyed = true);
              _tap(c);
            }
          case GameAction.pick1 when !i.repeat && _hintsOn && g.canHint:
            setState(() {
              _selected = null;
              _hint = g.hint();
              _message = _hint == null ? 'No pairs left. Use Shuffle.' : null;
            });
          case GameAction.pick2 when !i.repeat && g.canUndo:
            setState(() {
              g.undo();
              _selected = null;
              _hint = null;
            });
          case GameAction.pick3 when !i.repeat && g.canShuffle:
            setState(() {
              g.shuffle();
              _selected = null;
              _hint = null;
              _cursor = null;
              _message = 'Tiles shuffled.';
            });
          case GameAction.exit when !i.repeat:
            _leave();
          default:
        }
      case _Phase.result:
        if (i.repeat) return;
        if (a == GameAction.action) {
          widget.daily != null ? _leaveDaily() : _start(_layout);
        } else if (a == GameAction.exit) {
          _leave();
        }
    }
  }

  /// Back: the daily leaves, a game goes to the menu, the menu leaves.
  void _leave() {
    if (widget.daily != null) {
      _leaveDaily();
    } else if (_phase == _Phase.menu) {
      Navigator.of(context).maybePop();
    } else {
      setState(() => _phase = _Phase.menu);
    }
  }

  void _tap(int i) {
    final g = _game!;
    setState(() {
      _hint = null;
      _message = null;
      if (g.removed(i)) return;
      if (!g.isFree(i)) {
        _selected = null;
        _message = 'That tile is blocked.';
        return;
      }
      final sel = _selected;
      if (sel == null) {
        _selected = i;
      } else if (sel == i) {
        _selected = null;
      } else if (g.take(sel, i)) {
        _selected = null;
        if (g.won) {
          RunReportScope.finished(
            context,
            g.score,
            RunExtras(
              won: true,
              mistakes: _mistakes,
              hints: g.hints,
              variant: _tier.label,
              seconds: _clock?.seconds,
            ),
          );
          widget.onScore?.call(g.score);
          widget.daily?.onSolved?.call(_clock!.seconds, _mistakes);
          _phase = _Phase.result;
        } else if (g.stuck) {
          _message = 'No pairs left. Use Shuffle.';
        }
      } else {
        _selected = i;
        _message = 'Those tiles do not match.';
        _mistakes++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mahjong solitaire'),
        leading: BackButton(
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
          hints: _phase == _Phase.play
              ? const [
                  GameAction.left,
                  GameAction.right,
                  GameAction.action,
                  GameAction.exit,
                ]
              : const [GameAction.action, GameAction.exit],
          child: switch (_phase) {
            _Phase.menu => _menu(context),
            _Phase.play => _play(context),
            _Phase.result => CalmResults(
              game: _g,
              title: '${_game!.layout.name} cleared',
              score: _game!.score,
              thresholds: mahjongStarScores,
              detail: '${_game!.hints} hints, ${_game!.shuffles} shuffles',
              againLabel: widget.daily != null ? 'Back to Games' : 'Play again',
              onAgain: widget.daily != null
                  ? _leaveDaily
                  : () => _start(_layout),
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
                'Take off pairs of matching free tiles. A tile is free when nothing '
                'lies on it and its left or right side is open. Pick a level and a layout.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final t in MahjongTier.values)
                    ChoiceChip(
                      key: MindIds.calmControl(_g, 'tier.${t.name}'),
                      label: Text(t.label),
                      selected: _tier == t,
                      onSelected: (_) {
                        setState(() => _tier = t);
                        _prefs?.setString('mahjong.tier', t.name);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                ZenScope.of(context).zen
                    ? 'Hints: unlimited, shuffles: unlimited'
                    : 'Hints: ${_tier.hintLimit ?? 'unlimited'}, '
                          'shuffles: ${_tier.shuffleLimit ?? 'unlimited'}',
                key: MindIds.calmControl(_g, 'tier.note'),
              ),
              SwitchListTile(
                key: MindIds.calmControl(_g, 'hints'),
                title: const Text('Hints'),
                subtitle: const Text('Show the Hint button'),
                value: _hintsOn,
                onChanged: (v) {
                  setState(() => _hintsOn = v);
                  _prefs?.setBool('mahjong.hints', v);
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < _tier.layouts.length; i++)
                    FilledButton(
                      key: MindIds.calmLevel(_g, '$i'),
                      onPressed: () => _start(i),
                      child: Text(
                        '${_tier.layouts[i].name} (${_tier.layouts[i].positions.length})',
                      ),
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

  Widget _play(BuildContext context) {
    final g = _game!;
    g.unlimited = ZenScope.of(context).zen; // Zen: free hints and shuffles (M5)
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            '${g.layout.name}, ${g.remaining} tiles left',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(child: LayoutBuilder(builder: (c, box) => _board(box, g))),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.all(4),
            child: Text(_message!, key: MindIds.calmControl(_g, 'message')),
          ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
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
                        _hint = null;
                      })
                    : null,
                child: const Text('Undo'),
              ),
              if (_hintsOn)
                OutlinedButton(
                  key: MindIds.calmControl(_g, 'hint'),
                  onPressed: g.canHint
                      ? () => setState(() {
                          _selected = null;
                          _hint = g.hint();
                          _message = _hint == null
                              ? 'No pairs left. Use Shuffle.'
                              : null;
                        })
                      : null,
                  child: Text(
                    g.hintsLeft == null ? 'Hint' : 'Hint (${g.hintsLeft})',
                  ),
                ),
              OutlinedButton(
                key: MindIds.calmControl(_g, 'shuffle'),
                onPressed: !g.canShuffle
                    ? null
                    : () => setState(() {
                        g.shuffle();
                        _selected = null;
                        _hint = null;
                        _message = 'Tiles shuffled.';
                      }),
                child: Text(
                  g.shufflesLeft == null
                      ? 'Shuffle'
                      : 'Shuffle (${g.shufflesLeft})',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _board(BoxConstraints box, MahjongGame g) {
    final l = g.layout;
    const lift = 4.0;
    final unitW = (box.maxWidth - 16 - l.maxZ * lift) / (l.maxX + 2);
    final unitH = (box.maxHeight - 16 - l.maxZ * lift) / (l.maxY + 2);
    // A tile is never smaller than 40 dp: a bigger layout scrolls instead.
    final unit = max(min(min(unitW, unitH), 30.0), 20.0);
    final w = (l.maxX + 2) * unit + l.maxZ * lift;
    final h = (l.maxY + 2) * unit + l.maxZ * lift;
    final order = List.generate(g.faces.length, (i) => i)
      ..sort((a, b) {
        final pa = g.positions[a], pb = g.positions[b];
        final c = pa.z.compareTo(pb.z);
        if (c != 0) return c;
        final d = pa.y.compareTo(pb.y);
        return d != 0 ? d : pa.x.compareTo(pb.x);
      });
    final scheme = Theme.of(context).colorScheme;
    final board = SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          for (final i in order)
            if (!g.removed(i))
              Positioned(
                left: g.positions[i].x * unit + g.positions[i].z * lift,
                top:
                    g.positions[i].y * unit -
                    g.positions[i].z * lift +
                    l.maxZ * lift,
                width: unit * 2,
                height: unit * 2,
                child: _tile(g, i, scheme),
              ),
        ],
      ),
    );
    if (w <= box.maxWidth && h <= box.maxHeight) return Center(child: board);
    // Too big for the screen at 40 dp tiles: scroll both ways.
    return SingleChildScrollView(
      key: MindIds.calmControl(_g, 'board.scroll'),
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(child: board),
    );
  }

  Widget _tile(MahjongGame g, int i, ColorScheme scheme) {
    final free = g.isFree(i);
    final selected = _selected == i;
    final hinted = _hint != null && (_hint!.$1 == i || _hint!.$2 == i);
    final cursor = _keyed && _cursor == i;
    final state = selected
        ? 'selected'
        : hinted
        ? 'hint'
        : free
        ? 'free'
        : 'blocked';
    return Semantics(
      button: true,
      selected: selected,
      label: '${faceName(g.faces[i])}, $state',
      excludeSemantics: true,
      child: GestureDetector(
        key: MahjongIds.mahjongTile(i),
        behavior: HitTestBehavior.opaque,
        onTap: () => _tap(i),
        child: Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: free ? const Color(0xFFFFF8E1) : const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : hinted
                  ? const Color(0xFFE65100)
                  : cursor
                  ? scheme.tertiary
                  : const Color(0xFF424242),
              width: selected || hinted || cursor ? 3.5 : 1.2,
            ),
          ),
          child: CustomPaint(painter: TileFacePainter(g.faces[i])),
        ),
      ),
    );
  }
}

/// The face of a tile: the suit's shape drawn as many times as the rank (1 to 6), in the suit's
/// ink. Shapes: Ember (flame-like drop), Leaf, Wave and Star.
class TileFacePainter extends CustomPainter {
  TileFacePainter(this.face);
  final int face;

  static const _pips = <int, List<Offset>>{
    1: [Offset(0.5, 0.5)],
    2: [Offset(0.5, 0.3), Offset(0.5, 0.7)],
    3: [Offset(0.5, 0.22), Offset(0.3, 0.72), Offset(0.7, 0.72)],
    4: [Offset(0.3, 0.3), Offset(0.7, 0.3), Offset(0.3, 0.7), Offset(0.7, 0.7)],
    5: [
      Offset(0.28, 0.28),
      Offset(0.72, 0.28),
      Offset(0.5, 0.5),
      Offset(0.28, 0.72),
      Offset(0.72, 0.72),
    ],
    6: [
      Offset(0.3, 0.2),
      Offset(0.7, 0.2),
      Offset(0.3, 0.5),
      Offset(0.7, 0.5),
      Offset(0.3, 0.8),
      Offset(0.7, 0.8),
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final rank = rankOf(face);
    final pips = _pips[rank]!;
    final r = size.shortestSide * (rank == 1 ? 0.3 : 0.17);
    final paint = Paint()..color = _suitInk[suitOf(face)];
    for (final o in pips) {
      final c = Offset(o.dx * size.width, o.dy * size.height);
      canvas.drawPath(_shape(suitOf(face), c, r), paint);
    }
  }

  Path _shape(int suit, Offset c, double r) {
    final p = Path();
    switch (suit) {
      case 0: // drop
        p
          ..moveTo(c.dx, c.dy - r * 1.1)
          ..quadraticBezierTo(c.dx + r * 1.1, c.dy + r * 0.2, c.dx, c.dy + r)
          ..quadraticBezierTo(
            c.dx - r * 1.1,
            c.dy + r * 0.2,
            c.dx,
            c.dy - r * 1.1,
          )
          ..close();
      case 1: // leaf: a lens
        p
          ..moveTo(c.dx - r, c.dy + r * 0.6)
          ..quadraticBezierTo(
            c.dx - r * 0.9,
            c.dy - r,
            c.dx + r,
            c.dy - r * 0.6,
          )
          ..quadraticBezierTo(
            c.dx + r * 0.9,
            c.dy + r,
            c.dx - r,
            c.dy + r * 0.6,
          )
          ..close();
      case 2: // wave: a band with a bump
        p
          ..moveTo(c.dx - r, c.dy)
          ..quadraticBezierTo(c.dx - r * 0.5, c.dy - r * 1.2, c.dx, c.dy)
          ..quadraticBezierTo(c.dx + r * 0.5, c.dy + r * 1.2, c.dx + r, c.dy)
          ..lineTo(c.dx + r, c.dy + r * 0.5)
          ..quadraticBezierTo(
            c.dx + r * 0.5,
            c.dy + r * 1.7,
            c.dx,
            c.dy + r * 0.5,
          )
          ..quadraticBezierTo(
            c.dx - r * 0.5,
            c.dy - r * 0.7,
            c.dx - r,
            c.dy + r * 0.5,
          )
          ..close();
      default: // four point star
        for (var k = 0; k < 8; k++) {
          final a = k * pi / 4 - pi / 2;
          final rad = k.isEven ? r * 1.15 : r * 0.45;
          final pt = Offset(c.dx + rad * cos(a), c.dy + rad * sin(a));
          if (k == 0) {
            p.moveTo(pt.dx, pt.dy);
          } else {
            p.lineTo(pt.dx, pt.dy);
          }
        }
        p.close();
    }
    return p;
  }

  @override
  bool shouldRepaint(TileFacePainter old) => old.face != face;
}
