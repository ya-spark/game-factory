import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:game_core/game_core.dart';

import 'door_runner_ids.dart';
import 'rules/door_runner_race.dart';
import 'rules/door_runner_rules.dart';
import 'rules/door_runner_state.dart';
import 'ui/door_runner_extras.dart';
import 'ui/door_runner_field.dart';
import 'ui/door_runner_frame.dart';
import 'ui/door_runner_question.dart';
import 'ui/door_runner_style.dart';
import 'ui/door_runner_view.dart';

/// Door runner, race (docs/SPEC.md, "Two players"): both players run the same doors and race to
/// the right answer on their own keys. First to the target points wins. Nothing is recorded: no
/// stars, coins or progress, and the quiz session is never touched.
class DoorRunnerRaceScreen extends StatefulWidget {
  const DoorRunnerRaceScreen({
    super.key,
    required this.items,
    required this.level,
    required this.onExit,
    this.random,
    this.betweenQuestions = const Duration(milliseconds: 1400),
  });

  /// The questions (the session's items, read only); only `mcq` items can be played.
  final List<PoolItem> items;
  final MiniGameLevel level;
  final VoidCallback onExit;
  final Random? random;

  /// How long the answer stays on screen before the next question.
  final Duration betweenQuestions;

  @override
  State<DoorRunnerRaceScreen> createState() => _DoorRunnerRaceScreenState();
}

enum _Phase { intro, play, over }

class _DoorRunnerRaceScreenState extends State<DoorRunnerRaceScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final DoorRunSettings _cfg = DoorRunSettings.forLevel(widget.level);
  late final Random _random = widget.random ?? Random();
  late final Ticker _ticker = createTicker(_tick);
  late DoorRaceState _st;
  _Phase _phase = _Phase.intro;
  Duration _last = Duration.zero;
  int _index = -1;
  String _question = '';
  double? _betweenLeft;
  String _message = '';
  bool _reduce = false;
  bool _paused = false;
  int _finalWinner = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _st = _newState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final host = GameHostScope.of(context);
    _reduce =
        host.reduceMotion(context) || MediaQuery.disableAnimationsOf(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  DoorRaceState _newState() =>
      DoorRaceState(settings: _cfg, level: widget.level, doorsWait: _reduce);

  // ---- flow ----

  void _start() {
    _st = _newState();
    _index = -1;
    _phase = _Phase.play;
    _paused = false;
    _last = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
    _nextQuestion();
  }

  /// Starts the next question that can be played; the race ends when there is none.
  void _nextQuestion() {
    while (true) {
      _index++;
      if (_index >= widget.items.length) {
        _finish();
        return;
      }
      final item = widget.items[_index].item;
      final doors = layoutDoors(item, _cfg.doors, _random);
      if (doors != null) {
        _question = item.json['prompt'] as String;
        _st.startQuestion(doors);
        break;
      }
    }
    _betweenLeft = null;
    _message = '';
    if (mounted) setState(() {});
  }

  void _finish() {
    _ticker.stop();
    setState(() {
      _finalWinner = _st.decideWhenOut();
      _phase = _Phase.over;
    });
  }

  void _tick(Duration d) {
    final dt = _last == Duration.zero
        ? 0.0
        : min(0.1, (d - _last).inMicroseconds / 1e6);
    _last = d;
    if (_paused || _phase != _Phase.play) return;
    if (_st.phase == DoorPhase.approaching) {
      final picks = _st.tick(dt);
      if (picks.isNotEmpty || _st.questionOver) _questionEnded();
      if (mounted) setState(() {});
    } else if (_betweenLeft != null) {
      _betweenLeft = _betweenLeft! - dt;
      if (_betweenLeft! <= 0) _afterQuestion();
    }
  }

  void _questionEnded() {
    final s = _st.scorers;
    final right = _st.doors[_st.correctIndex].label;
    _message = s.length == 2
        ? 'A photo finish! Both players score.'
        : s.length == 1
        ? 'Player ${s.first} got it!'
        : 'No one got it. The answer was $right.';
    _betweenLeft = widget.betweenQuestions.inMicroseconds / 1e6;
  }

  void _afterQuestion() {
    if (_st.isOver) {
      _finish();
    } else {
      _nextQuestion();
    }
  }

  void _pause() {
    if (_phase != _Phase.play || _paused) return;
    setState(() {
      _paused = true;
      _st.pause();
    });
  }

  void _togglePause() {
    if (_phase != _Phase.play) return;
    if (_paused) {
      setState(() {
        _paused = false;
        _st.resume();
        _last = Duration.zero;
      });
    } else {
      _pause();
    }
  }

  void _pick(int player, [int? door]) {
    if (_phase != _Phase.play || _paused) return;
    final p = _st.zap(player, door);
    if (p == null) return;
    setState(() {
      if (_st.questionOver) {
        _questionEnded();
      } else {
        _message = 'Player ${p.player} is out of this question.';
      }
    });
  }

  // ---- keys (docs/KEYBOARD.md): each player has their own side ----

  void _onInput(GameInput i) {
    if (i.action == GameAction.exit) {
      if (i.repeat) return;
      _phase == _Phase.play ? _togglePause() : widget.onExit();
      return;
    }
    // Enter or Space (the pause key) starts, plays again and goes on after a question; in play
    // Space pauses, never while Next is showing (U2).
    final goOn = i.action == GameAction.action || i.action == GameAction.pause;
    final nextShowing = _phase == _Phase.play && _st.questionOver && !_paused;
    if (i.action == GameAction.pause && _phase == _Phase.play && !nextShowing) {
      if (!i.repeat) _togglePause();
      return;
    }
    if (_paused || i.repeat) return;
    switch (_phase) {
      case _Phase.intro:
        if (goOn) _start();
      case _Phase.over:
        if (goOn) _start();
      case _Phase.play:
        final n = i.action.pickNumber;
        if (n != null) {
          if (n - 1 < _st.doors.length) _pick(i.player, n - 1);
          return;
        }
        switch (i.action) {
          case GameAction.left:
            setState(() => _st.moveLeft(i.player));
          case GameAction.right:
            setState(() => _st.moveRight(i.player));
          case GameAction.up:
            _pick(i.player);
          case GameAction.action:
            if (_st.questionOver) _afterQuestion();
          case GameAction.pause:
            if (_st.questionOver) _afterQuestion();
          default:
            break;
        }
    }
  }

  // ---- look ----

  DoorRunnerView _view() {
    final doors = [
      for (var i = 0; i < _st.doors.length; i++)
        DoorView(
          _st.doors[i].label,
          mark: _st.questionOver && _st.doors[i].correct
              ? DoorMark.right
              : _st.wrongDoors.contains(i)
              ? DoorMark.wrong
              : DoorMark.idle,
        ),
    ];
    return DoorRunnerView(
      question: _question,
      doors: doors,
      lane: _st.laneOf(1),
      lane2: _st.laneOf(2),
      locked1: _st.isLocked(1),
      locked2: _st.isLocked(2),
      approach: _reduce ? 1 : _st.approach,
      paused: _paused,
      answered: _st.questionOver,
      world: (_index ~/ 4) % DrColors.worlds.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: DoorRunnerIds.raceScreen,
      backgroundColor: DrColors.ink,
      body: GameKeyboard(
        twoPlayer: true,
        onInput: _onInput,
        shortcuts: {LogicalKeyboardKey.keyL: widget.onExit},
        child: switch (_phase) {
          _Phase.intro => _intro(context),
          _Phase.play => _play(context),
          _Phase.over => _over(context),
        },
      ),
    );
  }

  Widget _hints() {
    Widget row(int p) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          p == 1 ? Icons.circle : Icons.square,
          size: 14,
          color: p == 1 ? const Color(0xFFFFC740) : const Color(0xFF59CC9E),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: KeyHints(
            player: p,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
            words: const {GameAction.up: 'zap', GameAction.pick1: 'pick door'},
            actions: [
              GameAction.left,
              GameAction.right,
              GameAction.up,
              ...[
                GameAction.pick1,
                GameAction.pick2,
                GameAction.pick3,
                GameAction.pick4,
              ].take(_cfg.doors),
            ],
          ),
        ),
      ],
    );
    return Padding(
      key: DoorRunnerIds.keys,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 24,
        runSpacing: 6,
        children: [row(1), row(2)],
      ),
    );
  }

  Widget _play(BuildContext context) {
    final view = _view();
    final overlay = Stack(
      children: [
        if (_paused)
          Positioned.fill(
            child: DoorRunnerPauseOverlay(
              onResume: _togglePause,
              onQuit: widget.onExit,
            ),
          ),
        if (_message.isNotEmpty && !_paused)
          Positioned(
            left: 12,
            right: 12,
            bottom: 8,
            child: Semantics(
              liveRegion: true,
              container: true,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xE61B1446),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: DrColors.lilac, width: 1.5),
                ),
                child: Text(
                  _message,
                  key: DoorRunnerIds.raceMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    return DoorRunnerFrame(
      world: view.world,
      hud: _RaceHud(
        paused: _paused,
        onExit: widget.onExit,
        onPause: _togglePause,
        p1: _st.pointsOf(1),
        p2: _st.pointsOf(2),
        target: _st.target,
        locked1: _st.isLocked(1),
        locked2: _st.isLocked(2),
      ),
      question: DoorRunnerQuestionChip(question: _question, onOpen: null),
      field: DoorRunnerField(
        view: view,
        reduceMotion: _reduce,
        interactive: false,
        onZap: (_) {},
      ),
      slowZone: const SizedBox.shrink(),
      hints: _hints(),
      overlay: overlay,
    );
  }

  Widget _backdrop({required List<Widget> children, required Widget action}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: DrColors.world(0),
          stops: const [0, 0.5, 1],
        ),
      ),
      child: SafeArea(
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
                      keyName: 'L',
                      onPressed: widget.onExit,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
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
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: action,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _title = TextStyle(
    color: Colors.white,
    fontSize: 32,
    letterSpacing: 3,
    fontWeight: FontWeight.w800,
    shadows: [Shadow(color: DrColors.lilac, blurRadius: 22)],
  );
  static const _body = TextStyle(color: Colors.white, fontSize: 18);

  Widget _intro(BuildContext context) {
    final keys = GameKeysScope.of(context);
    String set(int p) => [
      keyLabel(keys.primaryOf(KeySlot(GameAction.left, p))),
      keyLabel(keys.primaryOf(KeySlot(GameAction.right, p))),
      keyLabel(keys.primaryOf(KeySlot(GameAction.up, p))),
    ].join(' ');
    return _backdrop(
      children: [
        const Text(
          'DOOR RUNNER: RACE',
          style: _title,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Both runners run the same doors. Steer to the door with the right answer, or zap it. '
          'The first to the right door scores. A wrong door locks you out of that question. '
          'First to ${_st.target} points wins.',
          style: _body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        for (final p in [1, 2])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              'Player $p: ${set(p)}',
              style: _body.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
          ),
      ],
      action: SizedBox(
        width: 300,
        child: DrButton(
          key: DoorRunnerIds.start,
          colors: const [Color(0xFFFFB02E), Color(0xFFFF6B3D)],
          onPressed: _start,
          child: Text(
            keyedLabel(context, 'Start', GameAction.action, alsoSpace: true),
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

  Widget _over(BuildContext context) {
    final headline = _finalWinner == 0
        ? 'A draw!'
        : 'Player $_finalWinner wins!';
    return _backdrop(
      children: [
        Semantics(
          liveRegion: true,
          container: true,
          child: Text(
            headline,
            key: DoorRunnerIds.winner,
            style: _title,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Text('Player 1: ${_st.pointsOf(1)} points', style: _body),
        Text('Player 2: ${_st.pointsOf(2)} points', style: _body),
      ],
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 300,
            child: DrButton(
              key: DoorRunnerIds.again,
              colors: const [Color(0xFFFFB02E), Color(0xFFFF6B3D)],
              onPressed: _start,
              child: Text(
                keyedLabel(
                  context,
                  'Play again',
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
          const SizedBox(height: 8),
          TextButton(
            key: DoorRunnerIds.raceLeave,
            onPressed: widget.onExit,
            child: const Text(
              'Leave (Esc / L)',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// The race's top strip: exit and pause, and a point chip for each player.
class _RaceHud extends StatelessWidget {
  const _RaceHud({
    required this.paused,
    required this.onExit,
    required this.onPause,
    required this.p1,
    required this.p2,
    required this.target,
    required this.locked1,
    required this.locked2,
  });
  final bool paused;
  final VoidCallback onExit;
  final VoidCallback onPause;
  final int p1;
  final int p2;
  final int target;
  final bool locked1;
  final bool locked2;

  Widget _chip(int p, int points, bool locked) {
    final color = p == 1 ? const Color(0xFFFFC740) : const Color(0xFF59CC9E);
    return Semantics(
      label:
          'Player $p, $points of $target points${locked ? ', locked out' : ''}',
      excludeSemantics: true,
      child: Container(
        key: p == 1 ? DoorRunnerIds.p1Score : DoorRunnerIds.p2Score,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0x331B1446),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(p == 1 ? Icons.circle : Icons.square, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              '$points / $target',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (locked) ...[
              const SizedBox(width: 6),
              const Icon(Icons.lock_outline, size: 16, color: Colors.white70),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          KeyedSubtree(
            key: DoorRunnerIds.exit,
            child: DrRoundButton(
              icon: Icons.close,
              tooltip: 'Exit',
              keyName: 'L',
              onPressed: onExit,
            ),
          ),
          const SizedBox(width: 8),
          KeyedSubtree(
            key: DoorRunnerIds.pause,
            child: DrRoundButton(
              icon: paused ? Icons.play_arrow : Icons.pause,
              tooltip: paused ? 'Resume' : 'Pause',
              keyName: 'Esc',
              onPressed: onPause,
            ),
          ),
          Expanded(
            child: Center(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [_chip(2, p2, locked2), _chip(1, p1, locked1)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
