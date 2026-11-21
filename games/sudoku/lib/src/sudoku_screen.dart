import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:game_core/game_core.dart';

import 'sudoku_ids.dart';

import 'sudoku_daily.dart';
import 'rules/sudoku_rules.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Best-score thresholds for 1, 2 and 3 stars on the Games tab tile (docs/SPEC.md, 4.2).
const List<int> sudokuStarScores = [300, 800, 1400];

const String _g = 'sudoku';

/// Sudoku: calm and untimed. Menu (levels, mistake highlighting setting), play (no banner),
/// results (banner). Progress is saved after every move, one save per level.
class SudokuScreen extends StatefulWidget {
  const SudokuScreen({
    super.key,
    this.onScore,
    this.random,
    this.prefs,
    this.daily,
  });

  /// The daily puzzle: starts straight in the puzzle of the day (no menu).
  final DailyRun? daily;

  /// Told the score of each finished puzzle (the Games tab keeps the best one).
  final void Function(int score)? onScore;
  final Random? random;

  /// Injectable for tests.
  final SharedPreferences? prefs;

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

enum _Phase { menu, play, result }

class _SudokuScreenState extends State<SudokuScreen> {
  late final Random _random = widget.random ?? Random();
  SharedPreferences? _prefs;
  _Phase _phase = _Phase.menu;
  SudokuGame? _game;
  int? _selected;
  bool _pencil = false;
  bool _showMistakes = true;
  final Set<SudokuLevel> _saved = {};
  String? _message;
  bool _hintsOn = true;

  /// The stepped hint in progress: [_stage] 1 = where to look shown, 2 = the reason shown.
  SudokuHintStep? _step;
  int _stage = 0;

  ActiveSeconds? _clock;

  @override
  void initState() {
    super.initState();
    final d = widget.daily;
    if (d != null) _clock = ActiveSeconds(base: d.initialSeconds);
    _load();
  }

  @override
  void dispose() {
    _clock?.dispose();
    super.dispose();
  }

  /// The saved daily puzzle is kept apart from the level saves, one per day.
  String? get _dailyKey =>
      widget.daily == null ? null : 'sudoku.save.daily.${widget.daily!.day}';

  void _startDaily() {
    final d = widget.daily!;
    final g =
        SudokuGame.fromJson(_decode(_prefs?.getString(_dailyKey!))) ??
        SudokuGame(generateSudoku(sudokuDailyLevels[d.tier], Random(d.seed)));
    setState(() {
      _game = g;
      _phase = _Phase.play;
    });
    _save();
  }

  void _leaveDaily() {
    final g = _game;
    if (g != null && _phase == _Phase.play) {
      widget.daily?.onProgress?.call(_clock!.seconds, g.mistakes);
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _load() async {
    final p = widget.prefs ?? await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _prefs = p;
      _showMistakes = p.getBool('sudoku.mistakes') ?? true;
      _hintsOn = p.getBool('sudoku.hints') ?? true;
      for (final l in SudokuLevel.values) {
        if (SudokuGame.fromJson(_decode(p.getString(_key(l)))) != null) {
          _saved.add(l);
        }
      }
    });
    if (widget.daily != null) _startDaily();
  }

  static Object? _decode(String? s) {
    if (s == null) return null;
    try {
      return jsonDecode(s);
    } on FormatException {
      return null;
    }
  }

  static String _key(SudokuLevel l) => 'sudoku.save.${l.name}';

  void _save() {
    final g = _game;
    if (g == null) return;
    if (_dailyKey != null) {
      _prefs?.setString(_dailyKey!, jsonEncode(g.toJson()));
      return;
    }
    _prefs?.setString(_key(g.puzzle.level), jsonEncode(g.toJson()));
    _saved.add(g.puzzle.level);
  }

  void _start(SudokuLevel level, {required bool fresh}) {
    SudokuGame? g;
    if (!fresh) {
      g = SudokuGame.fromJson(_decode(_prefs?.getString(_key(level))));
    }
    g ??= SudokuGame(generateSudoku(level, _random));
    setState(() {
      _game = g;
      _selected = null;
      _pencil = false;
      _message = null;
      _step = null;
      _stage = 0;
      _phase = _Phase.play;
    });
    _save();
  }

  void _afterMove() {
    final g = _game!;
    _step = null;
    _stage = 0;
    if (g.solved) {
      if (_dailyKey != null) {
        _prefs?.remove(_dailyKey!);
      } else {
        _prefs?.remove(_key(g.puzzle.level));
        _saved.remove(g.puzzle.level);
      }
      RunReportScope.finished(
        context,
        g.score,
        RunExtras(
          won: true,
          mistakes: g.mistakes,
          hints: g.hintsUsed,
          variant: g.puzzle.level.label,
          seconds: _clock?.seconds,
        ),
      );
      widget.onScore?.call(g.score);
      widget.daily?.onSolved?.call(_clock!.seconds, g.mistakes);
      setState(() => _phase = _Phase.result);
    } else {
      _save();
      setState(() {});
    }
  }

  void _digit(int d) {
    final g = _game!;
    final i = _selected;
    if (i == null) {
      setState(() => _message = 'Pick a square first.');
      return;
    }
    _message = null;
    if (g.enter(i, d, pencil: _pencil)) {
      _afterMove();
    } else {
      setState(() {});
    }
  }

  /// Hint stages: where to look (free), the reason in words (free), then the digit (one of the
  /// puzzle's hints, 100 points). A puzzle that needs more than a single reveals at once, as before.
  void _hint() {
    final g = _game!;
    final step = _step ?? findSudokuHint(g, _selected);
    if (step == null) return;
    if (step.technique == SudokuTechnique.reveal) {
      if (g.hintsLeft <= 0) {
        setState(() => _message = 'No hints left for this puzzle.');
        return;
      }
      final c = g.hint(_selected);
      if (c != null) {
        _selected = c;
        _message = null;
        _afterMove();
      }
      return;
    }
    if (_stage == 0) {
      setState(() {
        _step = step;
        _stage = 1;
        _selected = step.cell;
        _message = step.where;
      });
    } else if (_stage == 1) {
      setState(() {
        _stage = 2;
        _message = step.reason;
      });
    } else {
      if (g.hintsLeft <= 0) {
        setState(() => _message = 'No hints left for this puzzle.');
        return;
      }
      if (g.fillHint(step.cell)) {
        _selected = step.cell;
        _message = null;
        _afterMove();
      }
    }
  }

  String get _zenHintLabel => switch (_stage) {
    1 => 'Why?',
    2 => 'Fill it',
    _ => 'Hint',
  };

  String get _hintLabel {
    final g = _game!;
    final left = 'Hint (${g.hintsLeft})';
    return switch (_stage) {
      1 => 'Why?',
      2 => 'Fill it (${g.hintsLeft} left)',
      _ => left,
    };
  }

  Future<void> _setMistakes(bool v) async {
    setState(() => _showMistakes = v);
    await _prefs?.setBool('sudoku.mistakes', v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sudoku'),
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
        child: switch (_phase) {
          _Phase.menu when widget.daily != null => const Center(
            child: CircularProgressIndicator(),
          ),
          _Phase.menu => _menu(context),
          _Phase.play => _play(context),
          _Phase.result => CalmResults(
            game: _g,
            title: 'Puzzle solved',
            score: _game!.score,
            thresholds: sudokuStarScores,
            detail:
                '${_game!.mistakes} mistakes, ${_game!.hintsUsed} hints used',
            againLabel: widget.daily != null ? 'Back to Games' : 'Play again',
            onAgain: widget.daily != null
                ? _leaveDaily
                : () => _start(_game!.puzzle.level, fresh: true),
            onDone: widget.daily != null
                ? _leaveDaily
                : () => setState(() => _phase = _Phase.menu),
          ),
        },
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
              for (final l in SudokuLevel.values)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${l.label} (${l.clues} clues)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (_saved.contains(l))
                          FilledButton(
                            key: MindIds.calmLevel(_g, '${l.name}.resume'),
                            onPressed: () => _start(l, fresh: false),
                            child: const Text('Resume'),
                          ),
                        _saved.contains(l)
                            ? OutlinedButton(
                                key: MindIds.calmLevel(_g, l.name),
                                onPressed: () => _start(l, fresh: true),
                                child: const Text('New puzzle'),
                              )
                            : FilledButton(
                                key: MindIds.calmLevel(_g, l.name),
                                onPressed: () => _start(l, fresh: true),
                                child: const Text('Play'),
                              ),
                      ],
                    ),
                  ),
                ),
              SwitchListTile(
                key: MindIds.calmControl(_g, 'hints'),
                title: const Text('Hints'),
                subtitle: const Text('Show the Hint button'),
                value: _hintsOn,
                onChanged: (v) {
                  setState(() => _hintsOn = v);
                  _prefs?.setBool('sudoku.hints', v);
                },
              ),
              SwitchListTile(
                key: MindIds.calmControl(_g, 'mistakes'),
                title: const Text('Show mistakes'),
                subtitle: const Text(
                  'Marks a wrong digit as soon as you place it',
                ),
                value: _showMistakes,
                onChanged: _setMistakes,
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
    final zen = ZenScope.of(context).zen;
    g.unlimitedHints = zen; // Zen: free hints, no limit (M5)
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sel = _selected;
    final selValue = sel == null ? 0 : g.values[sel];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              Text(
                '${g.puzzle.level.label}'
                '${_showMistakes && !zen ? ', mistakes ${g.mistakes}' : ''}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.onSurface, width: 2),
                  ),
                  child: Column(
                    children: [
                      for (var r = 0; r < 9; r++)
                        Expanded(
                          child: Row(
                            children: [
                              for (var c = 0; c < 9; c++)
                                Expanded(
                                  child: _cell(context, g, r * 9 + c, selValue),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _message!,
                    key: MindIds.calmControl(_g, 'message'),
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  for (var d = 1; d <= 9; d++)
                    Semantics(
                      button: true,
                      label: _pencil ? 'Note $d' : 'Digit $d',
                      excludeSemantics: true,
                      child: SizedBox(
                        width: 44,
                        height: 48,
                        child: FilledButton.tonal(
                          key: SudokuIds.sudokuDigit(d),
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(44, 48),
                          ),
                          onPressed: () => _digit(d),
                          child: Text('$d'),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilterChip(
                    key: MindIds.calmControl(_g, 'pencil'),
                    label: const Text('Notes'),
                    selected: _pencil,
                    onSelected: (v) => setState(() => _pencil = v),
                  ),
                  OutlinedButton(
                    key: MindIds.calmControl(_g, 'erase'),
                    onPressed: sel == null
                        ? null
                        : () {
                            if (g.erase(sel)) _afterMove();
                          },
                    child: const Text('Erase'),
                  ),
                  OutlinedButton(
                    key: MindIds.calmControl(_g, 'undo'),
                    onPressed: g.canUndo
                        ? () {
                            g.undo();
                            _afterMove();
                          }
                        : null,
                    child: const Text('Undo'),
                  ),
                  if (_hintsOn)
                    OutlinedButton(
                      key: MindIds.calmControl(_g, 'hint'),
                      onPressed: _hint,
                      child: Text(zen ? _zenHintLabel : _hintLabel),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(BuildContext context, SudokuGame g, int i, int selValue) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final r = i ~/ 9, c = i % 9;
    final v = g.values[i];
    final given = g.isGiven(i);
    final wrong = _showMistakes && g.isWrong(i);
    final selected = _selected == i;
    final sameDigit = selValue != 0 && v == selValue;
    final side = BorderSide(color: scheme.outline, width: 0.5);
    final thick = BorderSide(color: scheme.onSurface, width: 1.5);
    final inArea = _stage > 0 && (_step?.area.contains(i) ?? false);
    final isTarget = _stage > 0 && _step?.cell == i;
    final bg = selected
        ? scheme.primaryContainer
        : inArea
        ? scheme.tertiaryContainer
        : sameDigit
        ? scheme.secondaryContainer
        : scheme.surface;
    final label = StringBuffer('Row ${r + 1}, column ${c + 1}, ');
    if (v == 0) {
      label.write('empty');
    } else {
      label.write(given ? 'given $v' : 'entered $v');
      if (wrong) label.write(', wrong');
    }
    return Semantics(
      button: !given,
      selected: selected,
      label: label.toString(),
      excludeSemantics: true,
      child: InkWell(
        key: SudokuIds.sudokuCell(i),
        onTap: () => setState(() {
          _selected = i;
          _message = null;
        }),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            border: isTarget
                ? Border.all(color: scheme.tertiary, width: 3)
                : inArea
                ? Border.all(color: scheme.tertiary, width: 1.5)
                : Border(
                    top: r % 3 == 0 && r > 0 ? thick : side,
                    left: c % 3 == 0 && c > 0 ? thick : side,
                    right: side,
                    bottom: side,
                  ),
          ),
          alignment: Alignment.center,
          child: v != 0
              ? FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Text(
                      wrong ? '$v!' : '$v',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: given ? FontWeight.w800 : FontWeight.w500,
                        color: wrong ? scheme.error : scheme.onSurface,
                        decoration: wrong ? TextDecoration.underline : null,
                      ),
                    ),
                  ),
                )
              : _notes(g, i, scheme),
        ),
      ),
    );
  }

  Widget _notes(SudokuGame g, int i, ColorScheme scheme) {
    if (g.notes[i] == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(1),
      child: Column(
        children: [
          for (var r = 0; r < 3; r++)
            Expanded(
              child: Row(
                children: [
                  for (var c = 0; c < 3; c++)
                    Expanded(
                      child: FittedBox(
                        child: Text(
                          g.hasNote(i, r * 3 + c + 1) ? '${r * 3 + c + 1}' : '',
                          style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
