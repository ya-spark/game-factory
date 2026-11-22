import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:game_core/game_core.dart';

import 'judge_bot_ids.dart';
import 'rules/judge_rules.dart';
import 'ui/judge_art.dart';

/// Judge bot (package and id `judge_bot`): plays `mcq` items. A toy judge robot reads a ticket;
/// the child judges the claim TRUE or FALSE. Free with ads, Game and Study mode. [harder] is for
/// Champion. Spec: `docs/SPEC.md`.
MiniGame judgeBotGameFor({bool harder = false}) => MiniGame(
  id: judgeBotId,
  title: judgeBotTitle,
  itemTypes: const {ItemType.mcq},
  accepts: (p) => isClaimable(p.item),
  minPool: 4,
  build: (ctx) => JudgeBotScreen(
    session: ctx.session,
    onExit: ctx.onExit,
    onAnswered: ctx.onAnswered,
    onScore: ctx.onScore,
    level: levelForSession(ctx.session, harder: harder),
    study: ctx.mode == MiniGameMode.study,
  ),
);

final MiniGame judgeBotGame = judgeBotGameFor();

/// How to play, as shown on the start screen (the catalogue and the web text say the same).
const String judgeBotHowTo =
    'I read a ticket. You say TRUE or FALSE. Press T or F, or tap a lamp.';

class JudgeBotScreen extends StatefulWidget {
  const JudgeBotScreen({
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

  /// Study mode: calm, no timer, nothing moves on by itself.
  final bool study;
  final void Function(AnswerResult, QuizSession)? onAnswered;
  final void Function(int)? onScore;
  final Random? random;

  /// Overrides the container's read-aloud (tests).
  final GameReadAloud? reader;

  @override
  State<JudgeBotScreen> createState() => _JudgeBotScreenState();
}

enum _Phase { intro, play, results }

class _Missed {
  const _Missed(this.claim);
  final Claim claim;
}

class _JudgeBotScreenState extends State<JudgeBotScreen>
    with TickerProviderStateMixin {
  static const String _g = judgeBotId;
  static const double _btn = 44;

  late final JudgeSettings _cfg = JudgeSettings.forLevel(
    widget.level,
    study: widget.study,
  );
  late final Random _random = widget.random ?? Random();
  late final ClaimDealer _dealer = ClaimDealer([
    for (final p in widget.session.items) p.item,
  ], _random);
  late final AnimationController _timer = AnimationController(
    vsync: this,
    duration: Duration(seconds: _cfg.timed ? _cfg.secondsPerQuestion : 1),
  )..addStatusListener(_onTimer);
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  late final AnimationController _verdict = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final AnimationController _cheer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  _Phase _phase = _Phase.intro;
  Claim? _claim;
  int _ticket = 0;
  AnswerResult? _result;
  bool _timedOut = false;
  bool _fast = false;
  int? _cursor;
  bool _keyed = false;
  bool _paused = false;
  bool _reduce = false;
  int _score = 0;
  int _streak = 0;
  int _best = 0;
  bool _scoreSent = false;
  final List<_Missed> _missed = [];
  Timer? _auto;
  GameReadAloud? _reader;
  bool _autoRead = false;
  int? _autoReadIndex;

  QuizSession get _s => widget.session;
  bool get _canPick =>
      _phase == _Phase.play && _result == null && !_paused && _claim != null;

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
    _auto?.cancel();
    _timer.dispose();
    _slide.dispose();
    _verdict.dispose();
    _cheer.dispose();
    _reader?.stop();
    super.dispose();
  }

  // ---- flow ------------------------------------------------------------------

  void _start() {
    setState(() => _phase = _Phase.play);
    _beginTicket();
  }

  void _beginTicket() {
    if (_s.finished) return _toResults();
    final claim = _dealer.claimAt(_s.index);
    if (claim == null) return _toResults();
    _auto?.cancel();
    _claim = claim;
    _ticket = _s.index;
    _result = null;
    _timedOut = false;
    _fast = false;
    _cursor = null;
    _verdict.value = 0;
    _cheer.value = 0;
    if (_reduce) {
      _slide.value = 1;
    } else {
      _slide.forward(from: 0);
    }
    if (_cfg.timed) _timer.forward(from: 0);
    _maybeAutoRead();
    if (mounted) setState(() {});
  }

  void _toResults() {
    _timer.stop();
    _auto?.cancel();
    if (!_scoreSent) {
      _scoreSent = true;
      widget.onScore?.call(_score);
    }
    if (mounted) setState(() => _phase = _Phase.results);
  }

  void _onTimer(AnimationStatus st) {
    if (st != AnimationStatus.completed || !_canPick) return;
    _timedOut = true;
    _pick(null);
  }

  /// The child's verdict ([saysTrue]), or null when the time ran out. Called once per ticket.
  void _pick(bool? saysTrue) {
    final claim = _claim;
    if (!_canPick || claim == null) return;
    final correct = saysTrue != null && saysTrue == claim.isTrue;
    _timer.stop();
    _reader?.stop();
    final fast =
        correct &&
        _cfg.timed &&
        widget.level.older &&
        isFastAnswer(
          _timer.value * _cfg.secondsPerQuestion,
          _cfg.secondsPerQuestion,
        );
    final r = _s.answer(
      correct: correct,
      timedOut: _timedOut,
      skillEvidence: countsAsSkillEvidence(
        correct: correct,
        streakBefore: _streak,
      ),
    );
    widget.onAnswered?.call(r, _s);
    if (correct) {
      _score += judgeScore(
        streak: _streak,
        older: widget.level.older,
        fast: fast,
      );
      _streak++;
      if (_streak > _best) _best = _streak;
    } else {
      _streak = 0;
      _missed.add(_Missed(claim));
    }
    _fast = fast;
    _result = AnswerResult(
      correct: correct,
      firstPass: r.firstPass,
      stars: r.stars,
      coins: r.coins,
      topicCompleted: r.topicCompleted,
      explanation: r.explanation,
    );
    if (_reduce) {
      _verdict.value = 1;
      _cheer.value = 0;
    } else {
      _verdict.forward(from: 0);
      if (correct && _streak >= 3) _cheer.forward(from: 0);
    }
    // A right answer with no explanation moves on by itself (older level; never with reduced
    // motion or a screen reader). Everything else waits for Next.
    final reader = MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;
    if (correct &&
        _cfg.autoMove &&
        r.explanation.isEmpty &&
        !_reduce &&
        !reader) {
      _auto = Timer(judgeAutoMove, () {
        if (mounted && _result != null && !_paused) _next();
      });
    }
    setState(() {});
  }

  void _next() {
    if (_phase != _Phase.play || _result == null) return;
    _auto?.cancel();
    if (_s.finished) {
      _toResults();
    } else {
      _beginTicket();
    }
  }

  void _togglePause() {
    if (_phase != _Phase.play || _result != null) return;
    setState(() => _paused = !_paused);
    if (_paused) {
      _timer.stop();
      _reader?.stop();
    } else if (_cfg.timed) {
      _timer.forward();
    }
  }

  // ---- reading ---------------------------------------------------------------

  String get _ticketText {
    final c = _claim;
    if (c == null) return '';
    return c.derived
        ? 'Question: ${c.question.trim().replaceFirst(RegExp(r'[?.!:\s]+$'), '')}. Claim: ${c.shown} True or false?'
        : 'Statement: ${c.shown} True or false?';
  }

  Future<void> _read() {
    final r = _reader;
    final c = _claim;
    if (r == null || c == null) return Future.value();
    final text = _result != null ? _feedbackText(c) : _ticketText;
    return r.read(
      text,
      audioRef: _s.index < _s.items.length && _result == null
          ? _s.items[_s.index].item.audio
          : null,
    );
  }

  void _maybeAutoRead() {
    if (!_autoRead || _reader == null || _autoReadIndex == _s.index) return;
    _autoReadIndex = _s.index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _result == null) _read();
    });
  }

  String _headline() {
    final r = _result;
    if (r == null) return '';
    if (r.correct) return 'Right!';
    return _timedOut ? 'Time is up.' : 'Not this time.';
  }

  String _feedbackText(Claim c) {
    final b = StringBuffer('${_headline()} ${c.feedback}');
    if (_result!.explanation.isNotEmpty) b.write(' ${_result!.explanation}');
    if (_result!.correct) b.write(' Streak $_streak.');
    return b.toString();
  }

  // ---- keyboard (docs/SPEC.md, Keyboard) ----------------------------------------

  void _onInput(GameInput i) {
    final a = i.action;
    if (i.repeat) return;
    if (a == GameAction.exit) {
      // Esc pauses a ticket (the pause screen offers Leave); elsewhere it leaves.
      if (_phase == _Phase.play && _result == null) {
        _togglePause();
      } else {
        widget.onExit();
      }
      return;
    }
    // Space is the same key as Enter here (B-01): it confirms and goes on, it never pauses.
    final go = a == GameAction.action || a == GameAction.pause;
    switch (_phase) {
      case _Phase.intro:
        if (go) _start();
      case _Phase.results:
        if (go) widget.onExit();
      case _Phase.play:
        if (_paused) {
          if (go) _togglePause();
          return;
        }
        if (_result != null) {
          if (go) _next();
          return;
        }
        if (a == GameAction.left || a == GameAction.right) {
          setState(() {
            _keyed = true;
            _cursor = a == GameAction.left ? 0 : 1;
          });
        } else if (go) {
          final c = _cursor;
          if (_keyed && c != null) _pick(c == 0);
        } else if (a == GameAction.pick1) {
          _pick(true);
        } else if (a == GameAction.pick2) {
          _pick(false);
        } else if (a == GameAction.question && _reader != null) {
          _read();
        }
    }
  }

  void _key(bool saysTrue) {
    if (!_canPick) return;
    setState(() {
      _keyed = true;
      _cursor = saysTrue ? 0 : 1;
    });
    _pick(saysTrue);
  }

  Future<void> _showHow() async {
    if (_paused) return;
    final timerRunning = _timer.isAnimating;
    if (timerRunning) _timer.stop();
    await showDialog<void>(
      context: context,
      builder: (_) => const _HowToDialog(),
    );
    if (mounted && timerRunning && _canPick && !_paused) _timer.forward();
  }

  String _keyName(GameAction a) => keyLabel(
    GameKeysScope.of(context).primaryOf(KeySlot(a, a.shared ? 0 : 1)),
  );

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
    final showHints = keyHintsFit(context);
    return Scaffold(
      key: GameIds.mgScreen(_g),
      body: SafeArea(
        child: GameKeyboard(
          onInput: _onInput,
          shortcuts: {
            LogicalKeyboardKey.keyL: widget.onExit,
            LogicalKeyboardKey.keyP: _togglePause,
            LogicalKeyboardKey.keyH: _showHow,
            LogicalKeyboardKey.keyT: () => _key(true),
            LogicalKeyboardKey.keyF: () => _key(false),
          },
          child: GameFrame(
            showAds: _phase != _Phase.play,
            phoneBanner: null,
            child: Column(
              children: [
                // No title bar (owner, 2026-11-21): the host shows the name. Exit, read aloud and
                // pause are small overlays on the play area.
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
                          resumeKeyName: 'P / Esc / Space',
                        ),
                    ],
                  ),
                ),
                if (showHints) _hints(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

  Widget _overlayButtons(BuildContext context) {
    final playing = _phase == _Phase.play;
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
                          'Read the ticket aloud (${_keyName(GameAction.question)})',
                      icon: const Icon(Icons.volume_up),
                      onPressed: _read,
                    ),
                  ),
                if (playing && _result == null) ...[
                  const SizedBox(width: 6),
                  _withKey(
                    'P',
                    IconButton.filledTonal(
                      key: GameIds.mgPause(_g),
                      style: style,
                      tooltip: _paused ? 'Resume (P)' : 'Pause (P)',
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

  Widget _hints(BuildContext context) {
    final List<GameAction> actions;
    final List<(String, String)> extra;
    final words = <GameAction, String>{};
    if (_phase == _Phase.play && _result == null) {
      actions = const [GameAction.left, GameAction.action];
      words[GameAction.left] = 'choose';
      words[GameAction.action] = 'judge';
      extra = [
        ('T / 1', 'true'),
        ('F / 2', 'false'),
        ('P', 'pause'),
        ('H', 'how to play'),
        ('L', 'leave'),
      ];
    } else if (_phase == _Phase.play) {
      actions = const [GameAction.action];
      words[GameAction.action] = 'next';
      extra = const [('Esc', 'leave')];
    } else {
      actions = const [GameAction.action];
      words[GameAction.action] = _phase == _Phase.intro ? 'start' : 'done';
      extra = [
        if (_phase == _Phase.intro) ('H', 'how to play'),
        ('Esc', 'leave'),
      ];
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KeyHints(
        actions: actions,
        words: words,
        spaceGoesOn: true,
        extra: extra,
      ),
    );
  }

  // ---- intro and results -------------------------------------------------------------

  String _topicLine() {
    if (_s.items.isEmpty) return '';
    final p = _s.items.first;
    final t = p.topic.replaceAll('_', ' ');
    final nice = t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
    return 'Year ${p.year} · $nice';
  }

  Widget _robot(
    double height, {
    RobotMood mood = RobotMood.wait,
    bool animated = false,
    int lit = 0,
    bool gold = false,
  }) {
    return SizedBox(
      key: JudgeBotIds.robot(_g),
      height: height,
      width: height * 1.25,
      child: Semantics(
        container: true,
        image: true,
        label: robotLabel(mood),
        child: ExcludeSemantics(
          child: animated
              ? AnimatedBuilder(
                  animation: Listenable.merge([_timer, _verdict, _cheer]),
                  builder: (_, _) => CustomPaint(painter: _painter(mood)),
                )
              : CustomPaint(
                  painter: JudgeRobotPainter(mood: mood, lit: lit, gold: gold),
                ),
        ),
      ),
    );
  }

  JudgeRobotPainter _painter(RobotMood mood) {
    final b = bulbsFor(_streak);
    final r = _result;
    Color? lamp;
    if (r != null) {
      lamp = _timedOut
          ? judgeAmber
          : (r.correct ? judgeTrueGreen : judgeFalseRed);
    }
    final v = _verdict.value;
    final g = r == null ? 0.0 : sin(pi * (v.clamp(0.0, 0.5) / 0.5));
    final c = _cheer.value;
    return JudgeRobotPainter(
      mood: mood,
      eyeLeft: _cfg.timed && r == null ? 1 - _timer.value : null,
      lit: b.lit,
      gold: b.gold,
      lamp: lamp,
      gavel: g,
      cheer: c,
      confetti: _streak > 0 && _streak % judgeBulbs == 0,
      spin: _streak > 0 && _streak % 10 == 0 ? c : 0,
    );
  }

  RobotMood get _mood {
    final r = _result;
    if (r == null) return _cfg.timed ? RobotMood.think : RobotMood.wait;
    if (_timedOut) return RobotMood.buzz;
    return r.correct ? RobotMood.happy : RobotMood.oops;
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
              padding: EdgeInsets.fromLTRB(24, short ? 8 : 48, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _robot(short ? 90 : 150),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: judgeTicket,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: judgeInk, width: 3),
                    ),
                    child: Text(
                      judgeBotHowTo,
                      key: JudgeBotIds.introHeading(_g),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: judgeInk,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      _MiniLamp('TRUE', 'T', judgeTrueGreen, Icons.check),
                      _MiniLamp('FALSE', 'F', judgeFalseRed, Icons.close),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_topicLine(), style: theme.textTheme.bodyMedium),
                  SizedBox(height: short ? 8 : 16),
                  FilledButton(
                    key: GameIds.mgStart(_g),
                    onPressed: _start,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(240, 64),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: KeyedText(
                      'Start',
                      GameAction.action,
                      alsoSpace: true,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    key: JudgeBotIds.howToButton(_g),
                    onPressed: _showHow,
                    child: const Text('How to play (H)'),
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
    final review = _missed.take(judgeMaxReview).toList();
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              key: GameIds.mgResults(_g),
              padding: EdgeInsets.fromLTRB(24, short ? 8 : 48, 24, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: _robot(short ? 70 : 120, mood: RobotMood.happy),
                    ),
                    const SizedBox(height: 6),
                    Semantics(
                      container: true,
                      label:
                          'Case closed. ${r.correct} of ${r.answered} judged right. Score $_score. Best streak $_best.',
                      child: ExcludeSemantics(
                        child: Column(
                          children: [
                            Transform.rotate(
                              angle: -0.06,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: judgeFalseRed,
                                    width: 4,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'CASE CLOSED',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        color: judgeFalseRed,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${r.correct} of ${r.answered} judged right',
                              key: JudgeBotIds.judgedRight(_g),
                              style: theme.textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Score $_score',
                      key: GameIds.mgScore(_g),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'Best streak $_best in a row',
                      key: JudgeBotIds.bestStreak(_g),
                      textAlign: TextAlign.center,
                    ),
                    if (_s.rewardsConfig.starsEnabled)
                      Text(
                        '${r.stars} stars earned',
                        key: GameIds.mgStars(_g),
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                    if (review.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Review these', style: theme.textTheme.titleMedium),
                      Column(
                        key: JudgeBotIds.reviewList(_g),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < review.length; i++)
                            _reviewCard(theme, i, review[i].claim),
                        ],
                      ),
                    ],
                    SizedBox(height: short ? 12 : 20),
                    Center(
                      child: FilledButton(
                        key: GameIds.mgDone(_g),
                        onPressed: widget.onExit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(220, 56),
                        ),
                        child: KeyedText(
                          'Done',
                          GameAction.action,
                          alsoSpace: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _banner(GameBannerSlot.postGame),
      ],
    );
  }

  Widget _reviewCard(ThemeData theme, int i, Claim c) {
    return Container(
      key: JudgeBotIds.review(_g, i),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: judgeTicket,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: judgeInk, width: 2),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: judgeInk),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (c.derived)
              Text(c.question, style: const TextStyle(fontSize: 13)),
            Text(
              c.shown,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            Text(c.derived ? c.feedback : 'Right verdict: ${c.verdict}.'),
            if (c.explanation.isNotEmpty) Text(c.explanation),
          ],
        ),
      ),
    );
  }

  // ---- play ----------------------------------------------------------------------------

  Widget _play(BuildContext context) {
    final claim = _claim;
    if (claim == null) return const SizedBox.shrink();
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        final strip = scale > 1.2 ? 56.0 : 44.0;
        final landscape = h < 460 && w > h * 1.3;
        final rw = min(380.0, w * 0.46);
        final colW = landscape ? rw : w;
        final stacked = colW < 300 || scale > 1.3;
        final lampH = landscape ? 72.0 : (h * 0.12).clamp(72.0, 104.0);
        final lampsH = stacked ? lampH * 2 + 8 : lampH;
        final Widget body;
        if (landscape) {
          body = Row(
            children: [
              Expanded(child: _art(claim, scale)),
              SizedBox(
                width: rw,
                child: Column(
                  children: [
                    Expanded(child: _feedback(claim)),
                    const SizedBox(height: 6),
                    SizedBox(height: lampsH, child: _lamps(stacked)),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          );
        } else {
          body = Column(
            children: [
              Expanded(child: _art(claim, scale)),
              const SizedBox(height: 6),
              SizedBox(
                height: h < 600 ? 92 : (h < 760 ? 112 : 150),
                child: _feedback(claim),
              ),
              const SizedBox(height: 6),
              SizedBox(height: lampsH, child: _lamps(stacked)),
              const SizedBox(height: 8),
            ],
          );
        }
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  SizedBox(height: strip, child: _hud(Theme.of(context))),
                  Expanded(child: body),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _hud(ThemeData theme) {
    final speak = _reader != null;
    final b = bulbsFor(_streak);
    final limit = _cfg.secondsPerQuestion;
    return Padding(
      padding: EdgeInsets.only(left: 52, right: speak ? 104 : 52),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ticket ${_ticket + 1} of ${_s.total}',
                    key: GameIds.mgProgress(_g),
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Streak $_streak',
                    key: JudgeBotIds.streak(_g),
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(width: 6),
                  for (var i = 0; i < judgeBulbs; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: Container(
                        key: JudgeBotIds.bulb(_g, i),
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < b.lit
                              ? (b.gold ? const Color(0xFFFFC21A) : judgeAmber)
                              : theme.colorScheme.outlineVariant,
                          border: Border.all(color: judgeInk, width: 1),
                        ),
                      ),
                    ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Score $_score',
                    key: GameIds.mgScore(_g),
                    style: theme.textTheme.labelLarge,
                  ),
                  if (_cfg.timed) ...[
                    const SizedBox(width: 12),
                    AnimatedBuilder(
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
                    ),
                  ],
                ],
              ),
              if (_cfg.timed)
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

  /// The robot above the ticket; the ticket keeps the question it was dealt until Next (B-15).
  Widget _art(Claim claim, double scale) {
    return LayoutBuilder(
      builder: (context, box) {
        final ah = box.maxHeight;
        final younger = !widget.level.older;
        final ticketH = (ah * 0.36).clamp(104.0, 200.0);
        final robotH = ah - ticketH - 8;
        return Column(
          children: [
            if (robotH >= 40)
              SizedBox(
                height: robotH,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: _robot(150, mood: _mood, animated: true),
                  ),
                ),
              )
            else
              const Spacer(),
            const SizedBox(height: 8),
            SizedBox(
              height: min(ticketH, ah),
              child: SlideTransition(
                position: Tween(begin: const Offset(0, -0.25), end: Offset.zero)
                    .animate(
                      CurvedAnimation(parent: _slide, curve: Curves.easeOut),
                    ),
                child: FadeTransition(
                  alwaysIncludeSemantics: true,
                  opacity: _slide,
                  child: _ticketCard(claim, younger),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _ticketCard(Claim claim, bool younger) {
    final r = _result;
    final stampOn = r != null;
    return Semantics(
      container: true,
      label: _ticketText,
      excludeSemantics: true,
      child: Container(
        key: JudgeBotIds.ticket(_g),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 6, 10, 10),
        decoration: BoxDecoration(
          color: judgeTicket,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: judgeInk, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 0,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(
              height: 38,
              child: Row(
                children: [
                  Expanded(
                    child: claim.derived
                        ? Text(
                            claim.question,
                            key: JudgeBotIds.ticketQuestion(_g),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF55536F),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  if (stampOn)
                    AnimatedBuilder(
                      animation: _verdict,
                      builder: (_, _) => Transform.scale(
                        scale:
                            0.6 +
                            0.4 *
                                Curves.easeOutBack.transform(
                                  _verdict.value.clamp(0.0, 1.0),
                                ),
                        child: _stamp(claim),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _FitText(
                claim.shown,
                key: GameIds.mgPrompt(_g),
                maxSize: younger ? 32 : 28,
                minSize: younger ? 28 : 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stamp(Claim claim) {
    final c = claim.isTrue ? judgeTrueGreen : judgeFalseRed;
    return Transform.rotate(
      angle: -0.12,
      child: Container(
        key: JudgeBotIds.stamp(_g),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: c, width: 3),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(claim.isTrue ? Icons.check : Icons.close, color: c, size: 20),
            const SizedBox(width: 4),
            Text(
              claim.verdict,
              style: TextStyle(
                color: c,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feedback(Claim claim) {
    final theme = Theme.of(context);
    final r = _result;
    if (r == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            _keyed
                ? 'Judge it: press Enter or Space on the lamp, or T or F.'
                : 'Is it TRUE or FALSE? Press T or F, or tap a lamp.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }
    final ok = r.correct;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            liveRegion: true,
            container: true,
            label: _feedbackText(claim),
            child: ExcludeSemantics(
              child: SingleChildScrollView(
                key: GameIds.mgFeedback(_g),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Icon(
                          ok ? Icons.check_circle : Icons.info_outline,
                          size: 20,
                        ),
                        Text(_headline(), style: theme.textTheme.titleMedium),
                        if (_fast)
                          Chip(
                            key: JudgeBotIds.fast(_g),
                            avatar: const Icon(Icons.bolt, size: 16),
                            label: Text('Fast +$judgeFastBonus'),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    Text(claim.feedback),
                    if (r.explanation.isNotEmpty) Text(r.explanation),
                    if (r.stars > 0)
                      Text('+${r.stars} ${r.stars == 1 ? 'star' : 'stars'}'),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 150,
          child: FilledButton(
            key: GameIds.mgNext(_g),
            onPressed: _next,
            style: FilledButton.styleFrom(
              minimumSize: const Size(150, 56),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: KeyedText(
              _s.finished ? 'See results' : 'Next',
              GameAction.action,
              alsoSpace: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _lamps(bool stacked) {
    final answered = _result != null;
    final claim = _claim!;
    Widget lamp(bool isTrueLamp) => _Lamp(
      key: isTrueLamp ? JudgeBotIds.lampTrue(_g) : JudgeBotIds.lampFalse(_g),
      label: isTrueLamp ? 'TRUE' : 'FALSE',
      keyCap: isTrueLamp ? 'T' : 'F',
      icon: isTrueLamp ? Icons.check : Icons.close,
      color: isTrueLamp ? judgeTrueGreen : judgeFalseRed,
      enabled: !answered && !_paused,
      rightOne: answered && claim.isTrue == isTrueLamp,
      locked: answered,
      cursor: _keyed && !answered && _cursor == (isTrueLamp ? 0 : 1),
      semantics: !answered
          ? '${isTrueLamp ? 'True' : 'False'}, key ${isTrueLamp ? 'T' : 'F'}'
          : (claim.isTrue == isTrueLamp
                ? '${isTrueLamp ? 'True' : 'False'}, the right answer'
                : '${isTrueLamp ? 'True' : 'False'}, not this one'),
      onTap: () => _pick(isTrueLamp),
    );
    if (stacked) {
      return Column(
        children: [
          Expanded(child: lamp(true)),
          const SizedBox(height: 8),
          Expanded(child: lamp(false)),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: lamp(true)),
        const SizedBox(width: 12),
        Expanded(child: lamp(false)),
      ],
    );
  }
}

/// One of the two big lamp buttons, with its key cap in the corner.
class _Lamp extends StatefulWidget {
  const _Lamp({
    super.key,
    required this.label,
    required this.keyCap,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.rightOne,
    required this.locked,
    required this.cursor,
    required this.semantics,
    required this.onTap,
  });
  final String label, keyCap, semantics;
  final IconData icon;
  final Color color;
  final bool enabled, rightOne, locked, cursor;
  final VoidCallback onTap;

  @override
  State<_Lamp> createState() => _LampState();
}

class _LampState extends State<_Lamp> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final dim = widget.locked && !widget.rightOne;
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Semantics(
        button: true,
        excludeSemantics: true,
        enabled: widget.enabled,
        label: widget.semantics,
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          transform: Matrix4.translationValues(
            0,
            _hover && widget.enabled ? -2 : 0,
            0,
          ),
          constraints: const BoxConstraints(minHeight: 72, minWidth: 140),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: dim ? 0.4 : 1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.cursor
                  ? cs.tertiary
                  : (widget.rightOne ? Colors.white : judgeInk),
              width: widget.cursor || widget.rightOne ? 5 : 3,
            ),
            boxShadow: widget.rightOne
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.6),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ]
                : const [
                    BoxShadow(color: Color(0x33000000), offset: Offset(0, 3)),
                  ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.enabled ? widget.onTap : null,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(widget.icon, color: Colors.white, size: 30),
                          const SizedBox(width: 8),
                          Text(
                            widget.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: judgeInk, width: 1.5),
                    ),
                    child: Text(
                      widget.keyCap,
                      style: const TextStyle(
                        color: judgeInk,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small, inert picture of a lamp for the start screen.
class _MiniLamp extends StatelessWidget {
  const _MiniLamp(this.label, this.keyCap, this.color, this.icon);
  final String label, keyCap;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: judgeInk, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 4),
          Text(
            '$label ($keyCap)',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

/// The claim text: as big as fits between [maxSize] and [minSize], then it scrolls inside the ticket.
class _FitText extends StatelessWidget {
  const _FitText(
    this.text, {
    super.key,
    required this.maxSize,
    required this.minSize,
  });
  final String text;
  final double maxSize, minSize;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        TextStyle style(double s) => TextStyle(
          fontSize: s,
          fontWeight: FontWeight.w800,
          color: judgeInk,
          height: 1.2,
        );
        var size = maxSize;
        var fits = false;
        while (true) {
          final tp = TextPainter(
            text: TextSpan(text: text, style: style(size)),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
          )..layout(maxWidth: box.maxWidth);
          if (tp.height <= box.maxHeight) {
            fits = true;
            break;
          }
          if (size <= minSize) break;
          size = max(minSize, size - 2);
        }
        final t = Text(text, style: style(size), textAlign: TextAlign.center);
        return Semantics(
          header: true,
          child: fits
              ? Center(child: t)
              : SingleChildScrollView(child: Center(child: t)),
        );
      },
    );
  }
}

class _HowToDialog extends StatelessWidget {
  const _HowToDialog();

  @override
  Widget build(BuildContext context) {
    final how = HowToPlayCatalogue.forGame(judgeBotId);
    void close() => Navigator.of(context).pop();
    return Focus(
      autofocus: true,
      onKeyEvent: (_, e) {
        if (e is! KeyDownEvent) return KeyEventResult.ignored;
        final k = e.logicalKey;
        if (k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.space ||
            k == LogicalKeyboardKey.escape) {
          close();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AlertDialog(
        key: JudgeBotIds.howTo(judgeBotId),
        title: const Text('How to play Judge bot'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in how?.rules ?? const <String>[]) Text('• $r'),
              const SizedBox(height: 8),
              for (final t in how?.tips ?? const <String>[]) Text('Tip: $t'),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: JudgeBotIds.howToClose(judgeBotId),
            onPressed: close,
            child: const Text('Close (Enter / Space / Esc)'),
          ),
        ],
      ),
    );
  }
}
