import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:game_core/game_core.dart';

import 'bridge_builder_ids.dart';
import 'rules/bridge_rules.dart';
import 'rules/bridge_builder_rules.dart';
import 'ui/bridge_art.dart';

/// Bridge builder (package and id `bridge_builder`): plays `numeric` items whose answer is a whole number. A toy robot stops at a gap in
/// a bridge; the child builds any sum that equals the sign's target from number and sign tiles
/// in the gap's slots. [harder] is for Champion. Spec: `docs/SPEC.md`.
MiniGame bridgeBuilderGameFor({bool harder = false}) => MiniGame(
  id: bridgeBuilderId,
  title: bridgeBuilderTitle,
  itemTypes: const {ItemType.numeric},
  accepts: (p) => sumTarget(p.item) != null,
  minPool: 4,
  build: (ctx) => BridgeBuilderScreen(
    session: ctx.session,
    onExit: ctx.onExit,
    onAnswered: ctx.onAnswered,
    onScore: ctx.onScore,
    level: levelForSession(ctx.session, harder: harder),
    study: ctx.mode == MiniGameMode.study,
  ),
);

final MiniGame bridgeBuilderGame = bridgeBuilderGameFor();

/// The name the child sees.
const String bridgeBuilderTitle = 'Bridge builder';

/// How to play, as shown on the start screen (the catalogue and web text say the same).
const String bridgeBuilderHowTo =
    'The toy robot is stuck at a gap. Build a sum from number and sign tiles in the '
    'slots so it makes the number on the sign. Any sum that works lays a plank '
    'and the robot rolls across.';

class BridgeBuilderScreen extends StatefulWidget {
  const BridgeBuilderScreen({
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

  /// Study mode: calm, no timer.
  final bool study;
  final void Function(AnswerResult, QuizSession)? onAnswered;
  final void Function(int)? onScore;
  final Random? random;

  /// Overrides the container's read-aloud (tests); null uses the host's.
  final GameReadAloud? reader;

  @override
  State<BridgeBuilderScreen> createState() => _BridgeBuilderScreenState();
}

enum _Phase { intro, play, results }

class _BridgeBuilderScreenState extends State<BridgeBuilderScreen>
    with TickerProviderStateMixin {
  static const String _g = bridgeBuilderId;

  late final BridgeSettings _cfg = BridgeSettings.forLevel(
    widget.level,
    study: widget.study,
  );
  late final Random _random = widget.random ?? Random();
  late final AnimationController _timer = AnimationController(
    vsync: this,
    duration: Duration(
      seconds: _cfg.secondsPerQuestion > 0 ? _cfg.secondsPerQuestion : 1,
    ),
  )..addStatusListener(_onTimer);
  late final AnimationController _cross = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final AnimationController _wobble = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..addStatusListener(_onWobbleDone);

  _Phase _phase = _Phase.intro;
  SumPuzzle? _puzzle;
  BridgeBoard? _board;
  BridgeStage _stage = bridgeStageFor(0, 1);
  int _round = 0;
  int? _selTile;
  int _cursor = 0;
  bool _keyed = false;
  bool _missed = false;
  bool _paused = false;
  bool _reduce = false;
  AnswerResult? _result;
  bool _timedOut = false;
  String _laidText = '';
  List<String>? _ghost;
  bool _wrongNote = false;
  int _score = 0;
  int _streak = 0;
  int _best = 0;
  int _stageFirst = 0;
  int _stageStarsNow = 0;
  bool _scoreSent = false;
  GameReadAloud? _reader;
  bool _autoRead = false;
  int? _autoReadIndex;

  QuizSession get _s => widget.session;
  int get _target => _puzzle!.target;
  bool get _timed => _cfg.secondsPerQuestion > 0;

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
    _cross.dispose();
    _wobble.dispose();
    _reader?.stop();
    super.dispose();
  }

  // ---- flow ------------------------------------------------------------------

  void _start() {
    setState(() => _phase = _Phase.play);
    _beginRound();
  }

  void _beginRound() {
    if (_s.finished) return _toResults();
    final p = _s.items[_s.index];
    final puzzle = buildSum(p.item, _cfg.sum, _random);
    if (puzzle == null) return _toResults();
    _round = _s.index;
    _puzzle = puzzle;
    _board = BridgeBoard(tiles: puzzle.tiles, slotCount: _cfg.slots);
    _stage = bridgeStageFor(_round, _s.total, gapsPerStage: _cfg.gapsPerStage);
    if (_stage.gap == 0) _stageFirst = 0;
    _stageStarsNow = 0;
    _selTile = null;
    _cursor = 0;
    _missed = false;
    _timedOut = false;
    _wrongNote = false;
    _ghost = null;
    _result = null;
    _cross.value = 0;
    _wobble.value = 0;
    if (_timed) _timer.forward(from: 0);
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
    if (st != AnimationStatus.completed || _result != null || _paused) return;
    _timedOut = true;
    _missed = true;
    _finish(solved: false);
  }

  void _onWobbleDone(AnimationStatus st) {
    if (st == AnimationStatus.completed && mounted) {
      setState(() => _ghost = null);
    }
  }

  /// A slot was filled: a sum that hits the target lays a plank; a full wrong one wobbles.
  void _judge(BridgeVerdict v) {
    if (v == BridgeVerdict.right) {
      _finish(solved: true);
    } else if (v == BridgeVerdict.wrong) {
      _wrong();
    }
  }

  void _wrong() {
    final board = _board!;
    _missed = true;
    _streak = 0;
    _wrongNote = true;
    _selTile = null;
    if (!_reduce) {
      _ghost = board.tokens;
      _wobble.forward(from: 0);
    }
    board.clear();
    setState(() {});
  }

  void _finish({required bool solved}) {
    final board = _board!;
    _timer.stop();
    _reader?.stop();
    if (!solved) {
      // Time ran out: the game lays a working sum so the robot can cross.
      board.clear();
      final used = <int>{};
      for (final tok in _puzzle!.solution) {
        final i = [for (var k = 0; k < board.tiles.length; k++) k]
            .firstWhere((k) => board.tiles[k] == tok && !used.contains(k));
        used.add(i);
        board.place(i);
      }
    }
    final tokens = board.tokens;
    final r = _s.answer(correct: solved && !_missed, timedOut: _timedOut);
    widget.onAnswered?.call(r, _s);
    if (solved) {
      _score += scoreForAnswer(streak: _streak, older: widget.level.older);
      _streak = _missed ? 0 : _streak + 1;
      if (_streak > _best) _best = _streak;
    } else {
      _streak = 0;
    }
    if (solved && !_missed) _stageFirst++;
    _laidText = '${tokens.join(' ')} = $_target';
    _selTile = null;
    _wrongNote = false;
    if (_stage.endsStage) {
      _stageStarsNow = bridgeStageStars(
        firstTry: _stageFirst,
        gaps: _stage.gaps,
      );
    }
    _result = AnswerResult(
      correct: solved,
      firstPass: r.firstPass,
      stars: r.stars,
      coins: r.coins,
      topicCompleted: r.topicCompleted,
      explanation: r.explanation,
    );
    if (_reduce) {
      _cross.value = 1;
    } else {
      _cross.forward(from: 0);
    }
    setState(() {});
  }

  void _next() {
    if (_result == null) return;
    if (_s.finished) {
      _toResults();
    } else {
      _beginRound();
    }
  }

  // ---- placing tiles -----------------------------------------------------------

  bool get _canPlay =>
      _phase == _Phase.play && _result == null && !_paused && _board != null;

  void _placeTile(int tile, {int? slot}) {
    if (!_canPlay) return;
    final board = _board!;
    if (!board.place(tile, slot: slot)) return;
    _selTile = null;
    _wrongNote = false;
    final v = board.autoVerdict(_target);
    if (v != null) {
      _judge(v);
    } else {
      setState(() {});
    }
  }

  void _tapTile(int i) {
    if (!_canPlay) return;
    final board = _board!;
    setState(() {
      _cursor = i;
      final slot = board.slotOf(i);
      if (slot != null) {
        board.removeSlot(slot);
        _selTile = null;
      } else {
        _selTile = _selTile == i ? null : i;
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
      setState(() => board.removeSlot(s));
    }
  }

  void _checkNow() {
    if (!_canPlay) return;
    final v = _board!.check(_target);
    if (v == BridgeVerdict.tooShort) {
      setState(() => _wrongNote = false);
    } else {
      _judge(v);
    }
  }

  void _clear() {
    if (!_canPlay) return;
    setState(() {
      _board!.clear();
      _selTile = null;
    });
  }

  // ---- pause, reading ----------------------------------------------------------

  void _togglePause() {
    if (_phase != _Phase.play || _result != null) return;
    setState(() => _paused = !_paused);
    if (_paused) {
      _timer.stop();
      _reader?.stop();
    } else if (_timed) {
      _timer.forward();
    }
  }

  String get _promptText =>
      'Make $_target with the tiles. You can use some or all of them.';

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
      if (mounted && _result == null) _read();
    });
  }

  // ---- keyboard (docs/SPEC.md, Keyboard) -----------------------------------------

  void _onInput(GameInput i) {
    final a = i.action;
    if (a == GameAction.exit) {
      if (i.repeat) return;
      // Esc pauses a round (the pause screen offers Leave); elsewhere it leaves.
      if (_phase == _Phase.play && _result == null) {
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
        // Space is the same key as Enter here (B-01): it selects, it never pauses. Pause is the
        // button and Esc. On the pause screen Space or Enter resumes.
        final go = a == GameAction.action || a == GameAction.pause;
        if (_paused) {
          if (go) _togglePause();
          return;
        }
        if (_result != null) {
          if (go) _next();
          return;
        }
        final board = _board;
        if (board == null) return;
        final n = board.tiles.length;
        if (moves) {
          setState(() {
            _keyed = true;
            _cursor = (_cursor + (a == GameAction.left ? -1 : 1)) % n;
          });
        } else if (go || a == GameAction.up) {
          setState(() => _keyed = true);
          _cursorEnter(_cursor);
        } else if (a == GameAction.down) {
          if (board.removeLast()) setState(() => _keyed = true);
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
  }

  /// Enter on a tile: places it in the first empty slot, or takes it back when it is placed.
  void _cursorEnter(int tile) {
    final board = _board!;
    final slot = board.slotOf(tile);
    if (slot != null) {
      setState(() => board.removeSlot(slot));
    } else {
      _placeTile(tile);
    }
  }

  static final List<LogicalKeyboardKey> _extraDigits = [
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  /// Backspace (and Delete) takes back the tile placed last; the shared map has no such key.
  KeyEventResult _rawKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || !_canPlay) return KeyEventResult.ignored;
    final hw = HardwareKeyboard.instance;
    if (hw.isControlPressed || hw.isAltPressed || hw.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    final k = event.logicalKey;
    final extra = _extraDigits.indexOf(k);
    if (extra >= 0 && !HardwareKeyboard.instance.isShiftPressed) {
      // Tiles 5 to 9 have no key in the shared map (1 to 4 only): read them here.
      final board = _board!;
      if (_result == null && !_paused && 5 + extra <= board.tiles.length) {
        setState(() {
          _keyed = true;
          _cursor = 4 + extra;
        });
        _cursorEnter(4 + extra);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (k == LogicalKeyboardKey.backspace || k == LogicalKeyboardKey.delete) {
      if (_board!.removeLast()) setState(() => _keyed = true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  List<GameAction> get _hintActions => switch (_phase) {
    _Phase.intro ||
    _Phase.results => const [GameAction.action, GameAction.exit],
    _Phase.play =>
      _result != null
          ? const [GameAction.action, GameAction.exit]
          : [
              GameAction.left,
              GameAction.right,
              GameAction.action,
              GameAction.exit,
            ],
  };

  Map<GameAction, String> get _hintWords => {
    GameAction.left: 'choose tile',
    GameAction.action: _phase == _Phase.play && _result == null
        ? 'place'
        : (_phase == _Phase.play
              ? 'next'
              : (_phase == _Phase.intro ? 'start' : 'leave')),
    GameAction.exit: _phase == _Phase.play ? 'pause' : 'leave',
  };

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
            shortcuts: {
              LogicalKeyboardKey.keyL: widget.onExit,
              LogicalKeyboardKey.keyP: _togglePause,
              if (_canPlay) ...{
                LogicalKeyboardKey.keyG: () {
                  if (_board!.tokens.length >= 3) _checkNow();
                },
                LogicalKeyboardKey.keyR: _clear,
              },
            },
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
                      // read aloud are small overlays on the play area, like Wingy's pause button.
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

  static const double _btn = 44;

  Widget _overlayButtons(BuildContext context) {
    final playing = _phase == _Phase.play;
    final canPause = playing && _result == null;
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
            child: _withKey(
              'L',
              IconButton.filledTonal(
                key: GameIds.mgExit(_g),
                style: style,
                tooltip: 'Leave the game (L)',
                icon: const Icon(Icons.close),
                onPressed: widget.onExit,
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (playing && _reader != null)
                  _withKey(
                    _keyName(GameAction.question),
                    IconButton.filledTonal(
                      key: GameIds.mgSpeak(_g),
                      style: style,
                      tooltip:
                          'Read the target aloud (${_keyName(GameAction.question)})',
                      icon: const Icon(Icons.volume_up),
                      onPressed: _read,
                    ),
                  ),
                if (canPause) ...[
                  const SizedBox(width: 6),
                  _withKey(
                    'Esc / P',
                    IconButton.filledTonal(
                      key: GameIds.mgPause(_g),
                      style: style,
                      tooltip: _paused ? 'Resume (Esc / P)' : 'Pause (Esc / P)',
                      icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                      onPressed: _togglePause,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A small button with its key printed under it (B-09).
  Widget _withKey(String keyName, Widget button) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        Text(
          keyName,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _hints(BuildContext context) {
    final theme = Theme.of(context);
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
            spaceGoesOn: true,
            extra: [
              if (_phase == _Phase.play && _result == null) ...[
                // Tiles 1 to 9 all have a key (1 to 4 in the map, 5 to 9 read here).
                ('1-${min(9, _board?.tiles.length ?? 4)}', 'tile'),
                ('Backspace', 'take back'),
                ('G', 'lay plank'),
                ('R', 'clear'),
                ('P', 'pause'),
              ],
              ('L', 'leave'),
            ],
          ),
        ],
      ),
    );
  }

  /// The player's real key for [a] (a remapped key reads right).
  String _keyName(GameAction a) => keyLabel(
    GameKeysScope.of(context).primaryOf(KeySlot(a, a.shared ? 0 : 1)),
  );

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
                  SizedBox(
                    height: short ? 80 : 150,
                    width: short ? 160 : 300,
                    child: Semantics(
                      image: true,
                      label: 'A toy robot waits at a gap in a bridge',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CustomPaint(
                          painter: BridgeScenePainter(scenery: Scenery.river),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Help the robot cross!',
                    key: BridgeBuilderIds.mgIntroHeading(_g),
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pick tiles to make the number on the sign.',
                    key: BridgeBuilderIds.mgIntroTask(_g),
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bridgeBuilderHowTo,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: short ? 12 : 24),
                  FilledButton(
                    key: GameIds.mgStart(_g),
                    onPressed: _start,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(220, 64),
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Start',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${_keyName(GameAction.action)} / ${_keyName(GameAction.pause)}',
                          key: BridgeBuilderIds.mgStartKeys(_g),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
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
                  SizedBox(
                    height: short ? 80 : 150,
                    width: short ? 160 : 300,
                    child: ExcludeSemantics(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CustomPaint(
                          painter: BridgeScenePainter(
                            scenery: Scenery.sky,
                            laid: 1,
                            robotX: 0.8,
                            mood: RobotMood.happy,
                            flag: true,
                            stars: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    container: true,
                    label:
                        'Round finished. ${r.correct} of ${r.answered} right. Score $_score.',
                    child: Text(
                      '${r.correct} of ${r.answered} right',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Score $_score', key: GameIds.mgScore(_g)),
                  if (widget.level.older && _best > 1)
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
                    child: KeyedText(
                      'Done',
                      GameAction.action,
                      alsoSpace: true,
                    ),
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

  Widget _play(BuildContext context) {
    final puzzle = _puzzle, board = _board;
    if (puzzle == null || board == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final answered = _result != null;
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        // Height-aware (owner, 2026-11-22): the stage fits the window. The HUD strip, the scene and
        // the tile tray share the height; the tray scrolls inside itself only when it must.
        final strip = scale > 1.2 ? 56.0 : 44.0;
        final landscape = h < 460 && w > h * 1.3;
        final tileSize = h < 400
            ? 48.0
            : (h < 560 ? 52.0 : (widget.level.older ? 60.0 : 68.0));
        Widget tray() => SingleChildScrollView(
          key: BridgeBuilderIds.mgTray(_g),
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (answered) ..._feedback(theme),
              if (answered) const SizedBox(height: 8),
              if (!answered) _controls(context, board),
              if (!answered) const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < puzzle.tiles.length; i++)
                    _tile(context, board, i, tileSize),
                ],
              ),
              if (!answered) const SizedBox(height: 4),
              if (!answered) _hintLine(theme),
            ],
          ),
        );
        final Widget body;
        if (landscape) {
          body = Row(
            children: [
              Expanded(
                flex: 11,
                child: Center(child: _scene(context, puzzle, board)),
              ),
              SizedBox(
                width: min(340.0, w * 0.42),
                child: Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: h - strip),
                    child: tray(),
                  ),
                ),
              ),
            ],
          );
        } else {
          body = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Center(child: _scene(context, puzzle, board)),
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: (h - strip) * 0.6),
                child: tray(),
              ),
            ],
          );
        }
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                SizedBox(height: strip, child: _hud(theme, strip)),
                Expanded(child: body),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Stage, score and timer inside the play area, between the exit and pause buttons.
  Widget _hud(ThemeData theme, double strip) {
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
                'Bridge ${_round + 1} of ${_s.total} · Stage ${_stage.stage + 1}',
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
    final limit = _cfg.secondsPerQuestion;
    return AnimatedBuilder(
      animation: _timer,
      builder: (_, _) {
        final left = (limit * (1 - _timer.value)).ceil();
        return Semantics(
          label: 'Time left ${clock(left)}',
          excludeSemantics: true,
          child: Text(
            clock(left),
            key: GameIds.mgTimer(_g),
            style: theme.textTheme.labelLarge,
          ),
        );
      },
    );
  }

  Widget _hintLine(ThemeData theme) {
    final text = _wrongNote
        ? 'Not yet. The planks fell back. Try again!'
        : (_selTile != null
              ? 'Now tap a slot to put the tile in.'
              : (_round == 0 && _board!.isEmpty
                    ? 'Tap a tile, then a slot (or press a tile number, then Enter).'
                    : 'Drag a tile into a slot, or tap a tile and then a slot.'));
    return Semantics(
      liveRegion: true,
      child: Text(
        text,
        key: GameIds.mgPrompt(_g),
        style: theme.textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
    );
  }

  // The scene: backdrop, sign, slots over the gap, the robot.
  Widget _scene(BuildContext context, SumPuzzle puzzle, BridgeBoard board) {
    return LayoutBuilder(
      builder: (context, box) {
        // Fit the width and the height given; keep the 0.52 aspect, at most 320 tall.
        final maxH = box.maxHeight.isFinite ? box.maxHeight : 320.0;
        final w = min(box.maxWidth, min(maxH, 320.0) / 0.52);
        final h = w * 0.52;
        final size = Size(w, h);
        final deckY = h * BridgeGeometry.deck;
        final bank = w * BridgeGeometry.bank;
        final gapW = w - 2 * bank;
        const gapSp = 4.0;
        final n = board.slotCount;
        final ss = min(min(60.0, h * 0.34), (gapW - gapSp * (n - 1)) / n);
        final rowW = ss * n + gapSp * (n - 1);
        final rowLeft = bank + (gapW - rowW) / 2;
        final rowTop = deckY - h * 0.01;
        final done = _result != null;
        final stars = done && _stage.endsStage ? _stageStarsNow : 0;
        final endX = _stage.endsStage ? 0.8 : 0.94;
        return SizedBox(
          key: BridgeBuilderIds.mgScene(_g),
          width: w,
          height: h,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Semantics(
                    image: true,
                    label: done
                        ? 'The toy robot rolls across the new plank'
                        : 'The toy robot waits at a gap in the bridge',
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_cross, _wobble]),
                      builder: (_, _) {
                        final cv = _cross.value;
                        final laid = (cv / 0.4).clamp(0.0, 1.0);
                        final move = ((cv - 0.35) / 0.65).clamp(0.0, 1.0);
                        final wob = _wobble.isAnimating
                            ? sin(_wobble.value * pi * 6) *
                                  0.1 *
                                  (1 - _wobble.value)
                            : 0.0;
                        return CustomPaint(
                          size: size,
                          painter: BridgeScenePainter(
                            scenery: _stage.scenery,
                            laid: laid,
                            robotX:
                                0.06 +
                                (endX - 0.06) *
                                    Curves.easeInOut.transform(move),
                            mood: done
                                ? RobotMood.happy
                                : (_wrongNote
                                      ? RobotMood.wondering
                                      : RobotMood.normal),
                            flag: _stage.endsStage,
                            stars: stars,
                            time: cv * 3 + _wobble.value,
                            tilt: wob,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (_stage.endsStage)
                  Positioned(
                    right: 0,
                    top: 0,
                    width: bank * 1.2,
                    height: deckY,
                    child: Semantics(
                      key: BridgeBuilderIds.mgFlag(_g),
                      label: done
                          ? 'Flag reached: $stars of 3 stars'
                          : 'A flag waits at the end of this stage',
                      child: const SizedBox.expand(),
                    ),
                  ),
                Positioned(
                  top: 4,
                  left: 0,
                  right: 0,
                  height: deckY - 6,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: _sign(context, w),
                  ),
                ),
                Positioned(
                  left: rowLeft,
                  top: rowTop,
                  width: rowW,
                  child: Row(
                    key: done ? BridgeBuilderIds.mgPlank(_g) : null,
                    children: [
                      for (var i = 0; i < n; i++) ...[
                        if (i > 0) const SizedBox(width: gapSp),
                        _slot(context, board, i, ss),
                      ],
                    ],
                  ),
                ),
                if (_ghost != null)
                  Positioned(
                    left: rowLeft,
                    top: rowTop,
                    width: rowW,
                    child: _ghostRow(ss, gapSp),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sign(BuildContext context, double sceneW) {
    final theme = Theme.of(context);
    final w = min(sceneW * 0.32, 150.0);
    return Semantics(
      key: BridgeBuilderIds.mgSign(_g),
      container: true,
      label: 'Sign: make $_target',
      child: ExcludeSemantics(
        child: SizedBox(
          width: w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: w * 0.6,
                height: 12,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(width: 3, child: ColoredBox(color: bridgeInk)),
                    SizedBox(width: 3, child: ColoredBox(color: bridgeInk)),
                  ],
                ),
              ),
              Container(
                width: w,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D6),
                  border: Border.all(color: bridgeInk, width: 3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'make',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: bridgeInk,
                      ),
                    ),
                    Text(
                      '$_target',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: bridgeInk,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _plankBox(
    double size, {
    required Widget child,
    Color? fill,
    bool glow = false,
  }) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill ?? const Color(0xFFC98B4A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bridgeInk, width: glow ? 4 : 3),
      ),
      child: child,
    );
  }

  Widget _slot(BuildContext context, BridgeBoard board, int i, double size) {
    final theme = Theme.of(context);
    final tile = board.tileAt(i);
    final n = board.slotCount;
    final answered = _result != null;
    final next = board.firstEmpty == i && !answered;
    final label = tile == null
        ? 'Slot ${i + 1} of $n, empty'
        : 'Slot ${i + 1} of $n, ${spokenTile(board.tiles[tile])}';
    // After a result every slot is a laid plank (B-02): an unused slot stays on the bridge as a
    // blank green plank, not a faded hole with its number.
    final Widget face = tile == null && answered
        ? _plankBox(
            size,
            fill: const Color(0xFF7BDC8A),
            child: const SizedBox(),
          )
        : tile == null
        ? _plankBox(
            size,
            fill: const Color(0x66FFFFFF),
            glow: next,
            child: Text(
              '${i + 1}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: bridgeInk.withValues(alpha: 0.5),
              ),
            ),
          )
        : _plankBox(
            size,
            fill: answered ? const Color(0xFF7BDC8A) : const Color(0xFFD99A57),
            child: Text(
              board.tiles[tile],
              style: theme.textTheme.titleLarge?.copyWith(
                color: bridgeInk,
                fontWeight: FontWeight.w900,
              ),
            ),
          );
    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => _canPlay,
      onAcceptWithDetails: (d) => _placeTile(d.data, slot: i),
      builder: (context, candidates, _) => Semantics(
        button: true,
        enabled: !answered,
        excludeSemantics: true,
        label: label,
        onTap: () => _tapSlot(i),
        child: InkWell(
          key: BridgeBuilderIds.mgSlot(_g, i),
          borderRadius: BorderRadius.circular(10),
          onTap: answered ? null : () => _tapSlot(i),
          child: AnimatedScale(
            scale: candidates.isNotEmpty ? 1.1 : 1,
            duration: const Duration(milliseconds: 120),
            child: face,
          ),
        ),
      ),
    );
  }

  /// The planks of a wrong sum, wobbling and falling away.
  Widget _ghostRow(double ss, double sp) {
    final tokens = _ghost!;
    return IgnorePointer(
      key: BridgeBuilderIds.mgGhost(_g),
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _wobble,
          builder: (_, _) {
            final v = _wobble.value;
            return Opacity(
              opacity: (1 - v).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(sin(v * pi * 8) * 4, v * v * 90),
                child: Transform.rotate(
                  angle: sin(v * pi * 6) * 0.08 * (1 + v),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < tokens.length; i++) ...[
                        if (i > 0) SizedBox(width: sp),
                        _plankBox(
                          ss,
                          fill: const Color(0xFFE58F8F),
                          child: Text(
                            tokens[i],
                            style: const TextStyle(
                              color: bridgeInk,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _controls(BuildContext context, BridgeBoard board) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: BridgeBuilderIds.mgClear(_g),
            onPressed: board.isEmpty ? null : _clear,
            child: Text(withKey('Clear', 'R')),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            key: BridgeBuilderIds.mgCheck(_g),
            onPressed: board.tokens.length < 3 ? null : _checkNow,
            child: Text(withKey('Lay plank', 'G')),
          ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, BridgeBoard board, int i, double size) {
    final theme = Theme.of(context);
    final t = board.tiles[i];
    final placed = board.isPlaced(i);
    final selected = _selTile == i;
    final cursor = _keyed && _cursor == i;
    final op = isOperator(t);
    final answered = _result != null;
    Widget face({bool lifted = false}) => Container(
      constraints: BoxConstraints(minWidth: size, minHeight: size),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      // No `alignment` on the Container: it would stretch every tile to the full row width.
      decoration: BoxDecoration(
        color: op ? const Color(0xFFFFB02E) : const Color(0xFF5AA9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cursor ? theme.colorScheme.tertiary : bridgeInk,
          width: cursor ? 5 : 3,
        ),
        boxShadow: [
          BoxShadow(
            color: bridgeInk.withValues(alpha: 0.5),
            offset: Offset(0, lifted ? 8 : 4),
          ),
        ],
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          t,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: op ? bridgeInk : Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
    final spoken = spokenTile(t);
    final slot = board.slotOf(i);
    final label = placed
        ? '$spoken tile, in slot ${slot! + 1}'
        : (selected ? '$spoken tile, selected' : '$spoken tile');
    return Semantics(
      button: true,
      enabled: !answered,
      excludeSemantics: true,
      label: label,
      onTap: () => _tapTile(i),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: AnimatedScale(
          scale: selected ? 1.12 : 1,
          duration: const Duration(milliseconds: 120),
          child: Opacity(
            opacity: placed ? 0.35 : 1,
            child: Draggable<int>(
              data: i,
              maxSimultaneousDrags: _canPlay && !placed ? 1 : 0,
              feedback: Material(
                type: MaterialType.transparency,
                child: face(lifted: true),
              ),
              childWhenDragging: Opacity(opacity: 0.3, child: face()),
              child: InkWell(
                key: BridgeBuilderIds.mgTile(_g, i),
                borderRadius: BorderRadius.circular(14),
                onTap: answered ? null : () => _tapTile(i),
                child: face(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _feedback(ThemeData theme) {
    final res = _result!;
    final last = _s.finished;
    final ends = _stage.endsStage;
    return [
      Semantics(
        liveRegion: true,
        container: true,
        child: Column(
          key: GameIds.mgFeedback(_g),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _timedOut
                        ? "Time's up. A working sum was $_laidText"
                        : 'Plank laid! $_laidText',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (res.explanation.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(res.explanation, style: theme.textTheme.bodyMedium),
            ],
            if (ends) ...[
              const SizedBox(height: 4),
              Text(
                'Stage complete! $_stageStarsNow of 3 stars at the flag.',
                key: BridgeBuilderIds.mgStageStars(_g),
                style: theme.textTheme.titleMedium,
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 8),
      FilledButton(
        key: GameIds.mgNext(_g),
        onPressed: _next,
        child: KeyedText(
          last ? 'See results' : (ends ? 'Next stage' : 'Next bridge'),
          GameAction.action,
          alsoSpace: true,
        ),
      ),
    ];
  }
}
