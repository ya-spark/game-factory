import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/speech/speech_service.dart';
import '../../engine/engine.dart';
import '../test_ids.dart';
import 'minigame_parts.dart';

/// Memory match as a registry entry: free, both modes, needs 3 open `pairs` items.
final MiniGame memoryMatchGame = MiniGame(
  id: memoryMatchId,
  title: 'Memory match',
  itemTypes: const {ItemType.pairs},
  minPool: 3,
  build: (ctx) => MemoryMatchScreen(
    session: ctx.session,
    mode: ctx.mode,
    onExit: ctx.onExit,
    onAnswered: ctx.onAnswered,
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
    this.recordedClip,
    this.mismatchDelay = const Duration(milliseconds: 900),
  });

  final QuizSession session;
  final MiniGameMode mode;
  final VoidCallback onExit;
  final void Function(AnswerResult result, QuizSession session)? onAnswered;

  /// Null: from the theme's level. [hard] makes the older level harder (Craft Champion).
  final MatchLevel? level;
  final bool hard;
  final Random? random;
  final ReadAloud? reader;
  final RecordedClipPlayer? recordedClip;

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
  ReadAloud? _reader;

  QuizSession get _s => widget.session;
  bool get _study => widget.mode == MiniGameMode.study;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reader = resolveReader(context, widget.reader, widget.recordedClip);
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
    if (_result != null) return;
    final o = b.flip(i);
    if (o == FlipOutcome.ignored) return;
    setState(() {});
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
  });

  @override
  Widget build(BuildContext context) {
    final answered = _result != null;
    final shownIndex = answered ? _s.index - 1 : _s.index;
    final done = _s.finished && !answered;
    return Scaffold(
      key: TestIds.matchScreen,
      appBar: AppBar(
        title: Text(_study ? 'Memory match: study' : 'Memory match'),
        leading: IconButton(
          key: TestIds.matchExit,
          tooltip: 'Leave the game',
          icon: const Icon(Icons.close),
          onPressed: widget.onExit,
        ),
      ),
      body: SafeArea(
        child: done
            ? MiniGameSummary(
                summaryKey: TestIds.matchSummary,
                starsKey: TestIds.matchStars,
                doneKey: TestIds.matchNext,
                correct: _s.report.correct,
                answered: _s.report.answered,
                stars: _s.report.stars,
                showStars: _s.rewardsConfig.starsEnabled && !_study,
                onDone: widget.onExit,
              )
            : _board_(context, _s.items[shownIndex], shownIndex),
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
                  key: TestIds.matchProgress,
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
                    key: TestIds.matchTimer,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              if (_reader != null)
                IconButton(
                  key: TestIds.matchSpeak,
                  tooltip: 'Read the instructions aloud',
                  icon: const Icon(Icons.volume_up),
                  onPressed: () =>
                      _reader!.read(prompt, audioRef: p.item.audio),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            header: true,
            child: Text(
              prompt,
              key: TestIds.matchPrompt,
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
            color: matched ? cs.tertiary : cs.outline,
            width: matched ? 3 : 1,
          ),
        ),
        child: InkWell(
          key: TestIds.matchCard(i),
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
          key: TestIds.matchFeedback,
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
        key: TestIds.matchNext,
        onPressed: _next,
        child: Text(_s.finished ? 'See results' : 'Next'),
      ),
    ];
  }
}
