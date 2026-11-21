/// The shared screen of the choose-one games (Balloon pop, Shooter, True or false, ...): start
/// screen, rounds, results. The game supplies the options for an item and draws the play field.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../host/game_host.dart';
import 'game_ids.dart';
import 'game_palette.dart';
import 'keys/keys.dart';
import 'layout/game_frame.dart';
import 'layout/window_class.dart';

/// One thing the child can pick: a door or a balloon.
class ChoiceOption {
  const ChoiceOption(this.label, this.correct);
  final String label;
  final bool correct;
}

/// What a game's play field gets for the current question.
class ChoiceField {
  const ChoiceField({
    required this.gameId,
    required this.options,
    required this.disabled,
    required this.revealed,
    required this.answered,
    required this.onPick,
    required this.reduceMotion,
    required this.level,
    required this.questionIndex,
  });
  final String gameId;
  final List<ChoiceOption> options;

  /// Wrong picks already tried (younger level: try again).
  final Set<int> disabled;

  /// After the answer: the correct option is shown.
  final bool revealed;
  final bool answered;
  final void Function(int index) onPick;
  final bool reduceMotion;
  final MiniGameLevel level;
  final int questionIndex;
}

typedef ChoiceFieldBuilder = Widget Function(
  BuildContext context,
  ChoiceField field,
);

/// The shared screen of Door runner and Balloon pop: start screen, rounds, results.
/// The game supplies the options for an item and draws the play field.
///
/// Younger level: no timer, no failing; a wrong pick is greyed out and the child tries again.
/// Older level: a gentle timer; a wrong pick or time running out shows the answer and moves on.
/// Banners show on the start and results screens only, never during play.
class ChoiceGameScreen extends StatefulWidget {
  const ChoiceGameScreen({
    super.key,
    required this.gameId,
    required this.title,
    required this.howTo,
    required this.session,
    required this.level,
    required this.secondsPerQuestion,
    required this.retry,
    required this.layout,
    required this.fieldBuilder,
    required this.onExit,
    this.onAnswered,
    this.onScore,
    this.reader,
    this.random,
    this.autoRead,
    this.promptOf,
    this.introExtra,
  });

  /// Shown under the Start button on the start screen (Tug of war: "Play with a sibling").
  final Widget? introExtra;

  /// The text shown (and read aloud) for an item; null: the item's `prompt`.
  final String Function(PoolItem item)? promptOf;

  final String gameId;
  final String title;
  final String howTo;
  final QuizSession session;
  final MiniGameLevel level;

  /// 0: no timer.
  final int secondsPerQuestion;
  final bool retry;
  final List<ChoiceOption>? Function(PoolItem item, Random random) layout;
  final ChoiceFieldBuilder fieldBuilder;
  final VoidCallback onExit;
  final void Function(AnswerResult result, QuizSession session)? onAnswered;
  final void Function(int score)? onScore;
  final GameReadAloud? reader;
  final Random? random;
  final bool? autoRead;

  @override
  State<ChoiceGameScreen> createState() => _ChoiceGameScreenState();
}

enum _Phase { intro, play, results }

class _ChoiceGameScreenState extends State<ChoiceGameScreen>
    with SingleTickerProviderStateMixin {
  _Phase _phase = _Phase.intro;
  late final Random _random = widget.random ?? Random();
  late final AnimationController _timer;
  List<ChoiceOption>? _options;
  int _optionsFor = -1;
  final Set<int> _disabled = {};
  AnswerResult? _result;
  bool _timedOut = false;
  int _wrongTries = 0;
  int _score = 0;
  int _streak = 0;
  int _best = 0;
  bool _scoreSent = false;
  bool _paused = false;
  GameReadAloud? _reader;
  bool _autoRead = false;
  int? _autoReadIndex;

  QuizSession get _s => widget.session;
  MiniGameLevel get _lv => widget.level;
  String get _g => widget.gameId;

  @override
  void initState() {
    super.initState();
    _timer = AnimationController(
      vsync: this,
      duration: Duration(
        seconds: widget.secondsPerQuestion > 0 ? widget.secondsPerQuestion : 1,
      ),
    )..addStatusListener(_onTimer);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final host = GameHostScope.of(context);
    _reader = widget.reader ?? host.readAloud(context);
    _autoRead = widget.autoRead ?? host.autoRead(context);
  }

  @override
  void dispose() {
    _timer.dispose();
    _reader?.stop();
    super.dispose();
  }

  void _onTimer(AnimationStatus st) {
    if (st != AnimationStatus.completed || _result != null) return;
    _timedOut = true;
    _finishAnswer(correct: false);
  }

  PoolItem? get _item => _s.finished ? null : _s.items[_s.index];

  void _start() {
    setState(() => _phase = _Phase.play);
    _beginQuestion();
  }

  void _beginQuestion() {
    final p = _item;
    if (p == null) return _toResults();
    _options = widget.layout(p, _random);
    _optionsFor = _s.index;
    if (_options == null) return _toResults();
    if (widget.secondsPerQuestion > 0) _timer.forward(from: 0);
    _maybeAutoRead(p);
  }

  void _toResults() {
    _timer.stop();
    if (!_scoreSent) {
      _scoreSent = true;
      widget.onScore?.call(_score);
    }
    setState(() => _phase = _Phase.results);
  }

  ChoiceOption? get _right {
    for (final o in _options ?? const <ChoiceOption>[]) {
      if (o.correct) return o;
    }
    return null;
  }

  void _pick(int i) {
    if (_result != null || _options == null) return;
    if (_options![i].correct) {
      _finishAnswer(correct: true);
    } else if (widget.retry) {
      // Younger: no failing. The wrong pick is greyed out and the child tries another.
      setState(() {
        _disabled.add(i);
        _wrongTries++;
      });
    } else {
      _finishAnswer(correct: false);
    }
  }

  void _finishAnswer({required bool correct}) {
    _timer.stop();
    _reader?.stop();
    final r = _s.answer(
      correct: correct && _wrongTries == 0,
      timedOut: _timedOut,
    );
    widget.onAnswered?.call(r, _s);
    setState(() {
      if (correct) {
        _score += scoreForAnswer(streak: _streak, older: _lv.older);
        _streak++;
        if (_streak > _best) _best = _streak;
      } else {
        _streak = 0;
      }
      _result = AnswerResult(
        correct: correct,
        firstPass: r.firstPass,
        stars: r.stars,
        coins: r.coins,
        topicCompleted: r.topicCompleted,
        explanation: r.explanation,
      );
    });
  }

  void _next() {
    setState(() {
      _result = null;
      _timedOut = false;
      _wrongTries = 0;
      _disabled.clear();
    });
    if (_s.finished) {
      _toResults();
    } else {
      _beginQuestion();
    }
  }

  Future<void> _read(PoolItem p) => _reader == null
      ? Future.value()
      : _reader!.read(_prompt(p), audioRef: p.item.audio);

  String _prompt(PoolItem p) =>
      widget.promptOf?.call(p) ?? p.item.json['prompt'] as String;

  void _maybeAutoRead(PoolItem p) {
    if (!_autoRead || _reader == null || _autoReadIndex == _s.index) return;
    _autoReadIndex = _s.index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _result == null) _read(p);
    });
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
      key: GameIds.mgBanner(_g),
      child: host.banner(context, slot),
    );
  }

  // ---- keyboard (docs/KEYBOARD.md): 1 to 4 answer, Enter next or start, Q reads, Space pauses ----

  void _onInput(GameInput i) {
    if (i.action == GameAction.exit) {
      widget.onExit();
      return;
    }
    if (i.repeat) return;
    switch (_phase) {
      case _Phase.intro:
        if (i.action == GameAction.action) _start();
      case _Phase.results:
        if (i.action == GameAction.action) widget.onExit();
      case _Phase.play:
        if (i.action == GameAction.pause) {
          _togglePause();
        } else if (_paused) {
          return;
        } else if (i.action.pickNumber != null) {
          final n = i.action.pickNumber! - 1;
          final opts = _options;
          if (opts != null && n < opts.length && !_disabled.contains(n)) {
            _pick(n);
          }
        } else if (i.action == GameAction.action) {
          if (_result != null) _next();
        } else if (i.action == GameAction.question) {
          final p = _item;
          if (p != null && _result == null) _read(p);
        }
    }
  }

  void _togglePause() {
    if (_phase != _Phase.play || _result != null) return;
    setState(() => _paused = !_paused);
    if (_paused) {
      _timer.stop();
      _reader?.stop();
    } else if (widget.secondsPerQuestion > 0) {
      _timer.forward();
    }
  }

  List<GameAction> get _hintActions => switch (_phase) {
    _Phase.intro => const [GameAction.action, GameAction.exit],
    _Phase.results => const [GameAction.action, GameAction.exit],
    _Phase.play => [
      if (_result != null)
        GameAction.action
      else ...[
        GameAction.pick1,
        GameAction.pick2,
        GameAction.pick3,
        GameAction.pick4,
        if (_reader != null) GameAction.question,
      ],
      GameAction.pause,
      GameAction.exit,
    ],
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = WindowClass.ofContext(context) != WindowClass.compact;
    return Scaffold(
      key: GameIds.mgScreen(_g),
      body: SafeArea(
        child: GameKeyboard(
          onInput: _onInput,
          child: GameFrame(
            // No ad beside the game while a question is being played.
            showAds: _phase != _Phase.play,
            // The start and results screens draw their own phone banner.
            phoneBanner: null,
            child: Column(
              children: [
                // No title bar: exit and pause are small controls over the game (R2).
                Row(
                  children: [
                    IconButton(
                      key: GameIds.mgExit(_g),
                      tooltip: 'Leave ${widget.title}',
                      icon: const Icon(Icons.close),
                      onPressed: widget.onExit,
                    ),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_phase == _Phase.play && _result == null)
                      IconButton(
                        key: GameIds.mgPause(_g),
                        tooltip: _paused ? 'Resume' : 'Pause',
                        icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                        onPressed: _togglePause,
                      ),
                  ],
                ),
                Expanded(
                  child: Stack(
                    children: [
                      switch (_phase) {
                        _Phase.intro => _intro(context),
                        _Phase.play => _play(context),
                        _Phase.results => _results(context),
                      },
                      if (_paused) _pausedOverlay(theme),
                    ],
                  ),
                ),
                if (wide)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: KeyHints(actions: _hintActions),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pausedOverlay(ThemeData theme) => Positioned.fill(
    child: ColoredBox(
      key: GameIds.mgPaused(_g),
      color: theme.colorScheme.scrim.withValues(alpha: 0.6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Paused',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: GameIds.mgResume(_g),
              onPressed: _togglePause,
              child: const Text('Resume'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _intro(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              key: GameIds.mgIntro(_g),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.howTo,
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: GameIds.mgStart(_g),
                    onPressed: _start,
                    child: const Text('Start'),
                  ),
                  if (widget.introExtra != null) ...[
                    const SizedBox(height: 12),
                    widget.introExtra!,
                  ],
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
    final r = _s.report;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              key: GameIds.mgResults(_g),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  if (_lv.older && _best > 1)
                    Text('Best streak $_best in a row'),
                  if (_s.rewardsConfig.starsEnabled) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${r.stars} stars earned',
                      key: GameIds.mgStars(_g),
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    key: GameIds.mgDone(_g),
                    onPressed: widget.onExit,
                    child: const Text('Done'),
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
    final p = _item ?? (_result != null ? _s.items[_s.index - 1] : null);
    final opts = _options;
    if (p == null || opts == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final pal = MiniGamePalette(context);
    final reduce = pal.reduceMotion || MediaQuery.disableAnimationsOf(context);
    final index = _result != null ? _s.index - 1 : _s.index;
    final answered = _result != null;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Question ${index + 1} of ${_s.total}',
                  key: GameIds.mgProgress(_g),
                  style: theme.textTheme.labelLarge,
                ),
              ),
              Text('Score $_score', key: GameIds.mgScore(_g)),
              if (_reader != null)
                IconButton(
                  key: GameIds.mgSpeak(_g),
                  tooltip: 'Read the question aloud',
                  icon: const Icon(Icons.volume_up),
                  onPressed: () => _read(p),
                ),
            ],
          ),
        ),
        if (widget.secondsPerQuestion > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Semantics(
              label: 'Time left',
              child: AnimatedBuilder(
                animation: _timer,
                builder: (_, _) => LinearProgressIndicator(
                  key: GameIds.mgTimer(_g),
                  minHeight: 8,
                  value: 1 - _timer.value,
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Semantics(
            header: true,
            child: Text(
              _prompt(p),
              key: GameIds.mgPrompt(_g),
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Expanded(
          child: KeyedSubtree(
            key: GameIds.mgField(_g),
            child: widget.fieldBuilder(
              context,
              ChoiceField(
                gameId: _g,
                options: opts,
                disabled: _disabled,
                revealed: answered,
                answered: answered,
                onPick: _pick,
                reduceMotion: reduce,
                level: _lv,
                questionIndex: _optionsFor,
              ),
            ),
          ),
        ),
        if (_disabled.isNotEmpty && !answered)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Semantics(
              liveRegion: true,
              child: Text(
                'Not that one. Try another!',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
        if (answered)
          Flexible(
            flex: 0,
            child: SingleChildScrollView(child: _feedback(theme)),
          ),
      ],
    );
  }

  Widget _feedback(ThemeData theme) {
    final r = _result!;
    final right = _right;
    final headline = r.correct
        ? 'Correct!'
        : _timedOut
        ? 'Time is up. The answer was ${right?.label}.'
        : 'Not quite. The answer was ${right?.label}.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Column(
          key: GameIds.mgFeedback(_g),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(r.correct ? Icons.check_circle : Icons.info_outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(headline, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            if (r.explanation.isNotEmpty) Text(r.explanation),
            if (r.stars > 0)
              Text('+${r.stars} ${r.stars == 1 ? 'star' : 'stars'}'),
            const SizedBox(height: 8),
            FilledButton(
              key: GameIds.mgNext(_g),
              onPressed: _next,
              child: Text(_s.finished ? 'See results' : 'Next'),
            ),
          ],
        ),
      ),
    );
  }
}
