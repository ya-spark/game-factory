import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/speech/speech_service.dart';
import '../../engine/engine.dart';
import '../test_ids.dart';
import 'minigame_parts.dart';

/// Series builder as a registry entry: free, both modes, needs 3 open `series` items.
final MiniGame seriesBuilderGame = MiniGame(
  id: seriesBuilderId,
  title: 'Series builder',
  itemTypes: const {ItemType.series},
  minPool: 3,
  build: (ctx) => SeriesBuilderScreen(
    session: ctx.session,
    mode: ctx.mode,
    onExit: ctx.onExit,
    onAnswered: ctx.onAnswered,
    onScore: ctx.onScore,
  ),
);

/// Put the steps in order by tapping the tiles one after the other. One `series` item is one
/// round. Younger: a wrong tile is greyed out and the child tries again, no timer, no failing.
/// Older: a gentle timer. Pass `hard: true` for Craft Champion.
class SeriesBuilderScreen extends StatefulWidget {
  const SeriesBuilderScreen({
    super.key,
    required this.session,
    required this.mode,
    required this.onExit,
    this.onAnswered,
    this.onScore,
    this.level,
    this.hard = false,
    this.random,
    this.reader,
    this.recordedClip,
  });

  final QuizSession session;
  final MiniGameMode mode;
  final VoidCallback onExit;
  final void Function(AnswerResult result, QuizSession session)? onAnswered;
  final void Function(int score)? onScore;

  /// Null: from the theme's level.
  final SeriesLevel? level;
  final bool hard;
  final Random? random;
  final ReadAloud? reader;
  final RecordedClipPlayer? recordedClip;

  @override
  State<SeriesBuilderScreen> createState() => _SeriesBuilderScreenState();
}

class _SeriesBuilderScreenState extends State<SeriesBuilderScreen> {
  late final Random _random = widget.random ?? Random();
  late final SecondsTicker _ticker = SecondsTicker(() {
    if (mounted) setState(() {});
  });
  SeriesRound? _round;
  int? _roundIndex;
  AnswerResult? _result;
  bool _lastWrong = false;
  ReadAloud? _reader;
  int _score = 0;
  int _streak = 0;
  bool _scoreSent = false;

  QuizSession get _s => widget.session;
  bool get _study => widget.mode == MiniGameMode.study;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reader = resolveReader(context, widget.reader, widget.recordedClip);
  }

  @override
  void dispose() {
    _ticker.stop();
    _reader?.stop();
    super.dispose();
  }

  SeriesLevel _level(BuildContext context) =>
      widget.level ??
      (isYoungerLevel(context)
          ? SeriesLevel.younger
          : (widget.hard ? SeriesLevel.hard : SeriesLevel.older));

  SeriesRound _roundFor(BuildContext context, PoolItem p, int index) {
    if (_roundIndex != index || _round == null) {
      _roundIndex = index;
      final lvl = _level(context);
      _round = SeriesRound.fromItem(
        p.item,
        _study && lvl != SeriesLevel.younger ? SeriesLevel.older : lvl,
        _random,
      );
      _lastWrong = false;
      _ticker.reset();
      if (_round!.timeLimit != null && !_study) _ticker.start();
    }
    return _round!;
  }

  void _tap(SeriesRound r, int tile) {
    if (_result != null) return;
    final ok = r.place(tile);
    setState(() => _lastWrong = !ok);
    if (r.complete) {
      _ticker.stop();
      final passed = _study ? true : r.passed(elapsedSeconds: _ticker.seconds);
      final res = _s.answer(correct: passed);
      if (passed) {
        _score += scoreForAnswer(
          streak: _streak,
          older: r.level != SeriesLevel.younger,
        );
        _streak++;
      } else {
        _streak = 0;
      }
      widget.onAnswered?.call(res, _s);
      setState(() => _result = res);
    }
  }

  void _next() {
    setState(() {
      _result = null;
      _round = null;
    });
    if (_s.finished && !_scoreSent) {
      _scoreSent = true;
      widget.onScore?.call(_score);
    }
  }

  @override
  Widget build(BuildContext context) {
    final answered = _result != null;
    final shownIndex = answered ? _s.index - 1 : _s.index;
    final done = _s.finished && !answered;
    return Scaffold(
      key: TestIds.seriesScreen,
      appBar: AppBar(
        title: Text(_study ? 'Series builder: study' : 'Series builder'),
        leading: IconButton(
          key: TestIds.seriesExit,
          tooltip: 'Leave the game',
          icon: const Icon(Icons.close),
          onPressed: widget.onExit,
        ),
      ),
      body: SafeArea(
        child: done
            ? MiniGameSummary(
                summaryKey: TestIds.seriesSummary,
                starsKey: TestIds.seriesStars,
                doneKey: TestIds.seriesNext,
                correct: _s.report.correct,
                answered: _s.report.answered,
                stars: _s.report.stars,
                showStars: _s.rewardsConfig.starsEnabled && !_study,
                onDone: widget.onExit,
              )
            : _roundView(context, _s.items[shownIndex], shownIndex),
      ),
    );
  }

  Widget _roundView(BuildContext context, PoolItem p, int index) {
    final theme = Theme.of(context);
    final r = _roundFor(context, p, index);
    final prompt = (p.item.json['prompt'] as String?) ?? 'Put them in order.';
    final limit = r.timeLimit;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Round ${index + 1} of ${_s.total}: '
                  '${min(r.placed + 1, r.total)} of ${r.total}',
                  key: TestIds.seriesProgress,
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
                    key: TestIds.seriesTimer,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              if (_reader != null)
                IconButton(
                  key: TestIds.seriesSpeak,
                  tooltip: 'Read the instructions and the tiles aloud',
                  icon: const Icon(Icons.volume_up),
                  onPressed: () => _reader!.read(
                    '$prompt ${r.tiles.join(', ')}',
                    audioRef: p.item.audio,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            header: true,
            child: Text(
              prompt,
              key: TestIds.seriesPrompt,
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 16),
          _slots(theme, r),
          if (_lastWrong && _result == null)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Not that one next. Have another go.',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < r.tiles.length; i++) _tile(theme, r, i),
            ],
          ),
          if (_result != null) ..._feedback(theme, r),
        ],
      ),
    );
  }

  /// The row the child builds: placed steps first, then empty places.
  Widget _slots(ThemeData theme, SeriesRound r) {
    final cs = theme.colorScheme;
    final placed = r.placedTexts;
    return Semantics(
      container: true,
      label:
          'Your order so far: ${placed.isEmpty ? 'nothing yet' : placed.join(', ')}. '
          '${r.total - placed.length} to go.',
      excludeSemantics: true,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < r.total; i++)
            Container(
              key: TestIds.seriesSlot(i),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i < placed.length
                    ? cs.primaryContainer
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: i == placed.length ? cs.primary : cs.outline,
                  width: i == placed.length ? 3 : 1,
                ),
              ),
              child: Text(
                i < placed.length ? placed[i] : '${i + 1}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: i < placed.length
                      ? cs.onPrimaryContainer
                      : cs.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(ThemeData theme, SeriesRound r, int i) {
    final cs = theme.colorScheme;
    final used = r.isUsed(i);
    final greyed = r.isGreyed(i);
    final text = r.tiles[i];
    final big = r.level == SeriesLevel.younger;
    final enabled = !used && !greyed && _result == null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: used
          ? '$text, already placed'
          : (greyed ? '$text, not this one' : text),
      excludeSemantics: true,
      child: Opacity(
        opacity: used ? 0.35 : (greyed ? 0.5 : 1),
        child: Material(
          color: cs.secondaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cs.outline),
          ),
          child: InkWell(
            key: TestIds.seriesTile(i),
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? () => _tap(r, i) : null,
            child: Container(
              constraints: BoxConstraints(
                minWidth: big ? 72 : 56,
                minHeight: big ? 72 : 56,
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                text,
                style:
                    (big
                            ? theme.textTheme.headlineSmall
                            : theme.textTheme.titleLarge)
                        ?.copyWith(color: cs.onSecondaryContainer),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _feedback(ThemeData theme, SeriesRound r) {
    final res = _result!;
    return [
      const SizedBox(height: 16),
      Semantics(
        liveRegion: true,
        container: true,
        child: Column(
          key: TestIds.seriesFeedback,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    res.correct
                        ? 'In order!'
                        : 'In order now. Try again for a star.',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (res.explanation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(res.explanation, style: theme.textTheme.bodyLarge),
            ],
            if (!_study && res.stars > 0) ...[
              const SizedBox(height: 8),
              Text(
                '+${res.stars} ${res.stars == 1 ? 'star' : 'stars'}',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      FilledButton(
        key: TestIds.seriesNext,
        onPressed: _next,
        child: Text(_s.finished ? 'See results' : 'Next'),
      ),
    ];
  }
}
