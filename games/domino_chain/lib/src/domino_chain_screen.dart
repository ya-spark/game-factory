import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:game_core/game_core.dart';

import 'domino_chain_ids.dart';
import 'rules/domino_chain_rules.dart';
import 'rules/domino_rules.dart';
import 'ui/domino_art.dart';

/// Domino chain (package and id `domino_chain`): plays `series` items. The steps are dominoes in a
/// tray; the child puts them in the numbered slots in order and presses Go. The chain topples and
/// stops at the first wrong domino. [hard] is the internal flag of the oldest level (no text names
/// it). Spec: `docs/SPEC.md`.
MiniGame dominoChainGameFor({bool hard = false}) => MiniGame(
  id: dominoChainId,
  title: dominoChainTitle,
  itemTypes: const {ItemType.series},
  accepts: (p) => dominoPlayable(p.item),
  minPool: 1,
  build: (ctx) => DominoChainScreen(
    session: ctx.session,
    mode: ctx.mode,
    onExit: ctx.onExit,
    onAnswered: ctx.onAnswered,
    onScore: ctx.onScore,
    level: SeriesLevel.forSession(ctx.session, hard: hard),
  ),
);

/// The registry entry: free, both modes, needs 1 open `series` item (was 3).
final MiniGame dominoChainGame = dominoChainGameFor();

/// How to play, as shown on the start screen (the catalogue and web text say the same).
const String dominoChainHowTo =
    'Put the steps in the right order. Drag the dominoes into the row, or tap a domino and then a '
    'slot. Then press Go: the chain topples, and stops at the first domino that was not next.';

class DominoChainScreen extends StatefulWidget {
  const DominoChainScreen({
    super.key,
    required this.session,
    required this.onExit,
    this.mode = MiniGameMode.game,
    this.level = SeriesLevel.older,
    this.onAnswered,
    this.onScore,
    this.random,
    this.reader,
  });
  final QuizSession session;
  final VoidCallback onExit;
  final MiniGameMode mode;
  final SeriesLevel level;
  final void Function(AnswerResult, QuizSession)? onAnswered;
  final void Function(int)? onScore;
  final Random? random;

  /// Overrides the container's read-aloud (tests); null uses the host's.
  final GameReadAloud? reader;

  @override
  State<DominoChainScreen> createState() => _DominoChainScreenState();
}

enum _Phase { intro, play, results }

/// Where the chain is: editing the row, the topple running, stopped at a wrong domino, solved.
enum _Go { editing, running, stopped, solved }

/// Sizes of the dominoes for one layout.
class _Sz {
  const _Sz(this.w, this.h, this.fs);
  final double w, h, fs;
}

class _DominoChainScreenState extends State<DominoChainScreen>
    with TickerProviderStateMixin {
  static const String _g = dominoChainId;
  static const double _btn = 44;
  static const double _gap = 8;
  static const double _pad = 3;

  late final DominoSettings _cfg = DominoSettings.forLevel(
    widget.level,
    study: widget.mode == MiniGameMode.study,
  );
  late final Random _random = widget.random ?? Random();
  late final AnimationController _timer = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..addStatusListener(_onTimer);
  late final AnimationController _topple = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..addStatusListener(_onToppleDone);

  _Phase _phase = _Phase.intro;
  _Go _go = _Go.editing;
  DominoChain? _chain;
  DominoBoard? _board;
  int _round = 0;
  late final int _chains = dominoChainCount(widget.session.total);
  DominoStage _stage = dominoStageFor(0, 1);

  int? _selTile;
  int _cursor = 0;
  int _slotCursor = 0;
  bool _keyed = false;
  bool _paused = false;
  bool _reduce = false;

  int _attempts = 0;
  bool _hinted = false;
  bool _timedOut = false;
  int _hintsLeft = 0;
  int? _hintSlot;
  int? _hintTile;
  int? _brokenSlot;
  int _fallen = 0;
  bool _rightRun = false;
  int _totalMs = 1000;
  int _timeLimit = 0;
  String _message = '';
  AnswerResult? _result;
  int _chainStars = 0;
  int _stageFirst = 0;
  int _stageStarsNow = 0;
  int _score = 0;
  int _streak = 0;
  int _best = 0;
  bool _scoreSent = false;
  int _lastAnnounced = -1;
  GameReadAloud? _reader;
  bool _autoRead = false;
  int? _autoReadIndex;

  QuizSession get _s => widget.session;
  bool get _timed => _cfg.secondsPerDomino != null;
  bool get _canPlay =>
      _phase == _Phase.play &&
      _go != _Go.running &&
      _go != _Go.solved &&
      !_paused &&
      _board != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final host = GameHostScope.of(context);
    _reader = resolveReader(context, widget.reader);
    _autoRead = host.autoRead(context);
    _reduce = reduceMotionOf(context);
  }

  @override
  void dispose() {
    _timer.dispose();
    _topple.dispose();
    _reader?.stop();
    super.dispose();
  }

  // ---- flow ------------------------------------------------------------------

  void _start() {
    if (_phase != _Phase.intro) return;
    setState(() => _phase = _Phase.play);
    _beginChain();
  }

  void _beginChain() {
    if (_s.finished || _s.index >= _chains) return _toResults();
    final item = _s.items[_s.index].item;
    if (!dominoPlayable(item)) return _toResults();
    final chain = DominoChain.fromItem(item, widget.level, _random);
    _round = _s.index;
    _chain = chain;
    _board = DominoBoard(tiles: chain.tiles, steps: chain.steps);
    _stage = dominoStageFor(_round, _chains);
    if (_stage.indexInStage == 0) _stageFirst = 0;
    _stageStarsNow = 0;
    _go = _Go.editing;
    _selTile = null;
    _cursor = 0;
    _slotCursor = 0;
    _attempts = 0;
    _hinted = false;
    _timedOut = false;
    _hintsLeft = _cfg.hints;
    _hintSlot = null;
    _hintTile = null;
    _brokenSlot = null;
    _fallen = 0;
    _rightRun = false;
    _result = null;
    _message = '';
    _lastAnnounced = -1;
    _topple.value = 0;
    final limit = _cfg.timeLimit(chain.total);
    _timeLimit = limit ?? 0;
    if (limit != null) {
      _timer.duration = Duration(seconds: limit);
      _timer.forward(from: 0);
    }
    _maybeAutoRead();
    if (mounted) setState(() {});
  }

  void _toResults() {
    _timer.stop();
    if (!_scoreSent) {
      _scoreSent = true;
      widget.onScore?.call(_score);
    }
    if (mounted) setState(() => _phase = _Phase.results);
  }

  void _onTimer(AnimationStatus st) {
    if (st != AnimationStatus.completed || _paused) return;
    if (_phase != _Phase.play || _go == _Go.solved) return;
    // Time is up: the game stops editing and topples what is right, then shows the order.
    _topple.stop();
    _timedOut = true;
    _board!.solve();
    _selTile = null;
    _hintSlot = null;
    _hintTile = null;
    _runTopple(right: true);
  }

  // ---- placing dominoes ----------------------------------------------------------

  /// Any edit ends a stop: the row is being fixed.
  void _edited() {
    _selTile = null;
    _hintSlot = null;
    _hintTile = null;
    if (_go == _Go.stopped) {
      _go = _Go.editing;
      _brokenSlot = null;
      _fallen = 0;
    }
    _message = '';
  }

  void _announce(String text) => _message = text;

  void _placeTile(int tile, {int? slot}) {
    if (!_canPlay) return;
    final board = _board!;
    final from = board.slotOf(tile);
    if (!board.place(tile, slot: slot)) return;
    final at = board.slotOf(tile)!;
    setState(() {
      _edited();
      _slotCursor = at;
      _announce(
        from == null
            ? 'Placed ${board.tiles[tile]} in slot ${at + 1}'
            : 'Moved ${board.tiles[tile]} to slot ${at + 1}',
      );
    });
  }

  void _tapTile(int i) {
    if (!_canPlay) return;
    final board = _board!;
    setState(() {
      _cursor = i;
      final slot = board.slotOf(i);
      if (slot != null) {
        board.take(slot);
        _edited();
        _announce('Took back ${board.tiles[i]}');
      } else {
        _selTile = _selTile == i ? null : i;
        _hintSlot = null;
        _hintTile = null;
      }
    });
  }

  void _tapSlot(int s) {
    if (!_canPlay) return;
    final board = _board!;
    final sel = _selTile;
    if (sel != null) {
      _placeTile(sel, slot: s);
    } else if (board.tileAt(s) != null) {
      final t = board.tileAt(s)!;
      setState(() {
        board.take(s);
        _edited();
        _announce('Took back ${board.tiles[t]}');
      });
    }
  }

  void _takeLast() {
    if (!_canPlay) return;
    final board = _board!;
    final last = board.takeLast();
    if (!last) return;
    setState(() {
      _edited();
      _keyed = true;
      _announce('Took back the last domino');
    });
  }

  void _useHint() {
    if (!_canPlay || _hintsLeft <= 0) return;
    final board = _board!;
    final slot = board.hintSlot;
    if (slot == null) return;
    setState(() {
      _hintsLeft--;
      _hinted = true;
      _selTile = null;
      _hintSlot = slot;
      _hintTile = board.hintTile;
      _announce('Hint: slot ${slot + 1} comes next');
    });
  }

  // ---- Go and the topple ------------------------------------------------------------

  void _pressGo() {
    if (_phase != _Phase.play || _paused) return;
    if (_go == _Go.running) {
      // Go again while the chain topples: skip to the end.
      _topple.value = 1;
      return;
    }
    final board = _board;
    if (board == null || _go == _Go.solved || !board.isFull) return;
    final v = board.verdict;
    _attempts++;
    _selTile = null;
    _hintSlot = null;
    _hintTile = null;
    _message = '';
    if (v.isRight) {
      _timer.stop();
      _runTopple(right: true);
    } else {
      _brokenSlot = v.firstWrong;
      _runTopple(right: false);
    }
  }

  /// Plays the topple: a ready nudge (150 ms), each domino tips for 350 ms with a 120 ms overlap into
  /// the next; right: 400 ms pause then the flag pops (300 ms); wrong: the broken domino wobbles
  /// for 500 ms.
  void _runTopple({required bool right}) {
    final board = _board!;
    _rightRun = right;
    _fallen = right ? board.slotCount : (board.firstWrong ?? 0);
    _go = _Go.running;
    final tipEnd = 150 + (_fallen > 0 ? (_fallen - 1) * 230 + 350 : 0);
    _totalMs = tipEnd + (right ? 700 : 500);
    _topple.duration = Duration(milliseconds: _totalMs);
    if (_reduce) {
      _topple.value = 1;
      _onToppleDone(AnimationStatus.completed);
      return;
    }
    _topple.forward(from: 0);
    setState(() {});
  }

  void _onToppleDone(AnimationStatus st) {
    if (st != AnimationStatus.completed || _go != _Go.running) return;
    if (_rightRun) {
      _finishSolved();
    } else {
      final board = _board!;
      final k = board.firstWrong ?? 0;
      _go = _Go.stopped;
      _brokenSlot = k;
      _fallen = k;
      final txt = board.textAt(k) ?? '';
      _message = 'Slot ${k + 1} was not the next step. Try swapping it.';
      _stopNote =
          'The chain stopped at slot ${k + 1}: $txt was not the next step. '
          '${k == 0 ? 'No slot was right yet.' : (k == 1 ? 'Slot 1 was right.' : 'Slots 1 to $k were right.')}';
      if (mounted) setState(() {});
    }
  }

  String _stopNote = '';

  void _finishSolved() {
    final study = widget.mode == MiniGameMode.study;
    final correct = dominoChainCorrect(
      attempts: _attempts,
      hinted: _hinted,
      timedOut: _timedOut,
      study: study,
    );
    final firstTry = _attempts <= 1 && !_hinted && !_timedOut;
    final r = _s.answer(correct: correct, hinted: _hinted, timedOut: _timedOut);
    widget.onAnswered?.call(r, _s);
    if (!_timedOut) {
      _score += dominoChainScore(
        attempts: _hinted && _attempts <= 1 ? 2 : _attempts,
        streak: _streak,
        older: widget.level.isOlder,
      );
    }
    if (firstTry) {
      _streak++;
      if (_streak > _best) _best = _streak;
      _stageFirst++;
    } else {
      _streak = 0;
    }
    _chainStars = dominoChainStars(
      _timedOut ? 3 : (_hinted && _attempts <= 1 ? 2 : _attempts),
    );
    if (_stage.endsStage) {
      _stageStarsNow = dominoStageStars(
        firstTry: _stageFirst,
        chains: _stage.chains,
      );
    }
    _result = AnswerResult(
      correct: correct,
      firstPass: r.firstPass,
      stars: r.stars,
      coins: r.coins,
      topicCompleted: r.topicCompleted,
      explanation: r.explanation,
    );
    _go = _Go.solved;
    _fallen = _board!.slotCount;
    _message = _timedOut
        ? "Time's up. This is the right order."
        : 'The chain toppled all the way. Flag up. $_chainStars ${_chainStars == 1 ? 'star' : 'stars'}.';
    if (mounted) setState(() {});
  }

  void _next() {
    if (_go != _Go.solved) return;
    if (_s.finished || _s.index >= _chains) {
      _toResults();
    } else {
      _beginChain();
    }
  }

  // ---- pause, reading ----------------------------------------------------------

  void _togglePause() {
    if (_phase != _Phase.play || _go == _Go.solved) return;
    setState(() => _paused = !_paused);
    if (_paused) {
      _timer.stop();
      _topple.stop();
      _reader?.stop();
    } else {
      if (_timed && _go != _Go.solved) _timer.forward();
      if (_go == _Go.running) _topple.forward();
    }
  }

  String get _promptText {
    final c = _chain;
    final prompt =
        (_s.index < _s.items.length
            ? _s.items[_s.index].item.json['prompt']
            : null) ??
        'Put these in order.';
    if (c == null) return '$prompt';
    return '$prompt The steps are: ${c.tiles.join('. ')}.';
  }

  Future<void> _read() => _reader == null
      ? Future.value()
      : _reader!.read(
          _promptText,
          audioRef: _s.index < _s.items.length
              ? _s.items[_s.index].item.audio
              : null,
        );

  void _maybeAutoRead() {
    if (!_autoRead || _reader == null || _autoReadIndex == _s.index) return;
    _autoReadIndex = _s.index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _go != _Go.solved) _read();
    });
  }

  // ---- keyboard (docs/SPEC.md, Keyboard) -----------------------------------------

  void _onInput(GameInput i) {
    final a = i.action;
    if (a == GameAction.exit) {
      if (i.repeat) return;
      // Esc pauses a chain (the pause screen offers Leave, Esc resumes); elsewhere it leaves.
      if (_phase == _Phase.play && _go != _Go.solved && !_paused) {
        _togglePause();
      } else if (_paused) {
        _togglePause();
      } else {
        widget.onExit();
      }
      return;
    }
    final moves = a == GameAction.left || a == GameAction.right;
    if (i.repeat && !moves) return;
    switch (_phase) {
      case _Phase.intro:
        if (a == GameAction.action || a == GameAction.pause) _start();
      case _Phase.results:
        if (a == GameAction.action || a == GameAction.pause) widget.onExit();
      case _Phase.play:
        _playKey(a, moves);
    }
  }

  void _playKey(GameAction a, bool moves) {
    if (_paused) {
      if (a == GameAction.pause) _togglePause();
      return;
    }
    if (_go == _Go.solved) {
      if (a == GameAction.action || a == GameAction.pause) _next();
      return;
    }
    if (_go == _Go.running) {
      if (a == GameAction.action || a == GameAction.pause) _pressGo();
      return;
    }
    final board = _board;
    if (board == null) return;
    final n = board.tiles.length;
    if (a == GameAction.pause) {
      // Space: Go when every slot is full, else pause.
      board.isFull ? _pressGo() : _togglePause();
    } else if (moves) {
      final d = a == GameAction.left ? -1 : 1;
      setState(() {
        _keyed = true;
        if (_selTile != null) {
          _slotCursor = (_slotCursor + d) % board.slotCount;
        } else {
          _cursor = (_cursor + d) % n;
        }
      });
    } else if (a == GameAction.action || a == GameAction.up) {
      setState(() => _keyed = true);
      if (_go == _Go.stopped && _selTile == null && board.isFull) {
        // After a wrong Go: Enter goes back to editing.
        setState(() {
          _edited();
          _announce('Fix it: swap the dominoes, then press Go.');
        });
        return;
      }
      _enter();
    } else if (a == GameAction.down) {
      _takeLast();
    } else if (a.pickNumber != null && a.pickNumber! <= n) {
      final t = a.pickNumber! - 1;
      setState(() {
        _keyed = true;
        _cursor = t;
      });
      _cursorEnter(t);
    } else if (a == GameAction.question && _reader != null) {
      _read();
    }
  }

  /// Enter: with a held domino, place it in the chosen slot; else act on the domino under the cursor.
  void _enter() {
    final sel = _selTile;
    if (sel != null) {
      _placeTile(sel, slot: _slotCursor);
    } else {
      _cursorEnter(_cursor);
    }
  }

  /// Enter on a domino: places it in the next empty slot, or takes it back when it is placed.
  void _cursorEnter(int tile) {
    final board = _board!;
    final slot = board.slotOf(tile);
    if (slot != null) {
      setState(() {
        board.take(slot);
        _edited();
        _announce('Took back ${board.tiles[tile]}');
      });
    } else {
      _placeTile(tile);
    }
  }

  /// Backspace and Delete take back the last domino, H is the hint; the shared map has neither.
  KeyEventResult _rawKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || _phase != _Phase.play || _paused) {
      return KeyEventResult.ignored;
    }
    final hw = HardwareKeyboard.instance;
    if (hw.isControlPressed || hw.isAltPressed || hw.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.backspace || k == LogicalKeyboardKey.delete) {
      if (_canPlay) _takeLast();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyH && event is KeyDownEvent) {
      if (_canPlay) _useHint();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  List<GameAction> get _hintActions => switch (_phase) {
    _Phase.intro ||
    _Phase.results => const [GameAction.action, GameAction.exit],
    _Phase.play =>
      _go == _Go.solved
          ? const [GameAction.action, GameAction.exit]
          : [
              GameAction.left,
              GameAction.right,
              GameAction.action,
              GameAction.pick1,
              GameAction.pick2,
              GameAction.pick3,
              GameAction.pick4,
              GameAction.pause,
              GameAction.question,
              GameAction.exit,
            ],
  };

  Map<GameAction, String> get _hintWords => {
    GameAction.left: 'choose',
    GameAction.action: _phase == _Phase.play
        ? (_go == _Go.solved ? 'next' : 'place')
        : 'go',
    GameAction.pick1: 'domino',
    GameAction.pause: (_board?.isFull ?? false) ? 'go' : 'pause',
    GameAction.question: 'read',
  };

  /// The label of the key that does [a], for a button ("Go (Space)").
  String _key(GameAction a) {
    final map = GameKeysScope.read(context);
    return keyLabel(map.primaryOf(KeySlot(a, a.shared ? 0 : 1)));
  }

  // ---- build ---------------------------------------------------------------------

  Widget _banner(GameBannerSlot slot) {
    final host = GameHostScope.of(context);
    final wide = WindowClass.ofContext(context) != WindowClass.compact;
    if (wide && host.adUnit(context, GameAdFormat.leaderboard) != null) {
      return const SizedBox.shrink();
    }
    return KeyedSubtree(
      key: GameIds.mgBanner(_g),
      child: host.banner(context, slot),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = WindowClass.ofContext(context) != WindowClass.compact;
    return Scaffold(
      key: GameIds.mgScreen(_g),
      body: SafeArea(
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: _rawKey,
          child: GameKeyboard(
            onInput: _onInput,
            child: GameFrame(
              showAds: _phase != _Phase.play,
              phoneBanner: null,
              child: LayoutBuilder(
                builder: (context, box) {
                  // Key hints need room: on a short window the play area keeps the height.
                  final showHints = wide && box.maxHeight >= 520;
                  return Column(
                    children: [
                      // No title bar (owner, 2026-11-21): the host shows the name. Exit, pause and
                      // read aloud are small overlays on the play area.
                      Expanded(
                        child: Stack(
                          children: [
                            switch (_phase) {
                              _Phase.intro => _intro(context),
                              _Phase.play => _play(context),
                              _Phase.results => _results(context),
                            },
                            _overlayButtons(context),
                            if (_paused)
                              PauseOverlay(
                                overlayKey: GameIds.mgPaused(_g),
                                resumeKey: GameIds.mgResume(_g),
                                onResume: _togglePause,
                                onLeave: widget.onExit,
                                leaveKey: GameIds.mgLeave(_g),
                              ),
                          ],
                        ),
                      ),
                      if (showHints) _hints(context),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlayButtons(BuildContext context) {
    final playing = _phase == _Phase.play;
    final canPause = playing && _go != _Go.solved;
    final style = IconButton.styleFrom(
      fixedSize: const Size(_btn, _btn),
      minimumSize: const Size(_btn, _btn),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: IconButton.filledTonal(
              key: GameIds.mgExit(_g),
              style: style,
              tooltip: 'Leave the game (Esc)',
              icon: const Icon(Icons.close),
              onPressed: widget.onExit,
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (playing && _reader != null)
                  IconButton.filledTonal(
                    key: GameIds.mgSpeak(_g),
                    style: style,
                    tooltip: 'Read the steps aloud (Q)',
                    icon: const Icon(Icons.volume_up),
                    onPressed: _read,
                  ),
                if (canPause) ...[
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    key: GameIds.mgPause(_g),
                    style: style,
                    tooltip: _paused ? 'Resume' : 'Pause',
                    icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                    onPressed: _togglePause,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hints(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 14,
        runSpacing: 6,
        children: [
          KeyHints(
            actions: _hintActions,
            words: _hintWords,
            spaceGoesOn: _phase != _Phase.play || _go == _Go.solved,
          ),
          if (_phase == _Phase.play && _go != _Go.solved) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const KeyCap(label: 'Backspace'),
                const SizedBox(width: 6),
                Text('take back', style: style),
              ],
            ),
            if (_cfg.hints > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const KeyCap(label: 'H'),
                  const SizedBox(width: 6),
                  Text('hint', style: style),
                ],
              ),
          ],
        ],
      ),
    );
  }

  // ---- start and results -------------------------------------------------------------

  Widget _artBox(DominoRowPainter painter, String? label, bool short) {
    final art = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CustomPaint(painter: painter),
    );
    return SizedBox(
      height: short ? 80 : 150,
      width: short ? 160 : 300,
      child: label == null
          ? ExcludeSemantics(child: art)
          : Semantics(image: true, label: label, child: art),
    );
  }

  Widget _intro(BuildContext context) {
    final theme = Theme.of(context);
    final short = MediaQuery.sizeOf(context).height < 480;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              key: GameIds.mgIntro(_g),
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _artBox(
                    const DominoRowPainter(backdrop: DominoBackdrop.floor),
                    'A row of toy dominoes stands ready to topple',
                    short,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    dominoChainHowTo,
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: short ? 12 : 24),
                  FilledButton(
                    key: GameIds.mgStart(_g),
                    onPressed: _start,
                    child: Text('Start (${_key(GameAction.action)})'),
                  ),
                ],
              ),
            ),
          ),
        ),
        _banner(GameBannerSlot.preGame),
      ],
    );
  }

  Widget _results(BuildContext context) {
    final theme = Theme.of(context);
    final short = MediaQuery.sizeOf(context).height < 480;
    final r = _s.report;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              key: GameIds.mgResults(_g),
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _artBox(
                    const DominoRowPainter(
                      backdrop: DominoBackdrop.sill,
                      fallen: 5,
                      flag: true,
                    ),
                    null,
                    short,
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    container: true,
                    label:
                        'Round finished. ${r.correct} of ${r.answered} right first time. Score $_score.',
                    child: Text(
                      '${r.correct} of ${r.answered} right',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Score $_score', key: GameIds.mgScore(_g)),
                  if (widget.level.isOlder && _best > 1)
                    Text('Best streak $_best in a row'),
                  if (_s.rewardsConfig.starsEnabled) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${r.stars} stars earned',
                      key: GameIds.mgStars(_g),
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                  SizedBox(height: short ? 12 : 24),
                  FilledButton(
                    key: GameIds.mgDone(_g),
                    onPressed: widget.onExit,
                    child: Text('Done (${_key(GameAction.action)})'),
                  ),
                ],
              ),
            ),
          ),
        ),
        _banner(GameBannerSlot.postGame),
      ],
    );
  }

  // ---- play: layout ------------------------------------------------------------------

  /// The domino sizes tried from large to small; the last one is the floor (44 dp wide, 64 dp tall
  /// at least). `long` dominoes are wide.
  static const _shortSizes = [
    _Sz(120, 92, 20),
    _Sz(108, 84, 19),
    _Sz(96, 76, 17),
    _Sz(84, 70, 16),
    _Sz(72, 66, 15),
    _Sz(64, 64, 14),
    _Sz(56, 64, 13),
    _Sz(44, 64, 12),
  ];
  static const _longSizes = [
    _Sz(190, 92, 18),
    _Sz(160, 86, 17),
    _Sz(150, 80, 16),
    _Sz(132, 76, 15),
    _Sz(116, 72, 14),
    _Sz(104, 68, 13),
    _Sz(96, 64, 13),
  ];

  /// Picks the biggest domino size whose slot row and tray fit [availH] (portrait: both stack in
  /// it; landscape: the slot rows in [availH] on the left, the tray in [availH] on the right).
  _Sz _fit({
    required DominoChain chain,
    required double slotW,
    required double trayW,
    required double slotH,
    required double trayH,
    required bool stacked,
    required double scale,
  }) {
    final n = chain.total;
    final ts = scale.clamp(1.0, 1.5);
    final list = chain.size == DominoSize.long ? _longSizes : _shortSizes;
    var pick = list.last;
    for (final c in list) {
      final w = c.w * ts, h = c.h * ts;
      final sPer = max(
        1,
        ((slotW - h * 0.28 + _gap) / (w + 2 * _pad + _gap)).floor(),
      );
      final tPer = max(1, ((trayW + _gap) / (w + _gap)).floor());
      final sRows = (n / sPer).ceil();
      final tRows = (n / tPer).ceil();
      final sH = sRows * (h + 2 * _pad + _gap);
      final tH = tRows * (h + _gap + 4);
      final ok = stacked ? sH + tH <= slotH : (sH <= slotH && tH <= trayH);
      pick = c;
      if (ok) break;
    }
    return _Sz(pick.w * ts, pick.h * ts, pick.fs);
  }

  Widget _play(BuildContext context) {
    final chain = _chain, board = _board;
    if (chain == null || board == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    final ts = scale.clamp(1.0, 1.6);
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        final strip = scale > 1.2 ? 56.0 : 44.0;
        final landscape = h < 460 && w > h * 1.3;
        final headerH = 64.0 * ts;
        final msgH = 40.0 * ts;
        final btnH = 52.0 * max(1.0, ts * 0.9);
        final body = h - strip;
        Widget content;
        if (landscape) {
          final leftW = w * 0.56;
          final rightW = w - leftW;
          final sz = _fit(
            chain: chain,
            slotW: leftW - 24 - 2 * 12,
            trayW: rightW - 24,
            slotH: body - headerH - msgH - 24 - 16 - 8,
            trayH: body - btnH - 16 - 8,
            stacked: false,
            scale: scale,
          );
          content = Row(
            children: [
              SizedBox(
                width: leftW,
                child: SingleChildScrollView(
                  key: DominoChainIds.tableScroll(_g),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      _table(context, chain, board, sz, headerH),
                      const SizedBox(height: 4),
                      _messageLine(theme, msgH),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        key: DominoChainIds.tray(_g),
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                        child: _trayArea(context, chain, board, sz, theme),
                      ),
                    ),
                    _buttons(board),
                  ],
                ),
              ),
            ],
          );
        } else {
          final sz = _fit(
            chain: chain,
            slotW: w - 24 - 24,
            trayW: w - 24,
            slotH: body - headerH - msgH - btnH - 24 - 24 - 20,
            trayH: 0,
            stacked: true,
            scale: scale,
          );
          // The table, the message and the tray scroll together only when the window is too small
          // for them (large text on a short phone); Go and Next stay in view.
          content = Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  key: DominoChainIds.tray(_g),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      _table(context, chain, board, sz, headerH),
                      const SizedBox(height: 4),
                      _messageLine(theme, msgH),
                      _trayArea(context, chain, board, sz, theme),
                    ],
                  ),
                ),
              ),
              _buttons(board),
            ],
          );
        }
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Column(
              children: [
                SizedBox(height: strip, child: _hud(theme)),
                Expanded(child: content),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Chain, stage, score and timer inside the play area, between the exit and pause buttons.
  Widget _hud(ThemeData theme) {
    final speak = _reader != null;
    return Padding(
      padding: EdgeInsets.only(left: 52, right: speak ? 104 : 52),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Chain ${_round + 1} of $_chains · Stage ${_stage.stage + 1}',
                key: GameIds.mgProgress(_g),
                style: theme.textTheme.labelLarge,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Score $_score',
                    key: GameIds.mgScore(_g),
                    style: theme.textTheme.labelLarge,
                  ),
                  if (_timed) ...[
                    const SizedBox(width: 12),
                    _timerLabel(theme),
                  ],
                ],
              ),
              if (_timed)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: ExcludeSemantics(
                    child: SizedBox(
                      width: 140,
                      child: AnimatedBuilder(
                        animation: _timer,
                        builder: (_, _) => LinearProgressIndicator(
                          value: 1 - _timer.value,
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timerLabel(ThemeData theme) {
    return AnimatedBuilder(
      animation: _timer,
      builder: (_, _) {
        final left = (_timeLimit * (1 - _timer.value)).ceil();
        if (announceTimeLeft(left) && _lastAnnounced != left) {
          _lastAnnounced = left;
        }
        return Semantics(
          label: 'Time left ${clock(left)}',
          excludeSemantics: true,
          liveRegion: announceTimeLeft(left),
          child: Text(
            clock(left),
            key: GameIds.mgTimer(_g),
            style: theme.textTheme.labelLarge,
          ),
        );
      },
    );
  }

  /// The one line under the table: the chosen domino's full text, the last message, or the
  /// instruction. A live region.
  Widget _messageLine(ThemeData theme, double height) {
    final board = _board!;
    final sel = _selTile;
    final String text;
    Key key = DominoChainIds.message(_g);
    if (sel != null && _canPlay) {
      text = 'Selected: ${board.tiles[sel]}. Tap a slot to put it in.';
      key = DominoChainIds.caption(_g);
    } else if (_message.isNotEmpty) {
      text = _message;
    } else if (!board.isFull) {
      text = board.isEmpty
          ? 'Drag a domino into a slot, or tap a domino and then a slot.'
          : 'Fill every slot, then press Go.';
    } else {
      text = 'Every slot is full. Press Go!';
    }
    return Semantics(
      liveRegion: true,
      container: true,
      label: _go == _Go.stopped && _message.isNotEmpty ? _stopNote : null,
      child: SizedBox(
        height: height,
        child: Center(
          child: Text(
            text,
            key: key,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _go == _Go.stopped ? dominoRed : null,
              fontWeight: _go == _Go.stopped ? FontWeight.w700 : null,
            ),
          ),
        ),
      ),
    );
  }

  // ---- the table: sign, flag, slots ----------------------------------------------------

  /// A tipped domino is drawn squashed and leaning to the right (tip 1 = lying down).
  static const double _tipAngle = 1.0;

  double _tipOf(int i) {
    switch (_go) {
      case _Go.editing:
        return 0;
      case _Go.stopped:
        return i < _fallen ? _tipAngle : 0;
      case _Go.solved:
        return _tipAngle;
      case _Go.running:
        final ms = _topple.value * _totalMs;
        if (i >= _fallen) return 0;
        final start = 150.0 + i * 230;
        final p = ((ms - start) / 350).clamp(0.0, 1.0);
        final nudge = i == 0 && ms < 150 ? sin(ms / 150 * pi) * 0.08 : 0.0;
        return Curves.easeIn.transform(p) * _tipAngle + nudge;
    }
  }

  /// 0..1 progress of the wobble of the broken domino while the wrong run plays.
  double get _wobbleP {
    if (_go != _Go.running || _rightRun) return 0;
    final ms = _topple.value * _totalMs;
    final tipEnd = 150 + (_fallen > 0 ? (_fallen - 1) * 230 + 350 : 0);
    return ((ms - tipEnd) / 500).clamp(0.0, 1.0);
  }

  double get _flagPop {
    if (_go == _Go.solved) return 1;
    if (_go != _Go.running || !_rightRun) return 0;
    final ms = _topple.value * _totalMs;
    final tipEnd = 150 + (_fallen > 0 ? (_fallen - 1) * 230 + 350 : 0);
    return ((ms - tipEnd - 400) / 300).clamp(0.0, 1.0);
  }

  DominoLook _look(int i) {
    if (_go == _Go.solved) return DominoLook.tipped;
    if (_brokenSlot == i && (_go == _Go.stopped || _wobbleP > 0)) {
      return DominoLook.broken;
    }
    if (_tipOf(i) > 0.3) return DominoLook.tipped;
    return DominoLook.rest;
  }

  Widget _table(
    BuildContext context,
    DominoChain chain,
    DominoBoard board,
    _Sz sz,
    double headerH,
  ) {
    return AnimatedBuilder(
      animation: _topple,
      builder: (context, _) {
        final scene = _go == _Go.solved
            ? 'The chain toppled all the way and the flag is up'
            : (_go == _Go.stopped
                  ? 'The chain stopped at slot ${(_brokenSlot ?? 0) + 1}'
                  : 'Dominoes wait in slots on a table');
        return Container(
          key: DominoChainIds.scene(_g),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: dominoInk, width: 3),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Semantics(
                  image: true,
                  label: scene,
                  child: CustomPaint(
                    painter: DominoBackdropPainter(_stage.backdrop),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(10, 6, 10 + sz.h * 0.28, 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: headerH - 8,
                      child: Row(
                        children: [
                          Expanded(child: _sign(context)),
                          const SizedBox(width: 8),
                          _flag(headerH - 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    _slotRow(context, chain, board, sz),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sign(BuildContext context) {
    final theme = Theme.of(context);
    final prompt =
        (_s.index < _s.items.length
            ? _s.items[_s.index].item.json['prompt']
            : null) ??
        'Put these in order.';
    return Semantics(
      key: DominoChainIds.sign(_g),
      container: true,
      label: 'Sign: $prompt',
      child: ExcludeSemantics(
        child: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: dominoCream,
            border: Border.all(color: dominoInk, width: 3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$prompt',
            key: GameIds.mgPrompt(_g),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: dominoInk,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _flag(double height) {
    final solved = _go == _Go.solved;
    final pop = _flagPop;
    return Semantics(
      key: DominoChainIds.flag(_g),
      label: solved
          ? 'Flag up: $_chainStars of 3 stars'
          : 'A flag waits at the end of the chain',
      child: SizedBox(
        width: height * 1.25,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: CustomPaint(painter: ToyFlagPainter(pop: pop)),
              ),
            ),
            if (solved && !_timedOut)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ExcludeSemantics(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '★' * _chainStars,
                      style: const TextStyle(
                        color: Color(0xFFFFB400),
                        fontSize: 18,
                        shadows: [Shadow(color: dominoInk, blurRadius: 2)],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _slotRow(
    BuildContext context,
    DominoChain chain,
    DominoBoard board,
    _Sz sz,
  ) {
    return Wrap(
      key: DominoChainIds.row(_g),
      alignment: WrapAlignment.center,
      spacing: _gap,
      runSpacing: _gap,
      children: [
        for (var i = 0; i < board.slotCount; i++) _slot(context, board, i, sz),
      ],
    );
  }

  // ---- a domino ------------------------------------------------------------------------

  /// The face: art plus the step text. [angle] tips it around its bottom right corner.
  Widget _face(
    String text,
    int tileIndex,
    _Sz sz,
    DominoChain chain, {
    DominoLook look = DominoLook.rest,
    bool cursor = false,
    bool lit = false,
    bool lifted = false,
    double tip = 0,
    double shake = 0,
  }) {
    final theme = Theme.of(context);
    final long = chain.size == DominoSize.long;
    final face = SizedBox(
      width: sz.w,
      height: sz.h,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: DominoFacePainter(
                band: dominoBand(tileIndex),
                look: look,
              ),
            ),
          ),
          Positioned.fill(
            top: sz.h * 0.2,
            bottom: 6,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Center(
                child: Text(
                  text,
                  maxLines: long || sz.h >= 70 ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: sz.fs,
                    color: dominoInk,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
              ),
            ),
          ),
          if (cursor || lit)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(min(sz.w, sz.h) * 0.16),
                    border: Border.all(
                      color: lit
                          ? const Color(0xFFFFB400)
                          : theme.colorScheme.tertiary,
                      width: 5,
                    ),
                  ),
                ),
              ),
            ),
          if (look == DominoLook.broken)
            Positioned(
              right: -2,
              top: -2,
              child: ExcludeSemantics(
                child: Container(
                  key: DominoChainIds.broken(_g),
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: dominoRed,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Text(
                    '?',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    Widget out = face;
    if (tip != 0) {
      // Falling right: the top slides right and the whole domino flattens, never taller than at rest.
      out = Transform(
        alignment: Alignment.bottomCenter,
        transform: Matrix4.identity()
          ..setEntry(0, 1, -0.55 * tip)
          ..setEntry(1, 1, 1 - 0.38 * tip),
        child: face,
      );
    }
    if (shake != 0) {
      out = Transform.rotate(
        angle: shake,
        alignment: Alignment.bottomCenter,
        child: out,
      );
    }
    return out;
  }

  Widget _slot(BuildContext context, DominoBoard board, int i, _Sz sz) {
    final theme = Theme.of(context);
    final chain = _chain!;
    final tile = board.tileAt(i);
    final n = board.slotCount;
    final editable = _canPlay;
    final slotSz = Size(sz.w + 2 * _pad, sz.h + 2 * _pad);
    final next = board.firstEmpty == i && editable;
    final cur = _keyed && _selTile != null && _slotCursor == i;
    final lit = _hintSlot == i;
    final label = tile == null
        ? 'Slot ${i + 1} of $n, empty'
        : 'Slot ${i + 1} of $n, ${board.tiles[tile]}'
              '${_brokenSlot == i && _go == _Go.stopped ? ', was not the next step' : ''}';
    final Widget content;
    if (tile == null) {
      content = Container(
        width: slotSz.width,
        height: slotSz.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: lit
                ? const Color(0xFFFFB400)
                : (cur
                      ? theme.colorScheme.tertiary
                      : dominoInk.withValues(alpha: next ? 0.9 : 0.45)),
            width: lit || cur || next ? 4 : 2,
          ),
        ),
        child: Text(
          '${i + 1}',
          style: theme.textTheme.titleLarge?.copyWith(
            color: dominoInk.withValues(alpha: 0.55),
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    } else {
      final wob = _brokenSlot == i && _wobbleP > 0
          ? sin(_wobbleP * pi * 6) * 0.12 * (1 - _wobbleP)
          : 0.0;
      final look = _look(i);
      Widget dom({bool lifted = false}) => Padding(
        padding: const EdgeInsets.all(_pad),
        child: _face(
          board.tiles[tile],
          tile,
          sz,
          chain,
          look: look,
          lit: lit,
          lifted: lifted,
          tip: lifted ? 0 : _tipOf(i),
          shake: lifted ? 0 : wob,
          cursor: cur,
        ),
      );
      content = SizedBox(
        width: slotSz.width,
        height: slotSz.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Draggable<int>(
              data: tile,
              maxSimultaneousDrags: editable ? 1 : 0,
              feedback: Material(
                type: MaterialType.transparency,
                child: dom(lifted: true),
              ),
              childWhenDragging: Opacity(opacity: 0.3, child: dom()),
              child: dom(),
            ),
            if (_brokenSlot == i && _go == _Go.running && _wobbleP > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Stack(
                      children: [
                        CustomPaint(painter: SparkPainter(_wobbleP)),
                        CustomPaint(painter: DustPainter(_wobbleP)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => editable,
      onAcceptWithDetails: (d) => _placeTile(d.data, slot: i),
      builder: (context, candidates, _) => Semantics(
        button: true,
        enabled: editable,
        excludeSemantics: true,
        label: label,
        onTap: () => _tapSlot(i),
        child: Padding(
          // A drop zone a little larger than the slot (8 dp margin) for touch.
          padding: EdgeInsets.zero,
          child: InkWell(
            key: DominoChainIds.slot(_g, i),
            borderRadius: BorderRadius.circular(12),
            onTap: editable ? () => _tapSlot(i) : null,
            child: AnimatedScale(
              scale: candidates.isNotEmpty ? 1.08 : 1,
              duration: const Duration(milliseconds: 120),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  // ---- the tray, Go, Hint, Next ---------------------------------------------------------

  Widget _trayArea(
    BuildContext context,
    DominoChain chain,
    DominoBoard board,
    _Sz sz,
    ThemeData theme,
  ) {
    if (_go == _Go.solved) return _feedback(theme);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: _gap,
        runSpacing: _gap,
        children: [
          for (var i = 0; i < board.tiles.length; i++)
            _tile(context, chain, board, i, sz),
        ],
      ),
    );
  }

  Widget _buttons(DominoBoard board) {
    final solved = _go == _Go.solved;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: solved
          ? SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: GameIds.mgNext(_g),
                onPressed: _next,
                child: Text(
                  '${_s.finished || _s.index >= _chains ? 'See results' : (_stage.endsStage ? 'Next stage' : 'Next chain')} (${_key(GameAction.action)})',
                ),
              ),
            )
          : _controls(board),
    );
  }

  Widget _controls(DominoBoard board) {
    final running = _go == _Go.running;
    final full = board.isFull;
    return Row(
      children: [
        if (_cfg.hints > 0) ...[
          Expanded(
            flex: 3,
            child: OutlinedButton(
              key: DominoChainIds.hint(_g),
              onPressed: (!running && _hintsLeft > 0 && !_paused)
                  ? _useHint
                  : null,
              child: Text('Hint (H): $_hintsLeft'),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: _cfg.hints > 0 ? 4 : 1,
          child: Semantics(
            container: true,
            button: true,
            enabled: full && !_paused,
            label: full
                ? 'Go, topple the chain'
                : 'Go, fill all ${board.slotCount} slots first',
            excludeSemantics: true,
            child: FilledButton.icon(
              key: DominoChainIds.go(_g),
              onPressed: full && !_paused ? _pressGo : null,
              icon: const SizedBox(
                width: 24,
                height: 24,
                child: CustomPaint(painter: GoLeverPainter()),
              ),
              label: Text('Go (${_key(GameAction.pause)})'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tile(
    BuildContext context,
    DominoChain chain,
    DominoBoard board,
    int i,
    _Sz sz,
  ) {
    final t = board.tiles[i];
    final placed = board.isPlaced(i);
    final selected = _selTile == i;
    final cursor = _keyed && _cursor == i && _selTile == null;
    final lit = _hintTile == i && !placed;
    final slot = board.slotOf(i);
    final editable = _canPlay;
    final label = placed
        ? '$t, domino, in slot ${slot! + 1}'
        : (selected ? '$t, domino, selected' : '$t, domino, in the tray');
    final tipLabel = chain.size == DominoSize.long || t.length > 18 ? t : null;
    final Widget cell = placed
        ? Container(
            width: sz.w,
            height: sz.h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cursor
                    ? Theme.of(context).colorScheme.tertiary
                    : dominoInk.withValues(alpha: 0.3),
                width: cursor ? 5 : 2,
              ),
            ),
          )
        : Draggable<int>(
            data: i,
            maxSimultaneousDrags: editable ? 1 : 0,
            feedback: Material(
              type: MaterialType.transparency,
              child: _face(t, i, sz, chain, lifted: true),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: _face(t, i, sz, chain),
            ),
            child: _face(t, i, sz, chain, cursor: cursor, lit: lit),
          );
    final body = Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: AnimatedScale(
        scale: selected ? 1.1 : 1,
        duration: const Duration(milliseconds: 120),
        child: InkWell(
          key: DominoChainIds.tile(_g, i),
          borderRadius: BorderRadius.circular(12),
          onTap: editable ? () => _tapTile(i) : null,
          child: cell,
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: editable,
      excludeSemantics: true,
      label: label,
      onTap: () => _tapTile(i),
      child: tipLabel == null ? body : Tooltip(message: tipLabel, child: body),
    );
  }

  Widget _feedback(ThemeData theme) {
    final res = _result!;
    final ends = _stage.endsStage;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Column(
        key: GameIds.mgFeedback(_g),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.flag),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _timedOut
                      ? "Time's up. This is the right order."
                      : 'Flag up! $_chainStars of 3 stars.',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Order: ${_board!.steps.join(', then ')}',
            style: theme.textTheme.bodyMedium,
          ),
          if (res.explanation.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(res.explanation, style: theme.textTheme.bodyMedium),
          ],
          if (ends) ...[
            const SizedBox(height: 4),
            Text(
              'Stage complete! $_stageStarsNow of 3 stars at the flag.',
              key: DominoChainIds.stageStars(_g),
              style: theme.textTheme.titleMedium,
            ),
          ],
        ],
      ),
    );
  }
}
