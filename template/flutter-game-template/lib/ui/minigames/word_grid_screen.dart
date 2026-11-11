import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/services.dart';
import '../../core/speech/speech_service.dart';
import '../../engine/engine.dart';
import '../test_ids.dart';
import 'choice_game.dart';
import 'minigame_parts.dart';

/// Word search and crossword from the open `word` items: free with ads, Game and Study mode.
/// The child picks which to play on the start screen. [harder] is for Champion.
MiniGame wordGridGameFor({bool harder = false}) => MiniGame(
  id: wordGridId,
  title: 'Word search and crossword',
  itemTypes: const {ItemType.word},
  minPool: 4,
  build: (ctx) => WordGridScreen(
    session: ctx.session,
    onExit: ctx.onExit,
    onAnswered: ctx.onAnswered,
    onScore: ctx.onScore,
    level: levelForSession(ctx.session, harder: harder),
    study: ctx.mode == MiniGameMode.study,
  ),
);

final MiniGame wordGridGame = wordGridGameFor();

enum _Phase { intro, play, results }

class WordGridScreen extends StatefulWidget {
  const WordGridScreen({
    super.key,
    required this.session,
    required this.onExit,
    required this.level,
    this.study = false,
    this.onAnswered,
    this.onScore,
    this.random,
    this.reader,
  });
  final QuizSession session;
  final VoidCallback onExit;
  final MiniGameLevel level;

  /// Study mode: calm, no timer, the words are listed.
  final bool study;
  final void Function(AnswerResult, QuizSession)? onAnswered;
  final void Function(int)? onScore;
  final Random? random;
  final ReadAloud? reader;

  @override
  State<WordGridScreen> createState() => _WordGridScreenState();
}

class _WordGridScreenState extends State<WordGridScreen> {
  static const _g = wordGridId;
  late final Random _random = widget.random ?? Random();
  _Phase _phase = _Phase.intro;
  WordGrid? _grid;
  final Set<String> _found = {};
  final Set<String> _missed = {};
  int _score = 0;
  int _streak = 0;
  String _message = '';
  bool _scoreSent = false;
  SecondsTicker? _ticker;
  int _left = 0;
  ReadAloud? _reader;

  // Word search selection.
  (int, int)? _anchor;
  (int, int)? _hover;

  // Crossword entry.
  int? _clue;
  List<String> _bank = [];
  final List<int> _typed = [];

  WordGridSettings get _st => WordGridSettings.forLevel(widget.level);
  bool get _timed =>
      widget.level.older && !widget.study && _st.secondsPerRound > 0;
  bool get _showWords => !widget.level.older || widget.study;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reader = resolveReader(context, widget.reader, null);
  }

  @override
  void dispose() {
    _ticker?.stop();
    _reader?.stop();
    super.dispose();
  }

  void _start(GridKind kind) {
    final words = leadingGridWords([
      for (final p in widget.session.items) p.item,
    ]);
    final grid = buildWordGrid(kind, words, _st, _random);
    setState(() {
      _grid = grid;
      _phase = _Phase.play;
      _left = _st.secondsPerRound;
    });
    if (grid == null) return;
    if (_timed) {
      _ticker = SecondsTicker(() {
        if (!mounted) return;
        setState(() => _left--);
        if (_left <= 0) _finish();
      })..start();
    }
  }

  void _found1(PlacedWord w, {required bool clean}) {
    _found.add(w.word.id);
    if (!clean) _missed.add(w.word.id);
    if (clean) {
      _score += scoreForAnswer(streak: _streak, older: widget.level.older);
      _streak++;
    }
    _message = 'Found ${w.word.word}!';
    if (_found.length == _grid!.placed.length) _finish();
  }

  void _miss(String msg) {
    _streak = 0;
    _message = msg;
  }

  void _finish() {
    if (_phase == _Phase.results) return;
    _ticker?.stop();
    _reader?.stop();
    final g = _grid!;
    final s = widget.session;
    for (final w in g.placed.toList()..sort((a, b) => _order(a) - _order(b))) {
      if (s.finished) break;
      final ok = _found.contains(w.word.id) && !_missed.contains(w.word.id);
      widget.onAnswered?.call(s.answer(correct: ok), s);
    }
    if (!_scoreSent) {
      _scoreSent = true;
      widget.onScore?.call(_score);
    }
    setState(() => _phase = _Phase.results);
  }

  int _order(PlacedWord w) =>
      widget.session.items.indexWhere((p) => p.id == w.word.id);

  // ---- Word search ----

  void _cellTap((int, int) c) {
    final a = _anchor;
    if (a == null) {
      setState(() => _anchor = c);
    } else {
      _trySelect(a, c);
    }
  }

  void _trySelect((int, int) a, (int, int) b) {
    final g = _grid!;
    final w = a == b ? null : wordForSelection(g, a, b);
    setState(() {
      _anchor = null;
      _hover = null;
      if (w != null && !_found.contains(w.word.id)) {
        _found1(w, clean: true);
      } else if (a != b) {
        _miss('That is not one of the words. Try another line.');
      }
    });
  }

  (int, int)? _cellAt(Offset p, double cell) {
    final g = _grid!;
    final r = (p.dy / cell).floor(), c = (p.dx / cell).floor();
    return r < 0 || c < 0 || r >= g.rows || c >= g.cols ? null : (r, c);
  }

  // ---- Crossword ----

  void _pickClue(int i) {
    final w = _grid!.placed[i];
    if (_found.contains(w.word.id)) return;
    setState(() {
      _clue = i;
      _typed.clear();
      _bank = w.word.word.split('')..shuffle(_random);
      _message = '';
    });
  }

  void _typeLetter(int i) {
    if (_clue == null || _typed.contains(i)) return;
    setState(() => _typed.add(i));
    final w = _grid!.placed[_clue!];
    if (_typed.length < w.word.word.length) return;
    final typed = _typed.map((j) => _bank[j]).join();
    setState(() {
      if (crosswordAnswerMatches(w, typed)) {
        _found1(w, clean: !_missed.contains(w.word.id));
        _clue = null;
        _bank = [];
      } else {
        _missed.add(w.word.id);
        _miss('Not quite. Try the letters again.');
      }
      _typed.clear();
    });
  }

  // ---- Views ----

  Widget _banner(AdPlacement placement) {
    final s = context
        .dependOnInheritedWidgetOfExactType<ServicesScope>()
        ?.services;
    if (s == null) return const SizedBox.shrink();
    return KeyedSubtree(
      key: TestIds.mgBanner(_g),
      child: s.ads.buildBanner(placement),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: TestIds.mgScreen(_g),
      appBar: AppBar(
        title: const Text('Word search and crossword'),
        leading: IconButton(
          key: TestIds.mgExit(_g),
          tooltip: 'Leave Word search and crossword',
          icon: const Icon(Icons.close),
          onPressed: widget.onExit,
        ),
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.intro => _intro(context),
          _Phase.play => _grid == null ? _noGrid(context) : _play(context),
          _Phase.results => _results(context),
        },
      ),
    );
  }

  Widget _intro(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              key: TestIds.mgIntro(_g),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Words',
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Word search: tap the first and last letter of a hidden word, '
                    'or drag across it. Crossword: tap a clue, then tap its letters in order.',
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: TestIds.mgStart(_g),
                    onPressed: () => _start(GridKind.wordSearch),
                    child: const Text('Word search'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    key: TestIds.mgStartAlt(_g),
                    onPressed: () => _start(GridKind.crossword),
                    child: const Text('Crossword'),
                  ),
                ],
              ),
            ),
          ),
        ),
        _banner(AdPlacement.preGame),
      ],
    );
  }

  Widget _noGrid(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'There are not enough words that fit a grid yet. Try another game.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: TestIds.mgDone(_g),
            onPressed: widget.onExit,
            child: const Text('Done'),
          ),
        ],
      ),
    ),
  );

  Widget _results(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.session.report;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              key: TestIds.mgResults(_g),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    container: true,
                    label:
                        'Round finished. ${r.correct} of ${r.answered} words found. Score $_score.',
                    child: Text(
                      '${r.correct} of ${r.answered} words found',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Score $_score', key: TestIds.mgScore(_g)),
                  if (widget.session.rewardsConfig.starsEnabled) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${r.stars} stars earned',
                      key: TestIds.mgStars(_g),
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    key: TestIds.mgDone(_g),
                    onPressed: widget.onExit,
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ),
        ),
        _banner(AdPlacement.postGame),
      ],
    );
  }

  Widget _play(BuildContext context) {
    final g = _grid!;
    final theme = Theme.of(context);
    final search = g.kind == GridKind.wordSearch;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_found.length} of ${g.placed.length} found',
                  key: TestIds.mgProgress(_g),
                  style: theme.textTheme.labelLarge,
                ),
              ),
              if (_timed)
                Text(
                  clock(max(0, _left)),
                  key: TestIds.mgTimer(_g),
                  semanticsLabel: 'Time left ${clock(max(0, _left))}',
                ),
              const SizedBox(width: 12),
              Text('Score $_score', key: TestIds.mgScore(_g)),
            ],
          ),
          const SizedBox(height: 8),
          _gridView(context, search),
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _message,
                  key: TestIds.mgFeedback(_g),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
          const SizedBox(height: 8),
          if (search) _wordList(context) else _clueList(context),
          if (!search && _clue != null) _letterBank(context),
          const SizedBox(height: 8),
          TextButton(
            key: TestIds.mgGiveUp(_g),
            onPressed: _finish,
            child: const Text('Finish round'),
          ),
        ],
      ),
    );
  }

  Widget _gridView(BuildContext context, bool search) {
    final g = _grid!;
    final pal = MiniGamePalette(context);
    return LayoutBuilder(
      builder: (context, box) {
        final cell = (box.maxWidth / g.cols).clamp(22.0, 52.0);
        final foundCells = <(int, int)>{
          for (final w in g.placed)
            if (_found.contains(w.word.id)) ...w.cells,
        };
        final preview = <(int, int)>{
          if (_anchor != null)
            ...(lineBetween(_anchor!, _hover ?? _anchor!) ?? [_anchor!]),
        };
        final clueCells = <(int, int)>{
          if (!search && _clue != null) ...g.placed[_clue!].cells,
        };
        final numbered = {
          for (final w in g.placed)
            if (w.number > 0) (w.row, w.col): w.number,
        };
        final body = Column(
          key: TestIds.mgGrid(_g),
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < g.rows; r++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var c = 0; c < g.cols; c++)
                    _cell(
                      pal,
                      g,
                      r,
                      c,
                      cell,
                      search,
                      foundCells,
                      preview,
                      clueCells,
                      numbered[(r, c)],
                    ),
                ],
              ),
          ],
        );
        final label = search
            ? 'Letter grid, ${g.rows} by ${g.cols}. Tap the first and the last letter of a word.'
            : 'Crossword grid. Use the clues below to fill it in.';
        return Center(
          child: Semantics(
            label: label,
            child: search
                ? GestureDetector(
                    onTapUp: (d) {
                      final c = _cellAt(d.localPosition, cell);
                      if (c != null) _cellTap(c);
                    },
                    onPanStart: (d) => setState(() {
                      _anchor = _cellAt(d.localPosition, cell);
                      _hover = _anchor;
                    }),
                    onPanUpdate: (d) {
                      final c = _cellAt(d.localPosition, cell);
                      if (c != null && c != _hover) setState(() => _hover = c);
                    },
                    onPanEnd: (_) {
                      final a = _anchor, b = _hover;
                      if (a != null && b != null && a != b) {
                        _trySelect(a, b);
                      } else {
                        setState(() => _hover = null);
                      }
                    },
                    child: body,
                  )
                : body,
          ),
        );
      },
    );
  }

  Widget _cell(
    MiniGamePalette pal,
    WordGrid g,
    int r,
    int c,
    double size,
    bool search,
    Set<(int, int)> foundCells,
    Set<(int, int)> preview,
    Set<(int, int)> clueCells,
    int? number,
  ) {
    final letter = g.letters[r][c];
    final isFound = foundCells.contains((r, c));
    final empty = letter.isEmpty;
    final show = search || isFound;
    final fill = empty
        ? Colors.transparent
        : isFound
        ? pal.success
        : preview.contains((r, c))
        ? pal.accent
        : clueCells.contains((r, c))
        ? pal.surface
        : pal.bg;
    final fg = isFound
        ? pal.bg
        : preview.contains((r, c))
        ? pal.onAccent
        : pal.text;
    return Container(
      key: TestIds.mgCell(_g, r, c),
      width: size,
      height: size,
      decoration: empty
          ? null
          : BoxDecoration(
              color: fill,
              border: Border.all(
                color: pal.border,
                width: clueCells.contains((r, c)) ? 2.5 : 0.5,
              ),
            ),
      child: empty
          ? null
          : Stack(
              children: [
                if (number != null)
                  Positioned(
                    left: 2,
                    top: 0,
                    child: ExcludeSemantics(
                      child: Text(
                        '$number',
                        style: TextStyle(fontSize: 9, color: fg),
                      ),
                    ),
                  ),
                Center(
                  child: show
                      ? ExcludeSemantics(
                          child: FittedBox(
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Text(
                                letter,
                                style: TextStyle(
                                  color: fg,
                                  fontWeight: FontWeight.bold,
                                  fontSize: size * 0.55,
                                ),
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
    );
  }

  /// Word search list: the clue for each word, with the word itself for younger children and
  /// in Study mode. Found words are ticked.
  Widget _wordList(BuildContext context) {
    final g = _grid!;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final w in g.placed)
          Chip(
            avatar: _found.contains(w.word.id)
                ? const Icon(Icons.check, size: 18)
                : null,
            label: Text(
              _found.contains(w.word.id) || _showWords
                  ? '${w.word.word}: ${w.word.hint}'
                  : w.word.hint,
            ),
          ),
      ],
    );
  }

  Widget _clueList(BuildContext context) {
    final g = _grid!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < g.placed.length; i++)
          Builder(
            builder: (_) {
              final w = g.placed[i];
              final done = _found.contains(w.word.id);
              return ListTile(
                key: TestIds.mgClue(_g, i),
                dense: true,
                selected: _clue == i,
                leading: done ? const Icon(Icons.check) : null,
                title: Text(
                  '${w.number} ${w.across ? 'across' : 'down'}: ${w.word.hint} (${w.word.word.length} letters)',
                ),
                onTap: done ? null : () => _pickClue(i),
              );
            },
          ),
      ],
    );
  }

  Widget _letterBank(BuildContext context) {
    final pal = MiniGamePalette(context);
    final typed = _typed.map((j) => _bank[j]).join();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Semantics(
            liveRegion: true,
            child: Text(
              typed.isEmpty ? 'Tap the letters in order' : typed,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < _bank.length; i++)
              Semantics(
                button: true,
                excludeSemantics: true,
                label: 'Letter ${_bank[i]}',
                enabled: !_typed.contains(i),
                onTap: _typed.contains(i) ? null : () => _typeLetter(i),
                child: Material(
                  color: _typed.contains(i) ? pal.surface : pal.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: pal.border),
                  ),
                  child: InkWell(
                    key: TestIds.mgLetter(_g, i),
                    borderRadius: BorderRadius.circular(12),
                    onTap: _typed.contains(i) ? null : () => _typeLetter(i),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: Center(
                        child: Text(
                          _bank[i],
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: _typed.contains(i)
                                    ? pal.text.withValues(alpha: 0.7)
                                    : pal.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        TextButton(
          key: TestIds.mgUndo(_g),
          onPressed: _typed.isEmpty ? null : () => setState(_typed.removeLast),
          child: const Text('Undo'),
        ),
      ],
    );
  }
}
