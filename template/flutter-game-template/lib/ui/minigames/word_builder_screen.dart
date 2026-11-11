import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/speech/speech_service.dart';
import '../../engine/engine.dart';
import '../test_ids.dart';
import 'minigame_parts.dart';

/// Word builder as a registry entry: free, both modes, needs 3 open `word` or `cloze` items.
final MiniGame wordBuilderGame = MiniGame(
  id: wordBuilderId,
  title: 'Word builder',
  itemTypes: const {ItemType.word, ItemType.cloze},
  minPool: 3,
  build: (ctx) => WordBuilderScreen(
    session: ctx.session,
    mode: ctx.mode,
    onExit: ctx.onExit,
    onAnswered: ctx.onAnswered,
    onScore: ctx.onScore,
  ),
);

/// Build the answer from letter tiles, with a hint. One `word` item (or one `cloze` item, a word
/// per gap) is one round. Younger: a wrong letter is greyed out, the word completes by itself, no
/// timer, no failing. Older: build the word and press Check, with a gentle timer. The correct
/// spelling is shown after any miss. Pass `hard: true` for Craft Champion.
class WordBuilderScreen extends StatefulWidget {
  const WordBuilderScreen({
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
  final WordLevel? level;
  final bool hard;
  final Random? random;
  final ReadAloud? reader;
  final RecordedClipPlayer? recordedClip;

  @override
  State<WordBuilderScreen> createState() => _WordBuilderScreenState();
}

class _WordBuilderScreenState extends State<WordBuilderScreen> {
  late final Random _random = widget.random ?? Random();
  late final SecondsTicker _ticker = SecondsTicker(() {
    if (mounted) setState(() {});
  });
  WordRound? _round;
  int? _roundIndex;
  AnswerResult? _result;
  bool _lastWrong = false;
  ReadAloud? _reader;
  int _score = 0;
  int _streak = 0;
  bool _scoreSent = false;

  /// The correct spellings of the words missed in this round, shown after a miss.
  final List<String> _missed = [];

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

  WordLevel _level(BuildContext context) =>
      widget.level ??
      (isYoungerLevel(context)
          ? WordLevel.younger
          : (widget.hard ? WordLevel.hard : WordLevel.older));

  WordRound _roundFor(BuildContext context, PoolItem p, int index) {
    if (_roundIndex != index || _round == null) {
      _roundIndex = index;
      final lvl = _level(context);
      _round = WordRound.fromItem(
        p.item,
        _study && lvl != WordLevel.younger ? WordLevel.older : lvl,
        _random,
      );
      _lastWrong = false;
      _missed.clear();
      _ticker.reset();
      if (_round!.timeLimit != null && !_study) _ticker.start();
    }
    return _round!;
  }

  void _afterMove(WordRound r, {required bool ok, required int slotBefore}) {
    setState(() => _lastWrong = !ok);
    if (r.slotIndex != slotBefore) _lastWrong = false;
    if (r.complete) _finish(r);
  }

  void _finish(WordRound r) {
    _ticker.stop();
    final passed = _study ? true : r.passed(elapsedSeconds: _ticker.seconds);
    final res = _s.answer(correct: passed);
    if (passed) {
      _score += scoreForAnswer(
        streak: _streak,
        older: r.level != WordLevel.younger,
      );
      _streak++;
    } else {
      _streak = 0;
    }
    widget.onAnswered?.call(res, _s);
    setState(() => _result = res);
  }

  void _tap(WordRound r, int tile) {
    if (_result != null) return;
    final before = r.slotIndex;
    final ok = r.tap(tile);
    _afterMove(r, ok: ok || r.level != WordLevel.younger, slotBefore: before);
  }

  void _check(WordRound r) {
    if (_result != null) return;
    final before = r.slotIndex;
    final word = r.current?.correct;
    final ok = r.submit();
    if (!ok && word != null && r.built.isEmpty && r.misses > 0) {
      if (!_missed.contains(word)) _missed.add(word);
    }
    _afterMove(r, ok: ok, slotBefore: before);
  }

  void _undo(WordRound r) {
    if (_result != null) return;
    setState(() {
      r.undo();
      _lastWrong = false;
    });
  }

  void _clear(WordRound r) {
    if (_result != null) return;
    setState(() {
      r.clear();
      _lastWrong = false;
    });
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
      key: TestIds.wordBuilderScreen,
      appBar: AppBar(
        title: Text(_study ? 'Word builder: study' : 'Word builder'),
        leading: IconButton(
          key: TestIds.wordBuilderExit,
          tooltip: 'Leave the game',
          icon: const Icon(Icons.close),
          onPressed: widget.onExit,
        ),
      ),
      body: SafeArea(
        child: done
            ? MiniGameSummary(
                summaryKey: TestIds.wordBuilderSummary,
                starsKey: TestIds.wordBuilderStars,
                doneKey: TestIds.wordBuilderNext,
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
    final slot = r.current;
    final hint = r.hintText ?? '';
    final limit = r.timeLimit;
    final older = r.level != WordLevel.younger;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Round ${index + 1} of ${_s.total}'
                  '${r.total > 1 ? ': word ${min(r.slotIndex + 1, r.total)} of ${r.total}' : ''}',
                  key: TestIds.wordBuilderProgress,
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
                    key: TestIds.wordBuilderTimer,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              if (_reader != null)
                IconButton(
                  key: TestIds.wordBuilderSpeak,
                  tooltip: 'Read the hint aloud',
                  icon: const Icon(Icons.volume_up),
                  onPressed: () => _reader!.read(
                    hint.replaceAll('____', 'blank'),
                    audioRef: p.item.audio,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            header: true,
            child: Text(
              hint,
              key: TestIds.wordBuilderHint,
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 16),
          if (slot != null) _builtRow(theme, r, slot),
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
                        older
                            ? 'Not quite. Have another go.'
                            : 'Not that letter. Have another go.',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_missed.isNotEmpty && _result == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'The spelling is: ${_missed.last}',
                style: theme.textTheme.bodyLarge,
              ),
            ),
          const SizedBox(height: 16),
          if (slot != null)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < slot.tiles.length; i++) _tile(theme, r, i),
              ],
            ),
          if (older && slot != null && _result == null) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton(
                  key: TestIds.wordBuilderCheck,
                  onPressed: r.built.isEmpty ? null : () => _check(r),
                  child: const Text('Check'),
                ),
                OutlinedButton.icon(
                  key: TestIds.wordBuilderUndo,
                  onPressed: r.built.isEmpty ? null : () => _undo(r),
                  icon: const Icon(Icons.backspace_outlined),
                  label: const Text('Undo'),
                ),
                OutlinedButton(
                  key: TestIds.wordBuilderClear,
                  onPressed: r.built.isEmpty ? null : () => _clear(r),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ],
          if (!older && slot != null && _result == null && r.built.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: TestIds.wordBuilderUndo,
                  onPressed: () => _undo(r),
                  icon: const Icon(Icons.backspace_outlined),
                  label: const Text('Undo'),
                ),
              ),
            ),
          if (_result != null) ..._feedback(theme, r),
        ],
      ),
    );
  }

  Widget _builtRow(ThemeData theme, WordRound r, WordSlot slot) {
    final cs = theme.colorScheme;
    final text = r.built;
    return Semantics(
      container: true,
      liveRegion: true,
      label: text.isEmpty ? 'Your word is empty' : 'Your word: $text',
      excludeSemantics: true,
      child: Container(
        key: TestIds.wordBuilderBuilt,
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.primary, width: 2),
        ),
        child: Text(
          text.isEmpty ? '...' : text,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: cs.onSurface,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget _tile(ThemeData theme, WordRound r, int i) {
    final cs = theme.colorScheme;
    final used = r.isUsed(i);
    final greyed = r.isGreyed(i);
    final text = r.current!.tiles[i];
    final big = r.level == WordLevel.younger;
    final enabled = !used && !greyed && _result == null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: used
          ? 'Letter $text, already used'
          : (greyed ? 'Letter $text, not this one' : 'Letter $text'),
      excludeSemantics: true,
      child: Opacity(
        opacity: used ? 0.35 : (greyed ? 0.5 : 1),
        child: Material(
          color: cs.secondaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: cs.outline),
          ),
          child: InkWell(
            key: TestIds.wordBuilderTile(i),
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? () => _tap(r, i) : null,
            child: Container(
              constraints: BoxConstraints(
                minWidth: big ? 64 : 52,
                minHeight: big ? 64 : 52,
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  List<Widget> _feedback(ThemeData theme, WordRound r) {
    final res = _result!;
    final answers = [for (final s in r.slots) s.correct];
    return [
      const SizedBox(height: 16),
      Semantics(
        liveRegion: true,
        container: true,
        child: Column(
          key: TestIds.wordBuilderFeedback,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    res.correct
                        ? 'Well built!'
                        : 'Built. Try again for a star.',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (_missed.isNotEmpty || r.misses > 0 || !res.correct) ...[
              const SizedBox(height: 8),
              Text(
                'The spelling is: ${answers.join(', ')}',
                style: theme.textTheme.bodyLarge,
              ),
            ],
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
        key: TestIds.wordBuilderNext,
        onPressed: _next,
        child: Text(_s.finished ? 'See results' : 'Next'),
      ),
    ];
  }
}
