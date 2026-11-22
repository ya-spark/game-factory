import 'dart:math';

import 'package:flutter/material.dart';

import 'package:game_core/game_core.dart';

import 'sort_bins_ids.dart';

import 'rules/sort_bins_rules.dart';

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
  });

  final QuizSession session;
  final MiniGameMode mode;
  final VoidCallback onExit;
  final void Function(AnswerResult result, QuizSession session)? onAnswered;

  /// Null: from the theme's level. [hard] makes the older level harder (Craft Champion).
  final SortLevel? level;
  final bool hard;
  final Random? random;
  final GameReadAloud? reader;

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
  GameReadAloud? _reader;

  /// The bin under the keyboard cursor; shown once a key has been used.
  int _cursor = 0;
  bool _keyed = false;

  QuizSession get _s => widget.session;
  bool get _study => widget.mode == MiniGameMode.study;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reader = resolveReader(context, widget.reader);
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

  // ---- keyboard (docs/SPEC.md, Keyboard): up and down (or left and right) move over the bins, Enter drops the
  // item in the bin (or goes on), 1 to 4 drop it in that bin, Esc leaves ----

  void _onKey(GameInput i) {
    final a = i.action;
    if (a == GameAction.exit) {
      if (!i.repeat) widget.onExit();
      return;
    }
    if (_s.finished && _result == null) {
      if (!i.repeat && (a == GameAction.action || a == GameAction.pause)) {
        widget.onExit();
      }
      return;
    }
    if (a == GameAction.question) {
      if (!i.repeat && _result == null && _round != null) {
        _readItem(_s.items[_s.index], _round!);
      }
      return;
    }
    final r = _round;
    if (_result != null) {
      if (!i.repeat && (a == GameAction.action || a == GameAction.pause)) {
        _next();
      }
      return;
    }
    if (r == null) return;
    final n = r.bins.length;
    final back = a == GameAction.left || a == GameAction.up;
    final fwd = a == GameAction.right || a == GameAction.down;
    if (back || fwd) {
      setState(() {
        _keyed = true;
        _cursor = (_cursor + (back ? -1 : 1)) % n;
      });
    } else if (i.repeat) {
      return;
    } else if (a == GameAction.action) {
      setState(() => _keyed = true);
      _drop(r, _cursor);
    } else if (a.pickNumber != null && a.pickNumber! <= n) {
      setState(() {
        _keyed = true;
        _cursor = a.pickNumber! - 1;
      });
      _drop(r, _cursor);
    }
  }

  void _readItem(PoolItem p, SortRound r) {
    final prompt = (p.item.json['prompt'] as String?) ?? 'Sort each one.';
    final item = r.current;
    _reader?.read(
      item == null ? prompt : '$prompt ${item.text}',
      audioRef: p.item.audio,
    );
  }

  void _next() => setState(() {
    _result = null;
    _round = null;
    _cursor = 0;
  });

  @override
  Widget build(BuildContext context) {
    final answered = _result != null;
    final shownIndex = answered ? _s.index - 1 : _s.index;
    final done = _s.finished && !answered;
    return Scaffold(
      key: SortBinsIds.sortScreen,
      appBar: AppBar(
        title: Text(_study ? 'Sort into bins: study' : 'Sort into bins'),
        leadingWidth: KeyedBackButton.width,
        leading: KeyedBackButton(
          key: SortBinsIds.sortExit,
          tooltip: 'Leave the game',
          icon: Icons.close,
          onPressed: widget.onExit,
        ),
      ),
      body: SafeArea(
        child: KeyedBody(
          onInput: _onKey,
          spaceGoesOn: done || _result != null,
          hints: const [
            GameAction.up,
            GameAction.down,
            GameAction.action,
            GameAction.question,
            GameAction.exit,
          ],
          words: const {GameAction.up: 'bins', GameAction.action: 'drop'},
          child: done
              ? MiniGameSummary(
                  summaryKey: SortBinsIds.sortSummary,
                  starsKey: SortBinsIds.sortStars,
                  doneKey: SortBinsIds.sortNext,
                  correct: _s.report.correct,
                  answered: _s.report.answered,
                  stars: _s.report.stars,
                  showStars: _s.rewardsConfig.starsEnabled && !_study,
                  onDone: widget.onExit,
                )
              : _roundView(context, _s.items[shownIndex], shownIndex),
        ),
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
                  key: SortBinsIds.sortProgress,
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
                    key: SortBinsIds.sortTimer,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              if (_reader != null)
                KeyedIconButton(
                  key: SortBinsIds.sortSpeak,
                  tooltip: 'Read the instructions and the item aloud',
                  icon: Icons.volume_up,
                  keyName: keyNameOf(context, GameAction.question),
                  onPressed: () => _readItem(p, r),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            header: true,
            child: Text(
              prompt,
              key: SortBinsIds.sortPrompt,
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
      key: SortBinsIds.sortItem,
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
                color: candidates.isNotEmpty
                    ? cs.primary
                    : (_keyed && _cursor == i ? cs.tertiary : cs.outline),
                width: candidates.isNotEmpty || (_keyed && _cursor == i)
                    ? 4
                    : 1,
              ),
            ),
            child: InkWell(
              key: SortBinsIds.sortBin(i),
              borderRadius: BorderRadius.circular(16),
              onTap: _result == null ? () => _drop(r, i) : null,
              child: Container(
                constraints: BoxConstraints(minHeight: big ? 96 : 64),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (i < 4) ...[
                      KeyCap(label: '${i + 1}'),
                      const SizedBox(width: 8),
                    ],
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
          key: SortBinsIds.sortFeedback,
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
        key: SortBinsIds.sortNext,
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
