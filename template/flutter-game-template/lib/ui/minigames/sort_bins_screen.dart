import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/speech/speech_service.dart';
import '../../engine/engine.dart';
import '../test_ids.dart';
import 'minigame_parts.dart';

/// Sort into bins as a registry entry: free, both modes, needs 3 open `category` items.
final MiniGame sortBinsGame = MiniGame(
  id: sortBinsId,
  title: 'Sort into bins',
  itemTypes: const {ItemType.category},
  minPool: 3,
  build: (ctx) => SortBinsScreen(
    session: ctx.session,
    mode: ctx.mode,
    onExit: ctx.onExit,
    onAnswered: ctx.onAnswered,
  ),
);

/// Put each item into the right bin by dragging it, or by tapping the bin (so it works with a
/// screen reader and without fine motor control). One `category` item is one round. A wrong
/// drop never ends the round: the item stays and the child tries again.
class SortBinsScreen extends StatefulWidget {
  const SortBinsScreen({
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
  });

  final QuizSession session;
  final MiniGameMode mode;
  final VoidCallback onExit;
  final void Function(AnswerResult result, QuizSession session)? onAnswered;

  /// Null: from the theme's level. [hard] makes the older level harder (Craft Champion).
  final SortLevel? level;
  final bool hard;
  final Random? random;
  final ReadAloud? reader;
  final RecordedClipPlayer? recordedClip;

  @override
  State<SortBinsScreen> createState() => _SortBinsScreenState();
}

class _SortBinsScreenState extends State<SortBinsScreen> {
  late final Random _random = widget.random ?? Random();
  late final SecondsTicker _ticker = SecondsTicker(() {
    if (mounted) setState(() {});
  });
  SortRound? _round;
  int? _roundIndex;
  AnswerResult? _result;
  bool _lastWrong = false;
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
    _ticker.stop();
    _reader?.stop();
    super.dispose();
  }

  SortLevel _level(BuildContext context) =>
      widget.level ??
      (isYoungerLevel(context)
          ? SortLevel.younger
          : (widget.hard ? SortLevel.hard : SortLevel.older));

  SortRound _roundFor(BuildContext context, PoolItem p, int index) {
    if (_roundIndex != index || _round == null) {
      _roundIndex = index;
      final lvl = _level(context);
      _round = SortRound.fromItem(
        p.item,
        _study && lvl != SortLevel.younger ? SortLevel.older : lvl,
        _random,
      );
      _lastWrong = false;
      _ticker.reset();
      if (_round!.timeLimit != null && !_study) _ticker.start();
    }
    return _round!;
  }

  void _drop(SortRound r, int bin) {
    if (_result != null) return;
    final ok = r.drop(bin);
    setState(() => _lastWrong = !ok);
    if (r.complete) {
      _ticker.stop();
      final passed = _study ? true : r.passed(elapsedSeconds: _ticker.seconds);
      final res = _s.answer(correct: passed);
      widget.onAnswered?.call(res, _s);
      setState(() => _result = res);
    }
  }

  void _next() => setState(() {
    _result = null;
    _round = null;
  });

  @override
  Widget build(BuildContext context) {
    final answered = _result != null;
    final shownIndex = answered ? _s.index - 1 : _s.index;
    final done = _s.finished && !answered;
    return Scaffold(
      key: TestIds.sortScreen,
      appBar: AppBar(
        title: Text(_study ? 'Sort into bins: study' : 'Sort into bins'),
        leading: IconButton(
          key: TestIds.sortExit,
          tooltip: 'Leave the game',
          icon: const Icon(Icons.close),
          onPressed: widget.onExit,
        ),
      ),
      body: SafeArea(
        child: done
            ? MiniGameSummary(
                summaryKey: TestIds.sortSummary,
                starsKey: TestIds.sortStars,
                doneKey: TestIds.sortNext,
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
    final prompt = (p.item.json['prompt'] as String?) ?? 'Sort each one.';
    final limit = r.timeLimit;
    final item = r.current;
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
                  '${min(r.index + 1, r.total)} of ${r.total}',
                  key: TestIds.sortProgress,
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
                    key: TestIds.sortTimer,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              if (_reader != null)
                IconButton(
                  key: TestIds.sortSpeak,
                  tooltip: 'Read the instructions and the item aloud',
                  icon: const Icon(Icons.volume_up),
                  onPressed: () => _reader!.read(
                    item == null ? prompt : '$prompt ${item.text}',
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
              key: TestIds.sortPrompt,
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 16),
          if (item != null) _itemTile(theme, item),
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
                        'Not that bin. Have another go.',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          for (var i = 0; i < r.bins.length; i++) _bin(theme, r, i),
          if (_result != null) ..._feedback(theme),
        ],
      ),
    );
  }

  Widget _itemTile(ThemeData theme, SortEntry item) {
    final cs = theme.colorScheme;
    final tile = Container(
      key: TestIds.sortItem,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.drag_indicator, color: cs.onSecondaryContainer),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              item.text,
              style: theme.textTheme.titleLarge?.copyWith(
                color: cs.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      label: 'Item to sort: ${item.text}. Drag it to a bin, or tap a bin.',
      excludeSemantics: true,
      child: Draggable<int>(
        data: 0,
        feedback: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: tile,
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.4, child: tile),
        child: tile,
      ),
    );
  }

  Widget _bin(ThemeData theme, SortRound r, int i) {
    final cs = theme.colorScheme;
    final big = r.level == SortLevel.younger;
    final name = r.bins[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DragTarget<int>(
        onAcceptWithDetails: (_) => _drop(r, i),
        builder: (context, candidates, _) => Semantics(
          button: true,
          excludeSemantics: true,
          label: 'Bin: $name',
          onTap: _result == null ? () => _drop(r, i) : null,
          child: Material(
            color: candidates.isEmpty
                ? cs.surfaceContainerHighest
                : cs.primaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: candidates.isEmpty ? cs.outline : cs.primary,
                width: candidates.isEmpty ? 1 : 3,
              ),
            ),
            child: InkWell(
              key: TestIds.sortBin(i),
              borderRadius: BorderRadius.circular(16),
              onTap: _result == null ? () => _drop(r, i) : null,
              child: Container(
                constraints: BoxConstraints(minHeight: big ? 96 : 64),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined, color: cs.onSurface),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        name,
                        textAlign: TextAlign.center,
                        style:
                            (big
                                    ? theme.textTheme.titleLarge
                                    : theme.textTheme.titleMedium)
                                ?.copyWith(color: cs.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _feedback(ThemeData theme) {
    final r = _result!;
    return [
      Semantics(
        liveRegion: true,
        container: true,
        child: Column(
          key: TestIds.sortFeedback,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.correct
                        ? 'Everything sorted!'
                        : 'Everything sorted. Try again for a star.',
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
        key: TestIds.sortNext,
        onPressed: _next,
        child: Text(_s.finished ? 'See results' : 'Next'),
      ),
    ];
  }
}
