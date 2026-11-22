import 'dart:math';

import 'package:flutter/material.dart';

import 'package:game_core/game_core.dart';

import 'solitaire_daily.dart';
import 'rules/solitaire_rules.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Best-score thresholds for 1, 2 and 3 stars on the Games tab tile (docs/SPEC.md, 4.3).
const List<int> solitaireStarScores = [500, 1000, 1500];

const String _g = 'solitaire';

enum _Phase { menu, play, result }

/// Where a dragged card comes from.
class _Src {
  const _Src(this.kind, {this.col = 0, this.index = 0});
  final MoveKind kind;
  final int col;
  final int index;
}

/// Klondike solitaire, calm and untimed. Menu (draw one or three, winnable deals), play (no
/// banner), results (banner). Tap a card to send it where it fits, or drag it.
class SolitaireScreen extends StatefulWidget {
  const SolitaireScreen({
    super.key,
    this.onScore,
    this.random,
    this.prefs,
    this.autoStep = const Duration(milliseconds: 90),
    this.firstDeal,
    this.daily,
  });

  /// The daily puzzle: starts straight in the deal of the day (no menu), always a proven
  /// winnable deal.
  final DailyRun? daily;

  /// For tests: the first game is dealt from this state instead of a shuffle.
  final KlondikeState? firstDeal;

  /// Told the score of each won game (the Games tab keeps the best one).
  final void Function(int score)? onScore;
  final Random? random;
  final SharedPreferences? prefs;

  /// Pause between the cards of an auto-complete (none with reduced motion).
  final Duration autoStep;

  @override
  State<SolitaireScreen> createState() => _SolitaireScreenState();
}

class _SolitaireScreenState extends State<SolitaireScreen> {
  late final Random _random = widget.random ?? Random();
  SharedPreferences? _prefs;
  _Phase _phase = _Phase.menu;
  KlondikeGame? _game;
  bool _draw3 = false;
  bool _winnable = true;
  SolitaireLevel _level = SolitaireLevel.easy;
  bool _hintsOn = true;
  KlondikeHint? _hint;
  bool _auto = false;

  /// Keyboard cursor: 0 stock, 1 waste, 2 to 8 the columns; [_depth] counts face-up cards down from the top.
  int _kslot = 0;
  int _depth = 0;
  bool _keyed = false;

  /// The level being played (the daily puzzle's tier, else the menu choice).
  SolitaireLevel get _playing =>
      widget.daily != null ? solitaireDailyLevels[widget.daily!.tier] : _level;
  int get _drawNow =>
      _level == SolitaireLevel.custom ? (_draw3 ? 3 : 1) : _level.drawCount;
  bool get _winnableNow =>
      _level == SolitaireLevel.custom ? _winnable : _level.winnable;

  ActiveSeconds? _clock;

  @override
  void initState() {
    super.initState();
    final d = widget.daily;
    if (d != null) {
      _clock = ActiveSeconds(base: d.initialSeconds);
      _start();
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
      widget.daily?.onProgress?.call(_clock!.seconds, 0);
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _load() async {
    final p = widget.prefs ?? await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _prefs = p;
      _draw3 = p.getBool('solitaire.draw3') ?? false;
      _winnable = p.getBool('solitaire.winnable') ?? true;
      _hintsOn = p.getBool('solitaire.hints') ?? true;
      // Saved draw and winnable choices become a level on first load.
      _level =
          SolitaireLevel.byName(p.getString('solitaire.level')) ??
          SolitaireLevel.fromLegacy(draw3: _draw3, winnable: _winnable);
    });
  }

  bool _firstUsed = false;

  void _start() {
    final first = _firstUsed ? null : widget.firstDeal;
    _firstUsed = true;
    // From initState there is nothing to rebuild yet.
    void set(KlondikeGame g) {
      void apply() {
        _game = g;
        _phase = _Phase.play;
        _auto = false;
        _hint = null;
        _kslot = 0;
        _depth = 0;
      }

      if (mounted) {
        setState(apply);
      } else {
        apply();
      }
    }

    if (first != null) {
      set(_newGame(first.copy(), false));
      return;
    }
    final daily = widget.daily;
    if (daily != null) {
      final d = dealKlondike(
        Random(daily.seed),
        drawCount: solitaireDailyLevels[daily.tier].drawCount,
        winnable: true,
        attempts: 40,
        maxNodes: 20000,
      );
      set(_newGame(d.state, d.proven));
      return;
    }
    final d = dealKlondike(
      _random,
      drawCount: _drawNow,
      winnable: _winnableNow,
      attempts: 12,
      maxNodes: 8000,
    );
    set(_newGame(d.state, d.proven));
  }

  KlondikeGame _newGame(KlondikeState st, bool proven) {
    final l = _playing;
    return KlondikeGame(
      st,
      proven: proven,
      winBonus: l.winBonus,
      hintLimit: l.hints,
    );
  }

  void _takeHint() {
    final g = _game!;
    if (_auto || !g.canHint) return;
    final h = g.takeHint();
    setState(() => _hint = h);
    if (h == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No useful move right now. Try Undo.')),
      );
    }
  }

  // ---- keyboard (docs/SPEC.md, Keyboard): left and right pick the stock, the waste or a column, up and down
  // pick the card in a column, Enter plays it (draws from the stock), 1 hint, 2 undo, Esc goes back ----

  void _onKey(GameInput i) {
    final a = i.action;
    switch (_phase) {
      case _Phase.menu:
        if (i.repeat) return;
        if (a == GameAction.exit) {
          Navigator.of(context).maybePop();
        } else if (a == GameAction.action || a == GameAction.pick1) {
          _start();
        }
      case _Phase.play:
        final g = _game!;
        final s = g.state;
        switch (a) {
          case GameAction.left:
            setState(() {
              _keyed = true;
              _kslot = (_kslot + 8) % 9;
              _depth = 0;
            });
          case GameAction.right:
            setState(() {
              _keyed = true;
              _kslot = (_kslot + 1) % 9;
              _depth = 0;
            });
          case GameAction.up || GameAction.down:
            if (_kslot < 2) return;
            final c = _kslot - 2;
            final faceUp = s.tableau[c].length - s.down[c];
            final d = _depth + (a == GameAction.up ? 1 : -1);
            setState(() {
              _keyed = true;
              _depth = faceUp <= 0 ? 0 : d.clamp(0, faceUp - 1);
            });
          case GameAction.action when !i.repeat:
            setState(() => _keyed = true);
            if (_kslot == 0) {
              _play(const KlondikeMove(MoveKind.draw));
            } else if (_kslot == 1) {
              _play(s.tapMove(MoveKind.wasteToTableau));
            } else {
              final c = _kslot - 2;
              final idx = s.tableau[c].length - 1 - _depth;
              if (idx >= s.down[c] && idx >= 0) {
                _play(s.tapMove(MoveKind.tableauToTableau, index: idx, col: c));
              }
            }
            _depth = 0;
          case GameAction.pick1 when !i.repeat:
            _takeHint();
          case GameAction.pick2 when !i.repeat && g.canUndo && !_auto:
            g.undo();
            setState(() => _hint = null);
          case GameAction.exit when !i.repeat:
            _leave();
          default:
        }
      case _Phase.result:
        if (i.repeat) return;
        if (a == GameAction.action) {
          widget.daily != null ? _leaveDaily() : _start();
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

  void _after() {
    final g = _game!;
    if (g.state.won) {
      RunReportScope.finished(
        context,
        g.finalScore,
        RunExtras(
          won: true,
          hints: g.hintsUsed,
          variant: _playing.label,
          seconds: _clock?.seconds,
        ),
      );
      widget.onScore?.call(g.finalScore);
      widget.daily?.onSolved?.call(_clock!.seconds, 0);
      setState(() => _phase = _Phase.result);
    } else {
      setState(() {});
    }
  }

  void _play(KlondikeMove? m) {
    if (m == null || _auto) return;
    if (_game!.play(m)) {
      _hint = null;
      _after();
    }
  }

  Future<void> _autoComplete() async {
    final g = _game!;
    if (_auto || !g.state.canAutoComplete) return;
    _auto = true;
    final quick = reduceMotionOf(context);
    while (mounted && !g.state.won) {
      final m = g.state.nextAutoMove();
      if (m == null) break;
      g.play(m);
      if (!g.state.won) setState(() {});
      if (!quick) await Future<void>.delayed(widget.autoStep);
    }
    _auto = false;
    if (mounted) _after();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solitaire'),
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
                  GameAction.up,
                  GameAction.down,
                  GameAction.action,
                  GameAction.exit,
                ]
              : const [GameAction.action, GameAction.exit],
          child: switch (_phase) {
            _Phase.menu => _menu(context),
            _Phase.play => _table(context),
            _Phase.result => CalmResults(
              game: _g,
              title: 'You won',
              score: _game!.finalScore,
              thresholds: solitaireStarScores,
              detail: '${_game!.state.moves} moves',
              againLabel: widget.daily != null ? 'Back to Games' : 'Play again',
              onAgain: widget.daily != null ? _leaveDaily : _start,
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
              Text('Level', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final l in SolitaireLevel.values)
                    ChoiceChip(
                      key: MindIds.calmControl(_g, 'level.${l.name}'),
                      label: Text(l.label),
                      selected: _level == l,
                      onSelected: (_) {
                        setState(() => _level = l);
                        _prefs?.setString('solitaire.level', l.name);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(_levelNote(_level, zen: ZenScope.of(context).zen)),
              if (_level == SolitaireLevel.custom) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final three in [false, true])
                      ChoiceChip(
                        key: Key(three ? 'solitaire.draw3' : 'solitaire.draw1'),
                        label: Text(three ? 'Draw three' : 'Draw one'),
                        selected: _draw3 == three,
                        onSelected: (_) {
                          setState(() => _draw3 = three);
                          _prefs?.setBool('solitaire.draw3', three);
                        },
                      ),
                  ],
                ),
                SwitchListTile(
                  key: MindIds.calmControl(_g, 'winnable'),
                  title: const Text('Winnable deals'),
                  subtitle: const Text(
                    'Only deals that can be won, when one is found quickly',
                  ),
                  value: _winnable,
                  onChanged: (v) {
                    setState(() => _winnable = v);
                    _prefs?.setBool('solitaire.winnable', v);
                  },
                ),
              ],
              SwitchListTile(
                key: MindIds.calmControl(_g, 'hints'),
                title: const Text('Hints'),
                subtitle: const Text('Show the Hint button'),
                value: _hintsOn,
                onChanged: (v) {
                  setState(() => _hintsOn = v);
                  _prefs?.setBool('solitaire.hints', v);
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  key: MindIds.calmControl(_g, 'play'),
                  onPressed: _start,
                  child: const Text('Play'),
                ),
              ),
            ],
          ),
        ),
        const CalmBanner(game: _g, placement: GameBannerSlot.menu),
      ],
    );
  }

  static String _levelNote(SolitaireLevel l, {bool zen = false}) {
    final draw = l.drawCount == 3 ? 'Draw three' : 'Draw one';
    final deal = l.winnable ? 'winnable deals' : 'plain shuffle';
    if (zen) {
      return l == SolitaireLevel.custom
          ? 'Your own draw and deal, free hints'
          : '$draw, $deal, free hints';
    }
    final hints = l.hints == 0
        ? 'no hints'
        : '${l.hints} hint${l.hints == 1 ? '' : 's'}';
    if (l == SolitaireLevel.custom) {
      return 'Your own draw and deal, $hints, win bonus ${l.winBonus}';
    }
    return '$draw, $deal, $hints, win bonus ${l.winBonus}';
  }

  Widget _table(BuildContext context) {
    final g = _game!;
    final s = g.state;
    final zen = ZenScope.of(context).zen;
    g.unlimitedHints = zen; // Zen: free hints whatever the level's limit (M5)
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 4.0;
        final w = min(box.maxWidth, 640.0);
        final cw = (w - gap * 8) / 7;
        final ch = cw * 1.4;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: gap, vertical: 8),
          child: Center(
            child: SizedBox(
              width: w - gap * 2,
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (!zen) ...[
                        Text(
                          'Score ${s.score}',
                          key: MindIds.calmControl(_g, 'score'),
                        ),
                        Text('Moves ${s.moves}'),
                      ],
                      OutlinedButton(
                        key: MindIds.calmControl(_g, 'undo'),
                        onPressed: g.canUndo && !_auto
                            ? () {
                                g.undo();
                                setState(() {});
                              }
                            : null,
                        child: const Text('Undo'),
                      ),
                      OutlinedButton(
                        key: MindIds.calmControl(_g, 'new'),
                        onPressed: _auto ? null : _start,
                        child: Text(
                          widget.daily != null ? 'Restart' : 'New deal',
                        ),
                      ),
                      if (_hintsOn && (zen || g.hintLimit > 0))
                        OutlinedButton(
                          key: MindIds.calmControl(_g, 'hint'),
                          onPressed: g.canHint && !_auto ? _takeHint : null,
                          child: Text(
                            zen
                                ? 'Hint'
                                : 'Hint (${g.hintLimit - g.hintsUsed})',
                          ),
                        ),
                      if (s.canAutoComplete)
                        FilledButton(
                          key: MindIds.calmControl(_g, 'auto'),
                          onPressed: _autoComplete,
                          child: const Text('Auto-complete'),
                        ),
                    ],
                  ),
                  if (_hint != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _hint!.text,
                        key: MindIds.calmControl(_g, 'hint.text'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _stock(s, cw, ch),
                      const SizedBox(width: gap),
                      _waste(s, cw, ch),
                      const Spacer(),
                      for (var f = 0; f < 4; f++) ...[
                        _foundation(s, f, cw, ch),
                        if (f < 3) const SizedBox(width: gap),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var c = 0; c < 7; c++) ...[
                        _column(s, c, cw, ch),
                        if (c < 6) const SizedBox(width: gap),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The hint border: thick and dark, so the source and target do not rely on colour alone.
  Widget _mark(bool on, Widget child, {Key? key}) {
    if (!on) return child;
    return DecoratedBox(
      key: key,
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.tertiary,
          width: 4,
        ),
      ),
      child: child,
    );
  }

  MoveKind? get _hk => _hint?.move.kind;

  Widget _stock(KlondikeState s, double cw, double ch) {
    final empty = s.stock.isEmpty;
    return Semantics(
      button: true,
      label: empty
          ? (s.waste.isEmpty
                ? 'Stock, empty'
                : 'Stock, empty. Turn the waste over')
          : 'Stock, ${s.stock.length} cards. Draw',
      excludeSemantics: true,
      child: GestureDetector(
        key: MindIds.calmControl(_g, 'stock'),
        onTap: () => _play(const KlondikeMove(MoveKind.draw)),
        child: _mark(
          _hk == MoveKind.draw || (_keyed && _kslot == 0),
          _slot(
            cw,
            ch,
            child: empty
                ? Icon(
                    Icons.refresh,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )
                : _CardFace(card: 0, up: false, w: cw, h: ch),
          ),
          key: MindIds.calmControl(_g, 'hint.stock'),
        ),
      ),
    );
  }

  Widget _waste(KlondikeState s, double cw, double ch) {
    // Draw three fans the last three cards of the waste a little.
    final shown = s.waste.length > s.drawCount
        ? s.waste.sublist(s.waste.length - s.drawCount)
        : s.waste;
    final step = cw * 0.28;
    final width = cw + step * (s.drawCount - 1);
    return SizedBox(
      key: MindIds.calmControl(_g, 'waste'),
      width: width,
      height: ch,
      child: Stack(
        children: [
          _slot(cw, ch),
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: step * i,
              child: i == shown.length - 1
                  ? _mark(
                      _hk == MoveKind.wasteToFoundation ||
                          _hk == MoveKind.wasteToTableau ||
                          (_keyed && _kslot == 1),
                      _draggable(
                        const _Src(MoveKind.wasteToTableau),
                        [shown[i]],
                        cw,
                        ch,
                        () => _play(
                          _game!.state.tapMove(MoveKind.wasteToTableau),
                        ),
                        MindIds.calmControl(_g, 'waste.top'),
                      ),
                      key: MindIds.calmControl(_g, 'hint.source'),
                    )
                  : _CardFace(card: shown[i], up: true, w: cw, h: ch),
            ),
        ],
      ),
    );
  }

  Widget _foundation(KlondikeState s, int f, double cw, double ch) {
    final n = s.foundation[f];
    return DragTarget<_Src>(
      onWillAcceptWithDetails: (d) => _foundationMove(d.data, f) != null,
      onAcceptWithDetails: (d) => _play(_foundationMove(d.data, f)),
      builder: (context, cand, rej) => Container(
        key: MindIds.calmControl(_g, 'found.$f'),
        foregroundDecoration: _hintFoundation(s) == f
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.tertiary,
                  width: 4,
                ),
              )
            : null,
        child: n == 0
            ? Semantics(
                label: 'Foundation, ${suitNames[f]}, empty',
                child: _slot(
                  cw,
                  ch,
                  child: Text(
                    suitGlyphs[f],
                    style: TextStyle(
                      fontSize: cw * 0.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            : _draggable(
                _Src(MoveKind.foundationToTableau, col: f),
                [f * 13 + n - 1],
                cw,
                ch,
                () {
                  for (var d = 0; d < 7; d++) {
                    final m = KlondikeMove(
                      MoveKind.foundationToTableau,
                      from: f,
                      to: d,
                    );
                    if (s.isLegal(m)) return _play(m);
                  }
                },
                MindIds.calmControl(_g, 'found.$f.top'),
              ),
      ),
    );
  }

  /// The foundation a foundation hint points at, or null.
  int? _hintFoundation(KlondikeState s) {
    final m = _hint?.move;
    if (m == null) return null;
    if (m.kind == MoveKind.wasteToFoundation && s.waste.isNotEmpty) {
      return suitOf(s.waste.last);
    }
    if (m.kind == MoveKind.tableauToFoundation &&
        s.tableau[m.from].isNotEmpty) {
      return suitOf(s.tableau[m.from].last);
    }
    return null;
  }

  KlondikeMove? _foundationMove(_Src src, int f) {
    final s = _game!.state;
    KlondikeMove? m;
    if (src.kind == MoveKind.wasteToTableau && s.waste.isNotEmpty) {
      if (suitOf(s.waste.last) == f) {
        m = const KlondikeMove(MoveKind.wasteToFoundation);
      }
    } else if (src.kind == MoveKind.tableauToTableau) {
      final t = s.tableau[src.col];
      if (src.index == t.length - 1 && suitOf(t.last) == f) {
        m = KlondikeMove(MoveKind.tableauToFoundation, from: src.col);
      }
    }
    return m != null && s.isLegal(m) ? m : null;
  }

  KlondikeMove? _tableauMove(_Src src, int to) {
    final s = _game!.state;
    final KlondikeMove m;
    switch (src.kind) {
      case MoveKind.wasteToTableau:
        m = KlondikeMove(MoveKind.wasteToTableau, to: to);
      case MoveKind.tableauToTableau:
        m = KlondikeMove(
          MoveKind.tableauToTableau,
          from: src.col,
          to: to,
          count: s.tableau[src.col].length - src.index,
        );
      default:
        m = KlondikeMove(MoveKind.foundationToTableau, from: src.col, to: to);
    }
    return s.isLegal(m) ? m : null;
  }

  Widget _column(KlondikeState s, int c, double cw, double ch) {
    final t = s.tableau[c];
    final downStep = ch * 0.14;
    final upStep = ch * 0.3;
    var y = 0.0;
    final tops = <double>[];
    for (var i = 0; i < t.length; i++) {
      tops.add(y);
      y += i < s.down[c] ? downStep : upStep;
    }
    final height = t.isEmpty ? ch : tops.last + ch;
    // Leave room below so a dragged card can land on the column.
    return DragTarget<_Src>(
      onWillAcceptWithDetails: (d) => _tableauMove(d.data, c) != null,
      onAcceptWithDetails: (d) => _play(_tableauMove(d.data, c)),
      builder: (context, cand, rej) => SizedBox(
        key: MindIds.calmControl(_g, 'col.$c'),
        width: cw,
        height: max(height, ch * 2.4),
        child: _mark(
          _hint?.move.kind == MoveKind.wasteToTableau ||
                  _hint?.move.kind == MoveKind.tableauToTableau
              ? _hint!.move.to == c
              : (_keyed && _kslot == c + 2 && t.isEmpty),
          key: MindIds.calmControl(_g, 'hint.target'),
          Stack(
            children: [
              _slot(cw, ch, child: Semantics(label: 'Column ${c + 1}, empty')),
              for (var i = 0; i < t.length; i++)
                Positioned(
                  top: tops[i],
                  child: i < s.down[c]
                      ? _CardFace(card: t[i], up: false, w: cw, h: ch)
                      : _mark(
                          _hint?.move.kind == MoveKind.tableauToTableau &&
                                  _hint!.move.from == c &&
                                  i == t.length - _hint!.move.count ||
                              _hint?.move.kind ==
                                      MoveKind.tableauToFoundation &&
                                  _hint!.move.from == c &&
                                  i == t.length - 1 ||
                              (_keyed &&
                                  _kslot == c + 2 &&
                                  i == t.length - 1 - _depth),
                          _draggable(
                            _Src(MoveKind.tableauToTableau, col: c, index: i),
                            t.sublist(i),
                            cw,
                            ch,
                            () => _play(
                              s.tapMove(
                                MoveKind.tableauToTableau,
                                index: i,
                                col: c,
                              ),
                            ),
                            MindIds.calmControl(_g, 'card.${t[i]}'),
                            stepY: upStep,
                          ),
                          key: MindIds.calmControl(_g, 'hint.source'),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _draggable(
    _Src src,
    List<int> cards,
    double cw,
    double ch,
    VoidCallback onTap,
    Key key, {
    double? stepY,
  }) {
    final face = _CardFace(card: cards.first, up: true, w: cw, h: ch);
    final feedback = SizedBox(
      width: cw,
      height: ch + (stepY ?? 0) * (cards.length - 1),
      child: Stack(
        children: [
          for (var i = 0; i < cards.length; i++)
            Positioned(
              top: (stepY ?? 0) * i,
              child: _CardFace(card: cards[i], up: true, w: cw, h: ch),
            ),
        ],
      ),
    );
    return Draggable<_Src>(
      data: src,
      feedback: Material(type: MaterialType.transparency, child: feedback),
      childWhenDragging: Opacity(opacity: 0.35, child: face),
      child: GestureDetector(key: key, onTap: onTap, child: face),
    );
  }

  Widget _slot(double cw, double ch, {Widget? child}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: cw,
      height: ch,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outline),
      ),
      child: child,
    );
  }
}

/// One card, face up (rank and suit glyph, red or dark, and the suit name for screen readers) or
/// face down. Drawn with shapes and text only.
class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.card,
    required this.up,
    required this.w,
    required this.h,
  });
  final int card;
  final bool up;
  final double w;
  final double h;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!up) {
      return Semantics(
        label: 'Face-down card',
        excludeSemantics: true,
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: scheme.onPrimary, width: 2),
          ),
        ),
      );
    }
    final color = isRed(card)
        ? const Color(0xFFB00020)
        : const Color(0xFF111111);
    return Semantics(
      label: cardName(card),
      excludeSemantics: true,
      child: Container(
        width: w,
        height: h,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.black54),
        ),
        child: FittedBox(
          alignment: Alignment.topLeft,
          fit: BoxFit.scaleDown,
          child: Text(
            '${rankGlyphs[rankOf(card) - 1]}${suitGlyphs[suitOf(card)]}',
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
