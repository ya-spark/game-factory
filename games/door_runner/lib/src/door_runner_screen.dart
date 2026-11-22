import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:game_core/kit/keys/keys.dart';
import 'package:game_core/engine/engine.dart';
import 'package:game_core/host/game_host.dart';
import 'package:game_core/kit/layout/game_frame.dart';
import 'package:game_core/kit/layout/window_class.dart';

import 'door_runner_ids.dart';
import 'door_runner_race_screen.dart';
import 'rules/door_runner_rules.dart';
import 'rules/door_runner_state.dart';
import 'ui/door_runner_extras.dart';
import 'ui/door_runner_field.dart';
import 'ui/door_runner_frame.dart';
import 'ui/door_runner_fx.dart';
import 'ui/door_runner_hud.dart';
import 'ui/door_runner_keyboard.dart';
import 'ui/door_runner_question.dart';
import 'ui/door_runner_style.dart';
import 'ui/door_runner_view.dart';

/// Door runner: free, Game mode only, plays short multiple-choice items. The runner stands in
/// a lane and the doors come down; steer, zap or slow down (see `docs/SPEC.md`).
/// [harder] is for Champion (older level, tighter settings).
MiniGame doorRunnerGameFor({bool harder = false}) => MiniGame(
  id: doorRunnerId,
  title: 'Door runner',
  itemTypes: const {ItemType.mcq},
  sizes: SizeAccept.shortOnly,
  minPool: 4,
  modes: const {MiniGameMode.game},
  build: (ctx) => DoorRunnerScreen(
    session: ctx.session,
    onExit: ctx.onExit,
    onAnswered: ctx.onAnswered,
    onScore: ctx.onScore,
    level: levelForSession(ctx.session, harder: harder),
    // Race: two players on one keyboard (docs/SPEC.md); shown on windows 600 dp wide and up.
    offerTwoPlayers: true,
  ),
);

final MiniGame doorRunnerGame = doorRunnerGameFor();

class DoorRunnerScreen extends StatefulWidget {
  const DoorRunnerScreen({
    super.key,
    required this.session,
    required this.onExit,
    required this.level,
    this.onAnswered,
    this.onScore,
    this.random,
    this.reader,
    this.autoRead,
    this.offerTwoPlayers = false,
  });
  final QuizSession session;

  /// Adds the "2 players" race button to the start screen (windows 600 dp and wider).
  final bool offerTwoPlayers;
  final VoidCallback onExit;
  final MiniGameLevel level;
  final void Function(AnswerResult, QuizSession)? onAnswered;
  final void Function(int)? onScore;
  final Random? random;

  /// Overrides the container's read-aloud (tests); null uses the host's.
  final GameReadAloud? reader;

  /// Overrides the container's auto-read setting (tests); null uses the host's.
  final bool? autoRead;

  @override
  State<DoorRunnerScreen> createState() => _DoorRunnerScreenState();
}

enum _Phase { intro, play, results }

class _DoorRunnerScreenState extends State<DoorRunnerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const double _countIn = 3;

  late final DoorRunSettings _cfg = DoorRunSettings.forLevel(widget.level);
  late final Random _random = widget.random ?? Random();
  late final Ticker _ticker = createTicker(_tick);
  final DoorRunnerFx _fx = DoorRunnerFx();
  DoorRunnerState? _st;
  _Phase _phase = _Phase.intro;
  Duration _last = Duration.zero;
  String _question = '';
  AnswerResult? _result;
  double? _advanceIn;
  double _resumeIn = 0;
  bool _dialogOpen = false;
  bool _reduce = false;
  bool _scoreSent = false;
  bool _race = false;
  int _best = 0;
  GameReadAloud? _reader;
  bool _autoRead = false;
  int? _autoReadIndex;

  QuizSession get _s => widget.session;
  bool get _older => widget.level.older;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final host = GameHostScope.of(context);
    _reader = widget.reader ?? host.readAloud(context);
    _autoRead = widget.autoRead ?? host.autoRead(context);
    _reduce =
        host.reduceMotion(context) || MediaQuery.disableAnimationsOf(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _fx.dispose();
    _reader?.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  // ---- flow ------------------------------------------------------------------

  void _start() {
    _st = DoorRunnerState(
      settings: _cfg,
      level: widget.level,
      doorsWait: _reduce,
    );
    setState(() => _phase = _Phase.play);
    _beginQuestion();
    _last = Duration.zero;
    _ticker.start();
  }

  void _beginQuestion() {
    if (_s.finished) return _toResults();
    final p = _s.items[_s.index];
    final doors = layoutDoors(p.item, _cfg.doors, _random);
    if (doors == null) return _toResults();
    _question = p.item.json['prompt'] as String;
    _st!.startQuestion(doors);
    _maybeAutoRead();
  }

  void _toResults() {
    _ticker.stop();
    if (!_scoreSent) {
      _scoreSent = true;
      widget.onScore?.call(_st?.run.score ?? 0);
    }
    _best = _st?.run.bestStreak ?? 0;
    if (mounted) setState(() => _phase = _Phase.results);
  }

  void _tick(Duration d) {
    final dt = _last == Duration.zero
        ? 0.0
        : min(0.1, (d - _last).inMicroseconds / 1e6);
    _last = d;
    final st = _st;
    if (st == null || _phase != _Phase.play) return;
    if (_resumeIn > 0) {
      _resumeIn -= dt;
      if (_resumeIn <= 0) {
        _resumeIn = 0;
        st.resume();
      }
    } else if (!st.paused) {
      final p = st.tick(dt);
      if (p != null) {
        _handlePick(p);
      } else if (_advanceIn != null) {
        _advanceIn = _advanceIn! - dt;
        if (_advanceIn! <= 0) _next();
      }
    }
    if (mounted) setState(() {});
  }

  void _handlePick(DoorPick p) {
    switch (p.outcome) {
      case DoorOutcome.retry:
        if (!_reduce) _fx.shakeScreen();
      case DoorOutcome.right:
        _reader?.stop();
        final r = _s.answer(correct: p.clean, timedOut: false);
        widget.onAnswered?.call(r, _s);
        _result = r;
        if (!_reduce) {
          _fx.floatText('+${p.gained}', p.index, DrColors.gold);
          _fx.burst(p.index, DrColors.mint);
        }
        _advanceIn = 0.9;
      case DoorOutcome.wrong:
        _reader?.stop();
        final r = _s.answer(correct: false, timedOut: false);
        widget.onAnswered?.call(r, _s);
        _result = r;
        if (!_reduce) {
          _fx.shakeScreen();
          _fx.burst(p.index, DrColors.pink);
        }
        _advanceIn = null;
    }
    if (mounted) setState(() {});
  }

  bool get _nextShowing => _result != null && !_result!.correct;

  void _next() {
    _result = null;
    _advanceIn = null;
    if (_s.finished || (_st?.over ?? false)) return _toResults();
    _beginQuestion();
    if (mounted) setState(() {});
  }

  // ---- commands --------------------------------------------------------------

  void _zap([int? i]) {
    final st = _st;
    if (st == null || _phase != _Phase.play) return;
    final p = st.zap(i);
    if (p != null) _handlePick(p);
    setState(() {});
  }

  void _move(int dir) {
    final st = _st;
    if (st == null) return;
    setState(() => dir < 0 ? st.moveLeft() : st.moveRight());
  }

  void _slow(bool held) => setState(() => _st?.setSlow(held));

  void _pause() {
    final st = _st;
    if (st == null || _phase != _Phase.play) return;
    _resumeIn = 0;
    setState(st.pause);
  }

  void _resume({bool countIn = true}) {
    final st = _st;
    if (st == null) return;
    if (countIn && _older && !_reduce) {
      setState(() => _resumeIn = _countIn);
    } else {
      setState(st.resume);
    }
  }

  void _togglePause() {
    final st = _st;
    if (st == null || _phase != _Phase.play || _dialogOpen) return;
    if (st.paused) {
      if (_resumeIn > 0) return;
      _resume();
    } else {
      _pause();
    }
  }

  Future<void> _openQuestion() async {
    final st = _st;
    if (st == null || _phase != _Phase.play || _dialogOpen) return;
    final wasPaused = st.paused;
    _resumeIn = 0;
    setState(() {
      st.pause();
      _dialogOpen = true;
    });
    final pick = await showDoorRunnerQuestionDialog(
      context,
      question: _question,
      answers: [for (final d in st.doors) d.label],
      onSpeak: _reader == null ? null : _read,
    );
    if (!mounted) return;
    setState(() => _dialogOpen = false);
    if (pick != null) {
      setState(st.resume);
      _zap(pick);
    } else if (!wasPaused) {
      _resume();
    }
  }

  Future<void> _read() => _reader == null
      ? Future.value()
      : _reader!.read(_question, audioRef: _currentAudio);

  String? get _currentAudio {
    final i = _s.index;
    return i < _s.items.length ? _s.items[i].item.audio : null;
  }

  void _maybeAutoRead() {
    if (!_autoRead || _reader == null || _autoReadIndex == _s.index) return;
    _autoReadIndex = _s.index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _result == null) _read();
    });
  }

  // ---- build -----------------------------------------------------------------

  DoorRunnerView _view() {
    final st = _st!;
    return DoorRunnerView(
      question: _question,
      doors: [
        for (var i = 0; i < st.doors.length; i++)
          DoorView(
            st.doors[i].label,
            mark: st.phase == DoorPhase.answered && st.doors[i].correct
                ? DoorMark.right
                : (st.disabled.contains(i) || st.missedIndex == i)
                ? DoorMark.wrong
                : DoorMark.idle,
          ),
      ],
      lane: st.lane,
      approach: _reduce ? 1 : st.approach,
      hearts: st.hearts,
      maxHearts: _cfg.hearts ?? 3,
      score: st.run.score,
      streak: _older ? st.run.streak : null,
      paused: st.paused,
      answered: st.phase == DoorPhase.answered,
      world: (_s.index ~/ 4) % DrColors.worlds.length,
      speed: st.slow ? DoorRunSettings.slowFactor : 1,
    );
  }

  /// The phone banner of the start and results screens. On a wider window the frame shows the
  /// container's strip or rail instead, so the banner steps aside when there is one.
  Widget _banner(GameBannerSlot slot) {
    final host = GameHostScope.of(context);
    final wide = WindowClass.ofContext(context) != WindowClass.compact;
    if (wide && host.adUnit(context, GameAdFormat.leaderboard) != null) {
      return const SizedBox.shrink();
    }
    return KeyedSubtree(
      key: DoorRunnerIds.banner,
      child: host.banner(context, slot),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_race) {
      return DoorRunnerRaceScreen(
        items: _s.items,
        level: widget.level,
        onExit: widget.onExit,
        random: _random,
      );
    }
    return Scaffold(
      key: DoorRunnerIds.screen,
      backgroundColor: DrColors.ink,
      body: switch (_phase) {
        _Phase.intro => _menuKeys(_intro(context)),
        _Phase.play => _play(context),
        _Phase.results => _menuKeys(_results(context)),
      },
    );
  }

  /// Keys of the start and results screens (B-16, B-09): Enter or Space starts (or is Done), 2 races, Esc or L leaves.
  Widget _menuKeys(Widget child) => GameKeyboard(
    onInput: (i) {
      if (i.repeat) return;
      final goOn =
          i.action == GameAction.action || i.action == GameAction.pause;
      if (i.action == GameAction.exit) {
        widget.onExit();
      } else if (_phase == _Phase.intro) {
        if (goOn) {
          _start();
        } else if (i.action == GameAction.pick2 && _twoShown(context)) {
          setState(() => _race = true);
        }
      } else if (goOn) {
        widget.onExit();
      }
    },
    shortcuts: {LogicalKeyboardKey.keyL: widget.onExit},
    child: child,
  );

  bool _twoShown(BuildContext context) =>
      widget.offerTwoPlayers &&
      WindowClass.ofContext(context) != WindowClass.compact;

  Widget _backdrop({required Widget child}) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: DrColors.world(0),
        stops: const [0, 0.5, 1],
      ),
    ),
    child: SafeArea(child: child),
  );

  Widget _panel({
    required Key key,
    required List<Widget> children,
    required Widget action,
    required GameBannerSlot placement,
  }) {
    return _backdrop(
      // Centered; a strip or rail from the container sits beside it, not over it.
      child: GameFrame(
        maxWidth: 640,
        phoneBanner: null,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: KeyedSubtree(
                  key: DoorRunnerIds.exit,
                  child: DrRoundButton(
                    icon: Icons.close,
                    tooltip: 'Leave Door runner',
                    onPressed: widget.onExit,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  key: key,
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: children,
                    ),
                  ),
                ),
              ),
            ),
            // Pinned under the scrolling text so it is always on screen, even at large text.
            Padding(padding: const EdgeInsets.only(bottom: 16), child: action),
            _banner(placement),
          ],
        ),
      ),
    );
  }

  static const _title = TextStyle(
    color: Colors.white,
    fontSize: 36,
    letterSpacing: 4,
    fontWeight: FontWeight.w800,
    shadows: [Shadow(color: DrColors.lilac, blurRadius: 22)],
  );

  Widget _intro(BuildContext context) {
    return _panel(
      key: DoorRunnerIds.intro,
      placement: GameBannerSlot.preGame,
      children: [
        const Text('DOOR RUNNER', style: _title, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Text(
          _older
              ? 'Steer the runner to the door with the right answer, or zap it with Up. '
                    'Answer quickly to build a streak.'
              : 'Run to the door with the right answer. If it is not that one, try another door.',
          style: const TextStyle(color: Colors.white, fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ],
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 300,
            child: DrButton(
              key: DoorRunnerIds.start,
              colors: const [Color(0xFFFFB02E), Color(0xFFFF6B3D)],
              onPressed: _start,
              child: Text(
                keyedLabel(
                  context,
                  'Start',
                  GameAction.action,
                  alsoSpace: true,
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (widget.offerTwoPlayers &&
              WindowClass.ofContext(context) != WindowClass.compact) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: 300,
              child: DrButton(
                key: DoorRunnerIds.modeTwo,
                height: 48,
                onPressed: () => setState(() => _race = true),
                child: const Text(
                  '2 players: race (2)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _results(BuildContext context) {
    final r = _s.report;
    final score = _st?.run.score ?? 0;
    final ended = _st?.over ?? false;
    const body = TextStyle(color: Colors.white, fontSize: 18);
    return _panel(
      key: DoorRunnerIds.results,
      placement: GameBannerSlot.postGame,
      children: [
        Semantics(
          container: true,
          label:
              'Round finished. ${r.correct} of ${r.answered} right. Score $score.',
          child: Text(
            ended ? 'Good run!' : 'Round finished',
            style: _title,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${r.correct} of ${r.answered} right',
          style: body.copyWith(fontSize: 24, fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text('Score $score', key: DoorRunnerIds.score, style: body),
        if (_older && _best > 1)
          Text('Best streak $_best in a row', style: body),
        if (_s.rewardsConfig.starsEnabled) ...[
          const SizedBox(height: 8),
          Text(
            '${r.stars} stars earned',
            key: DoorRunnerIds.stars,
            style: body.copyWith(color: DrColors.gold),
          ),
        ],
      ],
      action: SizedBox(
        width: 300,
        child: DrButton(
          key: DoorRunnerIds.done,
          onPressed: widget.onExit,
          child: Text(
            keyedLabel(context, 'Done', GameAction.action, alsoSpace: true),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _play(BuildContext context) {
    final st = _st!;
    final view = _view();
    final showPause = st.paused && _resumeIn <= 0 && !_dialogOpen;
    final overlay = Stack(
      children: [
        if (showPause)
          Positioned.fill(
            child: DoorRunnerPauseOverlay(
              onResume: _togglePause,
              onQuit: widget.onExit,
            ),
          ),
        if (_resumeIn > 0 && !_dialogOpen)
          Positioned.fill(child: DoorRunnerCountdown(number: _resumeIn.ceil())),
        if (_result != null && !_result!.correct)
          Positioned(left: 12, right: 12, bottom: 8, child: _feedback(st)),
      ],
    );
    return DoorRunnerKeyboard(
      onLeft: () => _move(-1),
      onRight: () => _move(1),
      onZap: _zap,
      onSlow: _slow,
      // Space (and Enter) is Next while the wrong-answer feedback shows; Space pauses otherwise (U2).
      onPause: () => _nextShowing ? _next() : _togglePause(),
      onQuestion: () => _nextShowing ? _next() : _openQuestion(),
      onDoor: (i) => _zap(i),
      onLeave: widget.onExit,
      child: DoorRunnerFrame(
        world: view.world,
        hud: DoorRunnerHud(
          view: view,
          onExit: widget.onExit,
          onPause: _togglePause,
        ),
        question: DoorRunnerQuestionChip(
          question: _question,
          onOpen: _openQuestion,
        ),
        field: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v.abs() > 120) _move(v < 0 ? -1 : 1);
          },
          child: DoorRunnerField(
            view: view,
            fx: _fx,
            reduceMotion: _reduce,
            onZap: (i) => _zap(i),
          ),
        ),
        slowZone: DoorRunnerSlowZone(onSlow: _slow),
        overlay: overlay,
      ),
    );
  }

  Widget _feedback(DoorRunnerState st) {
    final r = _result!;
    final right = st.doors[st.correctIndex].label;
    final last = _s.finished || st.over;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: DoorRunnerIds.feedback,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xE61B1446),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: DrColors.lilac, width: 1.5),
          boxShadow: drGlow(DrColors.lilac, alpha: 0.4, blur: 20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Not quite. The answer was $right.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (r.explanation.isNotEmpty)
              Text(
                r.explanation,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            const SizedBox(height: 8),
            DrButton(
              key: DoorRunnerIds.next,
              height: 48,
              onPressed: _next,
              child: Text(
                keyedLabel(
                  context,
                  last ? 'See results' : 'Next',
                  GameAction.action,
                  alsoSpace: true,
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
