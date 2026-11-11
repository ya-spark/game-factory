import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/services.dart';
import '../../core/speech/speech_service.dart';
import '../../engine/engine.dart';
import '../test_ids.dart';
import '../theme/app_theme.dart';

/// One thing the child can pick: a door or a balloon.
class ChoiceOption {
  const ChoiceOption(this.label, this.correct);
  final String label;
  final bool correct;
}

/// Colours from the design theme, or from the plain Material theme when there is none.
class MiniGamePalette {
  MiniGamePalette(BuildContext context)
    : _t = ThemeTokens.maybeOf(context),
      _c = Theme.of(context).colorScheme;
  final ThemeTokens? _t;
  final ColorScheme _c;

  Color get bg => _t?.bg ?? _c.surface;
  Color get surface => _t?.surface ?? _c.surfaceContainerHighest;
  Color get text => _t?.text ?? _c.onSurface;
  Color get primary => _t?.primary ?? _c.primary;
  Color get onPrimary => _t?.onPrimary ?? _c.onPrimary;
  Color get accent => _t?.accent ?? _c.secondary;
  Color get onAccent => _t?.onAccent ?? _c.onSecondary;
  Color get border => _t?.border ?? _c.outline;
  Color get success => _t?.success ?? _c.tertiary;
  bool get reduceMotion => _t?.reduceMotion ?? false;
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
    this.recordedClip,
  });

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
  final ReadAloud? reader;
  final Random? random;
  final bool? autoRead;
  final RecordedClipPlayer? recordedClip;

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
  ReadAloud? _reader;
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
    final services = context
        .dependOnInheritedWidgetOfExactType<ServicesScope>()
        ?.services;
    _reader =
        widget.reader ??
        (services == null
            ? null
            : ReadAloud(
                speech: services.speech,
                recorded: widget.recordedClip,
              ));
    _autoRead = widget.autoRead ?? services?.config.speech.autoRead ?? false;
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
    final r = _s.answer(correct: correct && _wrongTries == 0);
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

  String _prompt(PoolItem p) => p.item.json['prompt'] as String;

  void _maybeAutoRead(PoolItem p) {
    if (!_autoRead || _reader == null || _autoReadIndex == _s.index) return;
    _autoReadIndex = _s.index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _result == null) _read(p);
    });
  }

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
        title: Text(widget.title),
        leading: IconButton(
          key: TestIds.mgExit(_g),
          tooltip: 'Leave ${widget.title}',
          icon: const Icon(Icons.close),
          onPressed: widget.onExit,
        ),
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.intro => _intro(context),
          _Phase.play => _play(context),
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
                    key: TestIds.mgStart(_g),
                    onPressed: _start,
                    child: const Text('Start'),
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

  Widget _results(BuildContext context) {
    final theme = Theme.of(context);
    final r = _s.report;
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
                        'Round finished. ${r.correct} of ${r.answered} right. Score $_score.',
                    child: Text(
                      '${r.correct} of ${r.answered} right',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Score $_score', key: TestIds.mgScore(_g)),
                  if (_lv.older && _best > 1)
                    Text('Best streak $_best in a row'),
                  if (_s.rewardsConfig.starsEnabled) ...[
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
                  key: TestIds.mgProgress(_g),
                  style: theme.textTheme.labelLarge,
                ),
              ),
              Text('Score $_score', key: TestIds.mgScore(_g)),
              if (_reader != null)
                IconButton(
                  key: TestIds.mgSpeak(_g),
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
                  key: TestIds.mgTimer(_g),
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
              key: TestIds.mgPrompt(_g),
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Expanded(
          child: KeyedSubtree(
            key: TestIds.mgField(_g),
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
          key: TestIds.mgFeedback(_g),
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
              key: TestIds.mgNext(_g),
              onPressed: _next,
              child: Text(_s.finished ? 'See results' : 'Next'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The level for a session: years 0 to 2 are younger, the rest older.
MiniGameLevel levelForSession(QuizSession s, {bool harder = false}) {
  final year = s.items.isEmpty ? 3 : s.items.first.year;
  return year <= 2
      ? const MiniGameLevel.younger()
      : MiniGameLevel.older(harder: harder);
}
