import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:game_core/game_core.dart';

import 'memory_match_ids.dart';

import 'memory_match_two_player.dart';
import 'rules/memory_match_rules.dart';

/// Memory match as a registry entry: free, both modes, needs 3 open `pairs` items.
final MiniGame memoryMatchGame = MiniGame(
  id: memoryMatchId,
  title: 'Memory match',
  itemTypes: const {ItemType.pairs},
  sizes: SizeAccept.shortOnly,
  minPool: 3,
  build: (ctx) => MemoryMatchScreen(
    session: ctx.session,
    mode: ctx.mode,
    onExit: ctx.onExit,
    onAnswered: ctx.onAnswered,
    // Two players take turns on one board (docs/SPEC.md); not in calm Study mode.
    offerTwoPlayers: ctx.mode == MiniGameMode.game,
  ),
);

/// Flip cards to find the pairs. One `pairs` item is one board. Younger children get a few
/// big cards, no timer and no failing; older children get more cards and a gentle clock.
/// Every card is a labelled button, the page scrolls at large text, and nothing depends on colour.
class MemoryMatchScreen extends StatefulWidget {
  const MemoryMatchScreen({
    super.key,
    required this.session,
    required this.mode,
    required this.onExit,
    this.onAnswered,
    this.level,
    this.hard = false,
    this.random,
    this.reader,
    this.mismatchDelay = const Duration(milliseconds: 900),
    this.offerTwoPlayers = false,
  });

  /// Shows the "2 players" choice above the first board.
  final bool offerTwoPlayers;

  final QuizSession session;
  final MiniGameMode mode;
  final VoidCallback onExit;
  final void Function(AnswerResult result, QuizSession session)? onAnswered;

  /// Null: from the theme's level. [hard] makes the older level harder (Craft Champion).
  final MatchLevel? level;
  final bool hard;
  final Random? random;
  final GameReadAloud? reader;

  /// How long a mismatch stays face up.
  final Duration mismatchDelay;

  @override
  State<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends State<MemoryMatchScreen> {
  late final Random _random = widget.random ?? Random();
  late final SecondsTicker _ticker = SecondsTicker(() {
    if (mounted) setState(() {});
  });
  MemoryMatchBoard? _board;
  int? _boardIndex;
  AnswerResult? _result;
  Timer? _hide;
  GameReadAloud? _reader;
  bool _paused = false;
  bool _twoPlayers = false;
  bool _started = false;

  /// The card the keyboard is on (drawn only once a key has been used).
  int _cursor = 0;
  bool _keyboardUsed = false;
  final Map<int, BuildContext> _cardContexts = {};

  QuizSession get _s => widget.session;
  bool get _study => widget.mode == MiniGameMode.study;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reader = resolveReader(context, widget.reader);
  }

  @override
  void dispose() {
    _hide?.cancel();
    _ticker.stop();
    _reader?.stop();
    super.dispose();
  }

  MatchLevel _level(BuildContext context) =>
      widget.level ??
      (isYoungerLevel(context)
          ? MatchLevel.younger
          : (widget.hard ? MatchLevel.hard : MatchLevel.older));

  MemoryMatchBoard _boardFor(BuildContext context, PoolItem p, int index) {
    if (_boardIndex != index || _board == null) {
      _boardIndex = index;
      final level = _study && _level(context) != MatchLevel.younger
          ? MatchLevel.older
          : _level(context);
      _board = MemoryMatchBoard.fromItem(p.item, level, _random);
      _ticker.reset();
      // Study mode is calm: no clock.
      if (_board!.timeLimit != null && !_study) _ticker.start();
    }
    return _board!;
  }

  void _flip(MemoryMatchBoard b, int i) {
    if (_result != null || _paused) return;
    final o = b.flip(i);
    if (o == FlipOutcome.ignored) return;
    setState(() => _started = true);
    if (o == FlipOutcome.mismatch) {
      _hide?.cancel();
      _hide = Timer(widget.mismatchDelay, () {
        if (!mounted) return;
        setState(b.hideMismatch);
      });
    } else if (b.complete) {
      _ticker.stop();
      final passed = _study ? true : b.passed(elapsedSeconds: _ticker.seconds);
      final r = _s.answer(correct: passed);
      widget.onAnswered?.call(r, _s);
      setState(() => _result = r);
    }
  }

  void _next() => setState(() {
    _result = null;
    _board = null;
    _cursor = 0;
  });

  void _togglePause() {
    final b = _board;
    if (b == null || _result != null || _s.finished) return;
    setState(() => _paused = !_paused);
    if (_paused) {
      _ticker.stop();
    } else if (b.timeLimit != null && !_study) {
      _ticker.start();
    }
  }

  // ---- keyboard (docs/KEYBOARD.md): arrows move over the cards, Enter turns one, Q reads, Space pauses ----

  /// The 1 player / 2 players switch shows before the first card is turned (keys 1 and 2 pick it).
  bool get _toggleShown =>
      widget.offerTwoPlayers &&
      !_study &&
      !_started &&
      _s.index == 0 &&
      _result == null;

  void _onInput(GameInput i) {
    final b = _board;
    if (i.action == GameAction.exit) {
      if (i.repeat) return;
      // Esc pauses a board (the pause screen offers Leave); elsewhere it leaves.
      if (b != null && _result == null && !_s.finished) {
        _togglePause();
      } else {
        widget.onExit();
      }
      return;
    }
    if (_s.finished && _result == null) {
      // Enter or Space (the pause key) leaves from the results.
      if ((i.action == GameAction.action || i.action == GameAction.pause) &&
          !i.repeat) {
        widget.onExit();
      }
      return;
    }
    if (b == null) return;
    if (i.action == GameAction.pause) {
      if (i.repeat) return;
      // Space is Next while a result shows; it never pauses then (U2).
      if (_result != null) {
        _next();
      } else {
        _togglePause();
      }
      return;
    }
    if (_paused) return;
    if (_toggleShown &&
        !i.repeat &&
        (i.action == GameAction.pick1 || i.action == GameAction.pick2)) {
      setState(() {
        _twoPlayers = i.action == GameAction.pick2;
        if (_twoPlayers) _ticker.stop();
      });
      return;
    }
    final cols = b.columns;
    final count = b.cards.length;
    int? to;
    switch (i.action) {
      case GameAction.left:
        to = _cursor % cols == 0 ? _cursor : _cursor - 1;
      case GameAction.right:
        to = _cursor % cols == cols - 1 || _cursor + 1 >= count
            ? _cursor
            : _cursor + 1;
      case GameAction.up:
        to = _cursor - cols >= 0 ? _cursor - cols : _cursor;
      case GameAction.down:
        to = _cursor + cols < count ? _cursor + cols : _cursor;
      case GameAction.action:
        if (i.repeat) return;
        if (_result != null) {
          _next();
        } else {
          setState(() => _keyboardUsed = true);
          _flip(b, _cursor);
        }
      case GameAction.question:
        final item = _s.items[_s.index];
        final prompt =
            (item.item.json['prompt'] as String?) ?? 'Find the pairs.';
        _reader?.read(prompt, audioRef: item.item.audio);
      default:
        break;
    }
    if (to != null) {
      setState(() {
        _keyboardUsed = true;
        _cursor = to!;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _cardContexts[_cursor];
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(ctx, duration: Duration.zero);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_twoPlayers) {
      return MemoryMatchTwoPlayerScreen(
        items: _s.items,
        level: _study ? MatchLevel.older : _level(context),
        random: _random,
        reader: widget.reader,
        mismatchDelay: widget.mismatchDelay,
        onExit: widget.onExit,
      );
    }
    final answered = _result != null;
    final shownIndex = answered ? _s.index - 1 : _s.index;
    final done = _s.finished && !answered;
    final title = _study ? 'Memory match: study' : 'Memory match';
    final wide = WindowClass.ofContext(context) != WindowClass.compact;
    return Scaffold(
      key: MemoryMatchIds.matchScreen,
      body: SafeArea(
        child: GameKeyboard(
          onInput: _onInput,
          // L leaves from anywhere (the Leave buttons show it).
          shortcuts: {LogicalKeyboardKey.keyL: widget.onExit},
          child: GameFrame(
            // No ad beside the cards while a board is being played.
            showAds: done,
            phoneBanner: null,
            child: Column(
              children: [
                // No title bar: exit and pause are small controls over the game (R2).
                GameTopBar(
                  title: title,
                  onExit: widget.onExit,
                  exitKey: MemoryMatchIds.matchExit,
                  onPause: done || answered ? null : _togglePause,
                  pauseKey: MemoryMatchIds.matchPause,
                  paused: _paused,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      done
                          ? MiniGameSummary(
                              summaryKey: MemoryMatchIds.matchSummary,
                              starsKey: MemoryMatchIds.matchStars,
                              doneKey: MemoryMatchIds.matchNext,
                              correct: _s.report.correct,
                              answered: _s.report.answered,
                              stars: _s.report.stars,
                              showStars:
                                  _s.rewardsConfig.starsEnabled && !_study,
                              onDone: widget.onExit,
                            )
                          : _board_(context, _s.items[shownIndex], shownIndex),
                      if (_paused)
                        PauseOverlay(
                          overlayKey: MemoryMatchIds.matchPaused,
                          resumeKey: MemoryMatchIds.matchResume,
                          onResume: _togglePause,
                          onLeave: widget.onExit,
                          leaveKey: MemoryMatchIds.matchLeave,
                        ),
                    ],
                  ),
                ),
                if (wide)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: KeyHints(
                      spaceGoesOn: done || _result != null,
                      actions: [
                        if (!done) ...[
                          GameAction.left,
                          GameAction.right,
                          GameAction.up,
                          GameAction.down,
                        ],
                        GameAction.action,
                        if (!done && _reader != null) GameAction.question,
                        if (!done) GameAction.pause,
                      ],
                      extra: [
                        if (_toggleShown) ('1 / 2', 'players'),
                        ('L', 'leave'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _board_(BuildContext context, PoolItem p, int index) {
    final theme = Theme.of(context);
    final b = _boardFor(context, p, index);
    final prompt = (p.item.json['prompt'] as String?) ?? 'Find the pairs.';
    final limit = b.timeLimit;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Board ${index + 1} of ${_s.total}',
                  key: MemoryMatchIds.matchProgress,
                  style: theme.textTheme.labelLarge,
                ),
              ),
              if (limit != null && !_study)
                Semantics(
                  label:
                      'Time ${clock(_ticker.seconds)} of about ${clock(limit)}',
                  excludeSemantics: true,
                  child: Text(
                    '${clock(_ticker.seconds)} / ${clock(limit)}',
                    key: MemoryMatchIds.matchTimer,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              if (_reader != null)
                KeyedIconButton(
                  key: MemoryMatchIds.matchSpeak,
                  tooltip: 'Read the instructions aloud',
                  icon: Icons.volume_up,
                  keyName: keyNameOf(context, GameAction.question),
                  onPressed: () =>
                      _reader!.read(prompt, audioRef: p.item.audio),
                ),
            ],
          ),
          if (_toggleShown) ...[
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('1 player (1)', key: MemoryMatchIds.matchModeOne),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(
                    '2 players (2)',
                    key: MemoryMatchIds.matchModeTwo,
                  ),
                ),
              ],
              selected: {_twoPlayers},
              onSelectionChanged: (v) => setState(() {
                _twoPlayers = v.first;
                if (_twoPlayers) _ticker.stop();
              }),
            ),
          ],
          const SizedBox(height: 8),
          Semantics(
            header: true,
            child: Text(
              prompt,
              key: MemoryMatchIds.matchPrompt,
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              // Few columns keep cards big; at large text a card grows with its text.
              final cols = b.columns;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: b.cards.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  mainAxisExtent:
                      96 * MediaQuery.textScalerOf(context).scale(1),
                ),
                itemBuilder: (_, i) => _card(theme, b, i),
              );
            },
          ),
          if (_result != null) ..._feedback(theme, b),
        ],
      ),
    );
  }

  Widget _card(ThemeData theme, MemoryMatchBoard b, int i) {
    final up = b.isFaceUp(i);
    final matched = b.matched.contains(i);
    final card = b.cards[i];
    final cs = theme.colorScheme;
    final label = up
        ? (matched ? '${card.text}, matched' : card.text)
        : 'Card ${i + 1}, face down';
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: label,
      onTap: up ? null : () => _flip(b, i),
      child: AnimatedContainer(
        duration: reduceMotionOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: up ? cs.surfaceContainerHighest : cs.primary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _keyboardUsed && i == _cursor
                ? cs.secondary
                : (matched ? cs.tertiary : cs.outline),
            width: (_keyboardUsed && i == _cursor) ? 4 : (matched ? 3 : 1),
          ),
        ),
        child: Builder(
          builder: (cardContext) {
            _cardContexts[i] = cardContext;
            return InkWell(
              key: MemoryMatchIds.matchCard(i),
              borderRadius: BorderRadius.circular(16),
              onTap: up ? null : () => _flip(b, i),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: up
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (matched)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.check_circle, size: 18),
                              ),
                            Flexible(
                              child: Text(
                                card.text,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Icon(Icons.help_outline, color: cs.onPrimary, size: 32),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _feedback(ThemeData theme, MemoryMatchBoard b) {
    final r = _result!;
    return [
      const SizedBox(height: 16),
      Semantics(
        liveRegion: true,
        container: true,
        child: Column(
          key: MemoryMatchIds.matchFeedback,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.correct
                        ? 'All pairs found!'
                        : 'All pairs found. Try again for a star.',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (r.explanation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(r.explanation, style: theme.textTheme.bodyLarge),
            ],
            if (!_study && r.stars > 0) ...[
              const SizedBox(height: 8),
              Text(
                '+${r.stars} ${r.stars == 1 ? 'star' : 'stars'}',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      FilledButton(
        key: MemoryMatchIds.matchNext,
        onPressed: _next,
        child: KeyedText(
          _s.finished ? 'See results' : 'Next',
          GameAction.action,
          alsoSpace: true,
        ),
      ),
    ];
  }
}
