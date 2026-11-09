import 'package:flutter/material.dart';

import '../engine/engine.dart';
import 'test_ids.dart';

/// Quick quiz as a registry entry: free, both modes, needs 4 open multiple-choice items.
final MiniGame quickQuizGame = MiniGame(
  id: quickQuizId,
  title: 'Quick quiz',
  itemTypes: const {ItemType.mcq},
  minPool: 4,
  build: (ctx) => QuickQuizScreen(
    session: ctx.session,
    mode: ctx.mode,
    onExit: ctx.onExit,
    onAnswered: ctx.onAnswered,
  ),
);

/// Multiple choice (and true or false) in Game or Study mode. One option is tapped to answer;
/// an item with several correct options uses taps to select and a Check button.
///
/// The explanation shows after every answer. Colour is never the only signal: the feedback has
/// an icon and words. The page scrolls, so large text never breaks it.
class QuickQuizScreen extends StatefulWidget {
  const QuickQuizScreen({
    super.key,
    required this.session,
    required this.mode,
    required this.onExit,
    this.onAnswered,
  });

  final QuizSession session;
  final MiniGameMode mode;
  final VoidCallback onExit;

  /// Called after every answer with the result and the updated session (save progress and
  /// add coins here).
  final void Function(AnswerResult result, QuizSession session)? onAnswered;

  @override
  State<QuickQuizScreen> createState() => _QuickQuizScreenState();
}

class _QuickQuizScreenState extends State<QuickQuizScreen> {
  final Set<int> _picked = {};
  AnswerResult? _result;
  Set<int> _shownCorrect = {};

  QuizSession get _s => widget.session;
  bool get _study => widget.mode == MiniGameMode.study;

  void _submit(PoolItem p, Set<int> picked) {
    final correctSet = mcqCorrectIndexes(p.item);
    final r = _s.answer(correct: mcqIsCorrect(p.item, picked));
    widget.onAnswered?.call(r, _s);
    setState(() {
      _picked
        ..clear()
        ..addAll(picked);
      _shownCorrect = correctSet;
      _result = r;
    });
  }

  void _next() => setState(() {
    _result = null;
    _picked.clear();
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final answered = _result != null;
    // After an answer the session has already moved on; show the item that was answered.
    final shownIndex = answered ? _s.index - 1 : _s.index;
    final done = _s.finished && !answered;
    return Scaffold(
      key: TestIds.quizScreen,
      appBar: AppBar(
        title: Text(_study ? 'Quick quiz: study' : 'Quick quiz'),
        leading: IconButton(
          key: TestIds.quizExit,
          tooltip: 'Leave the quiz',
          icon: const Icon(Icons.close),
          onPressed: widget.onExit,
        ),
      ),
      body: SafeArea(
        child: done
            ? _summary(theme)
            : _question(theme, _s.items[shownIndex], shownIndex),
      ),
    );
  }

  Widget _summary(ThemeData theme) {
    final r = _s.report;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          key: TestIds.quizSummary,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              container: true,
              label: 'Round finished. ${r.correct} of ${r.answered} correct.',
              child: Text(
                '${r.correct} of ${r.answered} correct',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            ),
            if (_s.rewardsConfig.starsEnabled) ...[
              const SizedBox(height: 12),
              Text(
                '${r.stars} stars earned',
                key: TestIds.quizStars,
                style: theme.textTheme.titleMedium,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: TestIds.quizNext,
              onPressed: widget.onExit,
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _question(ThemeData theme, PoolItem p, int index) {
    final options = mcqOptions(p.item);
    final multi = mcqCorrectIndexes(p.item).length > 1;
    final answered = _result != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Question ${index + 1} of ${_s.total}',
            key: TestIds.quizProgress,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(
              mcqPrompt(p.item),
              key: TestIds.quizPrompt,
              style: theme.textTheme.titleLarge,
            ),
          ),
          if (multi && !answered)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Pick every right answer, then press Check.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          const SizedBox(height: 16),
          for (var i = 0; i < options.length; i++)
            _option(theme, p, options, i),
          if (multi && !answered) ...[
            const SizedBox(height: 8),
            FilledButton(
              key: TestIds.quizCheck,
              onPressed: _picked.isEmpty
                  ? null
                  : () => _submit(p, {..._picked}),
              child: const Text('Check'),
            ),
          ],
          if (answered) ..._feedback(theme),
        ],
      ),
    );
  }

  Widget _option(ThemeData theme, PoolItem p, List<String> options, int i) {
    final multi = mcqCorrectIndexes(p.item).length > 1;
    final answered = _result != null;
    final selected = _picked.contains(i);
    final isRight = _shownCorrect.contains(i);
    String status = '';
    IconData? icon;
    if (answered) {
      if (isRight) {
        status = 'correct answer';
        icon = Icons.check_circle;
      } else if (selected) {
        status = 'your answer, not correct';
        icon = Icons.cancel;
      }
    } else if (selected) {
      status = 'selected';
      icon = Icons.check_box;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        excludeSemantics: true,
        label: status.isEmpty ? options[i] : '${options[i]}, $status',
        onTap: answered
            ? null
            : () => multi
                  ? setState(() {
                      selected ? _picked.remove(i) : _picked.add(i);
                    })
                  : _submit(p, {i}),
        child: OutlinedButton(
          key: TestIds.quizOption(i),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            alignment: Alignment.centerLeft,
            side: BorderSide(
              color: selected || (answered && isRight)
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              width: selected || (answered && isRight) ? 3 : 1,
            ),
          ),
          onPressed: answered
              ? null
              : () {
                  if (multi) {
                    setState(() {
                      selected ? _picked.remove(i) : _picked.add(i);
                    });
                  } else {
                    _submit(p, {i});
                  }
                },
          child: Row(
            children: [
              if (icon != null) ...[Icon(icon), const SizedBox(width: 8)],
              Expanded(child: Text(options[i])),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _feedback(ThemeData theme) {
    final r = _result!;
    return [
      const SizedBox(height: 8),
      Semantics(
        liveRegion: true,
        container: true,
        child: Column(
          key: TestIds.quizFeedback,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(r.correct ? Icons.check_circle : Icons.info_outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.correct ? 'Correct!' : 'Not quite.',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              r.explanation,
              key: TestIds.quizExplanation,
              style: theme.textTheme.bodyLarge,
            ),
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
        key: TestIds.quizNext,
        onPressed: _next,
        child: Text(_s.finished ? 'See results' : 'Next'),
      ),
    ];
  }
}
