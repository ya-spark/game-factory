import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';

import 'rules/tug_head_to_head_rules.dart';
import 'rules/tug_of_war_rules.dart';
import 'tug_of_war_ids.dart';
import 'tug_of_war_screen.dart' show TugRopePainter;

/// Tug of war, head to head (docs/SPEC.md, "Two players"): both players see the same question
/// and race on their own keys, player 1 on 1 to 4 and player 2 on Z X C V. The first right
/// answer pulls the rope toward that player; a wrong one locks that player out of the question.
/// Nothing is recorded: no stars, coins or progress, and the quiz session is never touched.
class TugOfWarHeadToHeadScreen extends StatefulWidget {
  const TugOfWarHeadToHeadScreen({
    super.key,
    required this.items,
    required this.level,
    required this.onExit,
    this.random,
    this.betweenQuestions = const Duration(milliseconds: 1600),
  });

  /// The questions (the session's items, read only); only `mcq` items can be played.
  final List<PoolItem> items;
  final MiniGameLevel level;
  final VoidCallback onExit;
  final Random? random;

  /// How long the answer stays on screen before the next question.
  final Duration betweenQuestions;

  @override
  State<TugOfWarHeadToHeadScreen> createState() => _HeadToHeadState();
}

enum _Phase { intro, question, between, over }

class _HeadToHeadState extends State<TugOfWarHeadToHeadScreen>
    with SingleTickerProviderStateMixin {
  late final Random _random = widget.random ?? Random();
  late HeadToHeadRun _run = HeadToHeadRun(widget.level);
  late final AnimationController _timer;
  _Phase _phase = _Phase.intro;
  int _index = -1;
  List<TugOption>? _options;
  bool _paused = false;
  Timer? _next;
  String _message = '';
  int _finalWinner = 0;

  @override
  void initState() {
    super.initState();
    final s = _run.settings.secondsPerQuestion;
    _timer =
        AnimationController(
          vsync: this,
          duration: Duration(seconds: s > 0 ? s : 1),
        )..addStatusListener((st) {
          if (st == AnimationStatus.completed && _phase == _Phase.question) {
            _run.timeUp();
            _endQuestion('Time is up.');
          }
        });
  }

  @override
  void dispose() {
    _next?.cancel();
    _timer.dispose();
    super.dispose();
  }

  bool get _playing => _phase == _Phase.question || _phase == _Phase.between;

  // ---- flow ----

  void _start() {
    _run = HeadToHeadRun(widget.level);
    _index = -1;
    _advance();
  }

  /// Moves to the next question that can be played; the game ends when there is none.
  void _advance() {
    _next?.cancel();
    while (true) {
      _index++;
      if (_index >= widget.items.length) {
        _finish();
        return;
      }
      final o = layoutTugOptions(
        widget.items[_index].item,
        _run.settings.options,
        _random,
      );
      if (o != null) {
        _options = o;
        break;
      }
    }
    _run.nextQuestion();
    setState(() {
      _phase = _Phase.question;
      _message = '';
    });
    if (_run.settings.secondsPerQuestion > 0) _timer.forward(from: 0);
  }

  void _finish() {
    _timer.stop();
    setState(() {
      _finalWinner = _run.decideWhenOut();
      _phase = _Phase.over;
    });
  }

  void _press(int player, int option) {
    if (_phase != _Phase.question || _paused) return;
    final opts = _options;
    if (opts == null || option < 0 || option >= opts.length) return;
    final r = _run.press(player, correct: opts[option].correct);
    if (r == HeadPress.ignored) return;
    if (r == HeadPress.pulled) {
      final round = _run.roundWinner;
      _endQuestion(
        round != null
            ? 'Player $player pulled it all the way and takes the round!'
            : 'Player $player got it first!',
      );
    } else if (_run.questionOver) {
      final round = _run.roundWinner;
      _endQuestion(
        round != null
            ? 'Player $round takes the round! No one got it.'
            : 'No one got it.',
      );
    } else {
      final round = _run.roundWinner;
      setState(
        () => _message = round != null
            ? 'Player $player slipped. Player $round takes the round!'
            : 'Player $player is out of this question.',
      );
      if (round != null && _run.isOver) _endQuestion(_message);
    }
  }

  void _endQuestion(String message) {
    _timer.stop();
    setState(() {
      _phase = _Phase.between;
      _message = message;
    });
    _scheduleNext();
  }

  void _scheduleNext() {
    _next?.cancel();
    _next = Timer(widget.betweenQuestions, _after);
  }

  void _after() {
    if (!mounted || _paused) return;
    if (_run.isOver) {
      _finish();
    } else {
      _advance();
    }
  }

  void _togglePause() {
    if (!_playing) return;
    setState(() => _paused = !_paused);
    if (_paused) {
      _timer.stop();
      _next?.cancel();
    } else if (_phase == _Phase.question) {
      if (_run.settings.secondsPerQuestion > 0) _timer.forward();
    } else {
      _scheduleNext();
    }
  }

  // ---- keys (docs/KEYBOARD.md) ----

  void _onInput(GameInput i) {
    if (i.action == GameAction.exit) {
      if (i.repeat) return;
      _playing ? _togglePause() : widget.onExit();
      return;
    }
    // Enter or Space (the pause key) goes on from intro, between rounds and results; Space only
    // pauses while a question is open (U2).
    final goOn = i.action == GameAction.action || i.action == GameAction.pause;
    if (i.action == GameAction.pause && _phase == _Phase.question) {
      if (!i.repeat) _togglePause();
      return;
    }
    if (_paused || i.repeat) return;
    switch (_phase) {
      case _Phase.intro:
        if (goOn) _start();
      case _Phase.question:
        final n = i.action.pickNumber;
        if (n != null) _press(i.player, n - 1);
      case _Phase.between:
        if (goOn) _after();
      case _Phase.over:
        if (goOn) _start();
    }
  }

  // ---- look ----

  Color _color(ColorScheme cs, int p) => p == 1 ? cs.primary : cs.secondary;
  IconData _marker(int p) => p == 1 ? Icons.circle : Icons.square;

  @override
  Widget build(BuildContext context) {
    final wide = WindowClass.ofContext(context) != WindowClass.compact;
    return Scaffold(
      key: TugIds.h2hScreen,
      body: SafeArea(
        child: GameKeyboard(
          twoPlayer: true,
          onInput: _onInput,
          child: GameFrame(
            showAds: !_playing,
            phoneBanner: null,
            child: Column(
              children: [
                GameTopBar(
                  title: 'Tug of war: head to head',
                  onExit: widget.onExit,
                  exitKey: TugIds.exit,
                  onPause: _playing ? _togglePause : null,
                  pauseKey: TugIds.pause,
                  paused: _paused,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      switch (_phase) {
                        _Phase.intro => _intro(context),
                        _Phase.over => _over(context),
                        _ => _play(context),
                      },
                      if (_paused)
                        PauseOverlay(
                          overlayKey: TugIds.paused,
                          resumeKey: TugIds.resume,
                          onResume: _togglePause,
                          onLeave: widget.onExit,
                          leaveKey: TugIds.leave,
                        ),
                    ],
                  ),
                ),
                if (wide && _phase != _Phase.over) _hints(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hints(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final n = _phase == _Phase.question || _phase == _Phase.between
        ? (_options?.length ?? 2)
        : _run.settings.options;
    final picks = [
      GameAction.pick1,
      GameAction.pick2,
      GameAction.pick3,
      GameAction.pick4,
    ].take(n).toList();
    Widget row(int p) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_marker(p), size: 14, color: _color(cs, p)),
        const SizedBox(width: 6),
        Flexible(
          child: KeyHints(
            player: p,
            actions: picks,
            words: const {GameAction.pick1: 'answer'},
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 24,
        runSpacing: 6,
        children: [row(1), row(2)],
      ),
    );
  }

  Widget _intro(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final keys = GameKeysScope.of(context);
    String range(int p) {
      final a =
          [
                GameAction.pick1,
                GameAction.pick2,
                GameAction.pick3,
                GameAction.pick4,
              ]
              .take(_run.settings.options)
              .map((x) => keyLabel(keys.primaryOf(KeySlot(x, p))))
              .join(' ');
      return a;
    }

    return Center(
      child: SingleChildScrollView(
        key: GameIds.mgIntro('tug_of_war'),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Head to head',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Both players see the same question. The first to press the right answer pulls the rope '
              'their way. A wrong answer locks you out of that question. Bring the rope all the way '
              'to your end to win the round, and win two rounds to win the game.',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            for (final p in [1, 2])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Icon(_marker(p), color: _color(cs, p), size: 18),
                    Text(
                      'Player $p answers with',
                      style: theme.textTheme.titleMedium,
                    ),
                    KeyCap(label: range(p), accent: _color(cs, p)),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              key: TugIds.start,
              onPressed: _start,
              child: const Text('Start (Enter)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, int p) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final locked = _phase == _Phase.question && _run.isLocked(p);
    final rounds = _run.roundsOf(p);
    return Semantics(
      label:
          'Player $p, $rounds ${rounds == 1 ? 'round' : 'rounds'}${locked ? ', locked out' : ''}',
      excludeSemantics: true,
      child: Container(
        key: p == 1 ? TugIds.p1Score : TugIds.p2Score,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _color(cs, p), width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_marker(p), color: _color(cs, p), size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Player $p: $rounds',
                style: theme.textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (locked) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.lock_outline,
                key: p == 1 ? TugIds.p1Locked : TugIds.p2Locked,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _play(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final item = widget.items[_index];
    final opts = _options!;
    final between = _phase == _Phase.between;
    final keys = GameKeysScope.of(context);
    final picks = [
      GameAction.pick1,
      GameAction.pick2,
      GameAction.pick3,
      GameAction.pick4,
    ];
    final status =
        'Rope ${_run.position == 0
            ? 'in the middle'
            : _run.position > 0
            ? '${_run.position} steps toward player 1'
            : '${-_run.position} steps toward player 2'}. '
        'Rounds: player 1 ${_run.roundsOf(1)}, player 2 ${_run.roundsOf(2)}.';
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Question ${_index + 1}', style: theme.textTheme.labelLarge),
          if (_run.settings.secondsPerQuestion > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Semantics(
                label: 'Time left',
                child: AnimatedBuilder(
                  animation: _timer,
                  builder: (_, _) => LinearProgressIndicator(
                    key: TugIds.timer,
                    minHeight: 8,
                    value: 1 - _timer.value,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Semantics(
              header: true,
              child: Text(
                item.item.json['prompt'] as String,
                key: TugIds.question,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          for (var i = 0; i < opts.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                label:
                    '${opts[i].label}. Player 1 key ${keySpokenLabel(keys.primaryOf(KeySlot(picks[i], 1)))}, player 2 key ${keySpokenLabel(keys.primaryOf(KeySlot(picks[i], 2)))}${between && opts[i].correct ? ', the right answer' : ''}',
                excludeSemantics: true,
                child: Container(
                  key: TugIds.option(i),
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: between && opts[i].correct
                        ? cs.tertiaryContainer
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: between && opts[i].correct
                          ? cs.tertiary
                          : cs.outline,
                      width: between && opts[i].correct ? 3 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      KeyCap(
                        label: keyLabel(keys.primaryOf(KeySlot(picks[i], 2))),
                        accent: _color(cs, 2),
                      ),
                      Expanded(
                        child: Text(
                          opts[i].label,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (between && opts[i].correct)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.check_circle),
                        ),
                      KeyCap(
                        label: keyLabel(keys.primaryOf(KeySlot(picks[i], 1))),
                        accent: _color(cs, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 4),
          Semantics(
            container: true,
            label: status,
            child: ExcludeSemantics(
              child: SizedBox(
                key: TugIds.rope,
                height: 64,
                child: CustomPaint(
                  painter: TugRopePainter(
                    position: _run.position,
                    reach: _run.settings.reach,
                    me: _color(cs, 1),
                    them: _color(cs, 2),
                    rope: cs.onSurface,
                    marker: cs.tertiary,
                    edge: cs.outline,
                  ),
                ),
              ),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [_chip(context, 2), _chip(context, 1)],
          ),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: SizedBox(
              height: 48,
              child: Text(
                _message,
                key: TugIds.message,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _over(BuildContext context) {
    final theme = Theme.of(context);
    final headline = _finalWinner == 0
        ? 'A draw!'
        : 'Player $_finalWinner wins!';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              liveRegion: true,
              container: true,
              child: Text(
                headline,
                key: TugIds.winner,
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Player 1: ${_run.roundsOf(1)} rounds',
              style: theme.textTheme.titleMedium,
            ),
            Text(
              'Player 2: ${_run.roundsOf(2)} rounds',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: TugIds.again,
              onPressed: _start,
              child: const Text('Play again'),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: TugIds.leave,
              onPressed: widget.onExit,
              child: const Text('Leave'),
            ),
          ],
        ),
      ),
    );
  }
}
