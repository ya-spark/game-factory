import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/profile/child_profile.dart';
import '../../core/services.dart';
import '../../engine/engine.dart';
import '../game_registry.dart';
import '../kit/ds_art.dart';
import '../tabs/tab_data.dart';
import '../test_ids.dart';
import 'choice_game.dart';
import 'tug_of_war_screen.dart';

/// Questions loaded for each player; the game ends early if one player runs out.
const int _familyQuestions = 24;

/// The years the game is offered for in this app (Scout: Year 3 and above).
({int min, int max}) _tugYears() {
  for (final e in appGames.entries) {
    if (e.game.id == tugOfWarId) return (min: e.minYear, max: e.maxYear);
  }
  return (min: 0, max: 12);
}

/// Children who may play family Tug of war.
List<ChildProfile> familyTugEligible(List<ChildProfile> children) {
  final y = _tugYears();
  return [
    for (final c in children)
      if (familyTugEligibleYear(c.year, minYear: y.min, maxYear: y.max)) c,
  ];
}

/// The "Play with a sibling" button for the Tug of war start screen. Null (no button) when the
/// flag is off or fewer than two profiles on the device are eligible, or when the active child
/// is not one of them.
Widget? familyTugButton(BuildContext context, {bool harder = false}) {
  final services = context
      .dependOnInheritedWidgetOfExactType<ServicesScope>()
      ?.services;
  if (services == null || !services.config.familyMode.enabled) return null;
  final me = services.profile.activeChild;
  if (me == null) return null;
  final eligible = familyTugEligible(services.profile.children);
  if (eligible.length < 2 || !eligible.any((c) => c.id == me.id)) return null;
  return OutlinedButton(
    key: TestIds.familyStart,
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FamilyTugSetupScreen(me: me, harder: harder),
      ),
    ),
    child: const Text('Play with a sibling'),
  );
}

/// Picks the second player and the subject, then starts the game.
class FamilyTugSetupScreen extends StatefulWidget {
  const FamilyTugSetupScreen({
    super.key,
    required this.me,
    this.harder = false,
    this.loaders,
    this.random,
  });
  final ChildProfile me;
  final bool harder;
  final TabLoaders? loaders;
  final Random? random;

  @override
  State<FamilyTugSetupScreen> createState() => _FamilyTugSetupState();
}

class _FamilyTugSetupState extends State<FamilyTugSetupScreen> {
  ChildProfile? _partner;
  String? _subject;
  List<PoolItem> _mine = const [];
  List<PoolItem> _theirs = const [];
  bool _loading = false;

  TabLoaders get _loaders => widget.loaders ?? TabLoaders.of(context);

  List<String> get _subjects {
    final p = _partner;
    if (p == null) return const [];
    Set<String> with4(List<PoolItem> open, int? year) {
      final n = <String, int>{};
      for (final i in open) {
        if (i.year == year && i.item.type == ItemType.mcq) {
          n[i.subject] = (n[i.subject] ?? 0) + 1;
        }
      }
      return {
        for (final e in n.entries)
          if (e.value >= tugOfWarMinPool) e.key,
      };
    }

    return (with4(
      _mine,
      widget.me.year,
    ).intersection(with4(_theirs, p.year)).toList()..sort());
  }

  Future<void> _pick(ChildProfile c) async {
    setState(() {
      _partner = c;
      _subject = null;
      _loading = true;
    });
    final l = _loaders;
    final mine = await l.openItems(widget.me.id);
    final theirs = await l.openItems(c.id);
    if (!mounted) return;
    setState(() {
      _mine = mine;
      _theirs = theirs;
      _loading = false;
      final s = _subjects;
      if (s.length == 1) _subject = s.first;
    });
  }

  Future<void> _begin() async {
    final services = ServicesScope.of(context);
    final nav = Navigator.of(context);
    final subject = _subject;
    final partner = _partner;
    if (subject == null || partner == null) return;
    final packs = await _loaders.packs();
    final random = widget.random ?? Random();
    final players = [widget.me, partner];
    final open = [_mine, _theirs];
    final sessions = <QuizSession>[];
    for (var i = 0; i < 2; i++) {
      final cur = services.profile.children.firstWhere(
        (c) => c.id == players[i].id,
      );
      final s = QuizSession.start(
        open: open[i],
        progress: cur.progress,
        packs: packs,
        rewardsConfig: services.rewardsFor(cur),
        subject: subject,
        year: cur.year ?? 0,
        today: services.profile.today,
        random: random,
        types: const {ItemType.mcq},
        count: _familyQuestions,
        minPool: tugOfWarMinPool,
        streakDays: services.profile.displayStreak,
        gameId: tugOfWarId,
      );
      if (s == null) return;
      sessions.add(s);
    }
    final level = familyTugLevel([
      for (final s in sessions) levelForSession(s),
    ], harder: widget.harder);
    await services.profile.holdPlay();
    if (!nav.mounted) return;
    await nav.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => FamilyTugScreen(
          players: [for (final p in players) FamilyPlayer.of(p)],
          sessions: sessions,
          level: level,
          random: random,
          onAnswered: (i, r, s) async {
            await services.profile.setChildProgress(players[i].id, s.progress);
            if (r.coins > 0) await services.profile.addCoins(r.coins);
          },
          onPlayed: (i, seconds) =>
              services.profile.creditPlay(players[i].id, seconds),
          onExit: () {
            services.profile.releasePlay();
            nav.pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = ServicesScope.of(context);
    final theme = Theme.of(context);
    final others = [
      for (final c in familyTugEligible(services.profile.children))
        if (c.id != widget.me.id) c,
    ];
    final subjects = _subjects;
    return Scaffold(
      key: TestIds.familySetup,
      appBar: AppBar(title: const Text('Play with a sibling')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Who is playing with ${widget.me.nickname}?',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final c in others)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ChoiceChip(
                    key: TestIds.familyPartner(c.id),
                    avatar: DsAvatarArt(c.avatar, size: 24),
                    label: Text(c.nickname),
                    selected: _partner?.id == c.id,
                    onSelected: (_) => _pick(c),
                  ),
                ),
              if (_loading) const LinearProgressIndicator(),
              if (_partner != null && !_loading) ...[
                const SizedBox(height: 16),
                if (subjects.isEmpty)
                  Text(
                    'There are not enough questions open for both of you yet. '
                    'Keep learning and try again soon.',
                    style: theme.textTheme.bodyLarge,
                  )
                else ...[
                  Text('Pick a subject', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final s in subjects)
                        ChoiceChip(
                          key: TestIds.familySubject(s),
                          label: Text(tidyTopicId(s)),
                          selected: _subject == s,
                          onSelected: (_) => setState(() => _subject = s),
                        ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 24),
              FilledButton(
                key: TestIds.familyBegin,
                onPressed: _subject == null ? null : _begin,
                child: const Text('Start'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Minimum open `mcq` items of a subject and year for a player.
const int tugOfWarMinPool = 4;

class FamilyPlayer {
  const FamilyPlayer(this.id, this.nickname, this.avatar);
  factory FamilyPlayer.of(ChildProfile c) =>
      FamilyPlayer(c.id, c.nickname, c.avatar);
  final String id;
  final String nickname;
  final String avatar;
}

enum _Phase { question, feedback, pass, result }

/// The game itself: two players, one device. Each turn asks the player one question from their
/// own session; between turns a pass screen hides the next question.
class FamilyTugScreen extends StatefulWidget {
  const FamilyTugScreen({
    super.key,
    required this.players,
    required this.sessions,
    required this.level,
    required this.onExit,
    this.onAnswered,
    this.onPlayed,
    this.random,
    this.clock,
  });
  final List<FamilyPlayer> players;
  final List<QuizSession> sessions;
  final MiniGameLevel level;
  final VoidCallback onExit;

  /// Called for every answer with the player's index (record it to that child).
  final Future<void> Function(int player, AnswerResult, QuizSession)?
  onAnswered;

  /// Seconds the player's turn took (credit it to that child).
  final void Function(int player, int seconds)? onPlayed;
  final Random? random;
  final DateTime Function()? clock;

  @override
  State<FamilyTugScreen> createState() => _FamilyTugScreenState();
}

class _FamilyTugScreenState extends State<FamilyTugScreen> {
  late final FamilyTugRun _run = FamilyTugRun(widget.level);
  late final Random _random = widget.random ?? Random();
  _Phase _phase = _Phase.question;
  List<TugOption>? _options;
  final Set<int> _disabled = {};
  int _wrongTries = 0;
  bool _timedOut = false;
  int _left = 0;
  Timer? _timer;
  DateTime? _turnStart;
  int _answerer = 0;
  String _feedback = '';

  DateTime _now() => (widget.clock ?? DateTime.now)();
  FamilyPlayer get _who => widget.players[_run.turn];
  QuizSession get _session => widget.sessions[_run.turn];
  bool get _timed => _run.settings.secondsPerQuestion > 0;

  @override
  void initState() {
    super.initState();
    _beginTurn();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _beginTurn() {
    final item = _session.current;
    final options = item == null
        ? null
        : layoutTugOptions(item.item, _run.settings.options, _random);
    if (options == null) {
      _phase = _Phase.result;
      return;
    }
    _options = options;
    _phase = _Phase.question;
    _disabled.clear();
    _wrongTries = 0;
    _timedOut = false;
    _turnStart = _now();
    _timer?.cancel();
    if (_timed) {
      _left = _run.settings.secondsPerQuestion;
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        if (_left <= 1) {
          t.cancel();
          _timedOut = true;
          _finish(correct: false);
        } else {
          setState(() => _left--);
        }
      });
    }
  }

  void _pick(int i) {
    if (_phase != _Phase.question) return;
    if (_options![i].correct) {
      _finish(correct: true);
    } else if (!widget.level.older) {
      // Gentle rules: no failing. The wrong pick is greyed out and the player tries again.
      setState(() {
        _disabled.add(i);
        _wrongTries++;
      });
    } else {
      _finish(correct: false);
    }
  }

  Future<void> _finish({required bool correct}) async {
    _timer?.cancel();
    final player = _run.turn;
    final started = _turnStart;
    if (started != null) {
      widget.onPlayed?.call(player, _now().difference(started).inSeconds);
    }
    final session = widget.sessions[player];
    final r = session.answer(correct: correct && _wrongTries == 0);
    final name = widget.players[player].nickname;
    // Gentle rules: the rope only ever moves toward the player who just answered.
    final end = _run.answer(correct: widget.level.older ? correct : true);
    setState(() {
      _answerer = player;
      _phase = _Phase.feedback;
      _feedback = _run.isOver
          ? 'That was the last pull!'
          : end == FamilyTugEnd.round
          ? '${widget.players[_run.lastRoundWinner!].nickname} took that round!'
          : correct
          ? 'Nice pull, $name!'
          : _timedOut
          ? 'Time is up, $name. Good try!'
          : 'Good try, $name!';
    });
    await widget.onAnswered?.call(player, r, session);
  }

  void _next() {
    if (_run.isOver || widget.sessions[_run.turn].finished) {
      setState(() => _phase = _Phase.result);
      return;
    }
    setState(() => _phase = _Phase.pass);
  }

  void _ready() => setState(_beginTurn);

  void _exit() {
    _timer?.cancel();
    final started = _turnStart;
    if (_phase == _Phase.question && started != null) {
      widget.onPlayed?.call(_run.turn, _now().difference(started).inSeconds);
    }
    widget.onExit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: TestIds.mgScreen('family_tug'),
      appBar: AppBar(
        title: const Text('Tug of war'),
        leading: IconButton(
          key: TestIds.familyExit,
          tooltip: 'Leave Tug of war',
          icon: const Icon(Icons.close),
          onPressed: _exit,
        ),
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.pass => _pass(context),
          _Phase.result => _result(context),
          _ => _play(context),
        },
      ),
    );
  }

  Widget _avatar(FamilyPlayer p, double size) =>
      DsAvatarArt(p.avatar, size: size);

  Widget _pass(BuildContext context) {
    final theme = Theme.of(context);
    final who = _who;
    return Center(
      child: SingleChildScrollView(
        key: TestIds.familyPass,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _avatar(who, 96),
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                'Pass to ${who.nickname}',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: TestIds.familyReady,
              style: FilledButton.styleFrom(
                minimumSize: const Size(220, 64),
                textStyle: theme.textTheme.titleLarge,
              ),
              onPressed: _ready,
              child: const Text("I'm ready"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rope(BuildContext context) {
    final pal = MiniGamePalette(context);
    final a = widget.players[0].nickname;
    final b = widget.players[1].nickname;
    final reach = _run.settings.reach;
    final p = _run.position;
    final where = p == 0
        ? 'in the middle'
        : p > 0
        ? '$p of $reach steps toward $a'
        : '${-p} of $reach steps toward $b';
    return Column(
      children: [
        Semantics(
          container: true,
          label:
              'Rope $where. Rounds: $a ${_run.roundsOf(0)}, $b ${_run.roundsOf(1)}.',
          child: ExcludeSemantics(
            child: SizedBox(
              key: TestIds.mgRope('family_tug'),
              height: 64,
              width: double.infinity,
              child: CustomPaint(
                painter: TugRopePainter(
                  position: p,
                  reach: reach,
                  me: pal.primary,
                  them: pal.accent,
                  rope: pal.text,
                  marker: pal.success,
                  edge: pal.border,
                ),
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text('$b: ${_run.roundsOf(1)}')),
            Flexible(
              child: Text('$a: ${_run.roundsOf(0)}', textAlign: TextAlign.end),
            ),
          ],
        ),
      ],
    );
  }

  Widget _play(BuildContext context) {
    final theme = Theme.of(context);
    final pal = MiniGamePalette(context);
    final feedback = _phase == _Phase.feedback;
    final who = widget.players[feedback ? _answerer : _run.turn];
    final item = feedback ? null : _session.current;
    final options = _options!;
    return SingleChildScrollView(
      key: TestIds.mgField('family_tug'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Row(
              key: TestIds.familyTurn,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _avatar(who, 32),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    feedback ? who.nickname : "${who.nickname}'s turn",
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _rope(context),
          if (_timed && !feedback)
            Text(
              key: TestIds.mgTimer('family_tug'),
              '$_left seconds',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge,
            ),
          const SizedBox(height: 8),
          if (item != null)
            Text(
              item.item.json['prompt'] as String,
              key: TestIds.mgPrompt('family_tug'),
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          if (feedback)
            Semantics(
              liveRegion: true,
              child: Text(
                _feedback,
                key: TestIds.familyFeedback,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 12),
          for (var i = 0; i < options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                button: true,
                excludeSemantics: true,
                enabled: !feedback && !_disabled.contains(i),
                label: _disabled.contains(i)
                    ? '${options[i].label}, not this one'
                    : (feedback && options[i].correct)
                    ? '${options[i].label}, the right answer'
                    : options[i].label,
                child: FilledButton(
                  key: TestIds.familyChoice(i),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: _disabled.contains(i)
                        ? pal.surface
                        : (feedback && options[i].correct)
                        ? pal.success
                        : pal.primary,
                    foregroundColor: _disabled.contains(i)
                        ? pal.text.withValues(alpha: 0.7)
                        : (feedback && options[i].correct)
                        ? pal.bg
                        : pal.onPrimary,
                  ),
                  onPressed: feedback || _disabled.contains(i)
                      ? null
                      : () => _pick(i),
                  child: Text(options[i].label, textAlign: TextAlign.center),
                ),
              ),
            ),
          if (feedback) ...[
            const SizedBox(height: 8),
            FilledButton(
              key: TestIds.familyNext,
              onPressed: _next,
              child: Text(
                _run.isOver || widget.sessions[_run.turn].finished
                    ? 'See the result'
                    : 'Next',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _result(BuildContext context) {
    final theme = Theme.of(context);
    final w = _run.winner;
    final a = widget.players[0];
    final b = widget.players[1];
    final line = w != null
        ? '${widget.players[w].nickname} pulled it home, '
              '${_run.roundsOf(w)} rounds to ${_run.roundsOf(1 - w)}.'
        : 'All square: ${_run.roundsOf(0)} rounds each.';
    return Center(
      child: SingleChildScrollView(
        key: TestIds.familyResult,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _avatar(a, 48),
                const SizedBox(width: 16),
                _avatar(b, 48),
              ],
            ),
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                'Great game, both of you!',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              line,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: TestIds.familyDone,
              onPressed: _exit,
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
