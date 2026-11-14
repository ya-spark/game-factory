import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/profile/child_profile.dart';
import '../core/services.dart';
import '../engine/engine.dart';
import 'tabs/tab_data.dart';
import 'test_ids.dart';

/// Exam practice (C7), Study mode only: setup, the timed exam without feedback, and the review.
/// No coins, no stars, no comparison with anyone.

String examClock(int seconds) {
  final s = max(0, seconds);
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

String _subjectLabel(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// The setup screen. [onPractise] opens a normal practice round on a topic (used by the
/// "Practise these topics" links and the "Open a few more questions first" link).
class ExamSetupScreen extends StatefulWidget {
  const ExamSetupScreen({
    super.key,
    required this.child,
    required this.open,
    required this.packs,
    required this.onPractise,
    this.clock,
    this.random,
  });
  final ChildProfile child;
  final List<PoolItem> open;
  final List<LoadedPack> packs;
  final void Function(String subject, int year, String? topic) onPractise;

  /// Injected for tests.
  final DateTime Function()? clock;
  final Random? random;

  @override
  State<ExamSetupScreen> createState() => _ExamSetupScreenState();
}

class _ExamSetupScreenState extends State<ExamSetupScreen> {
  late String _subject;
  String? _topic; // null: Mixed
  int _count = 10;
  int? _minutes = 20; // null: No timer

  late final int _year;
  late final List<String> _subjects;

  @override
  void initState() {
    super.initState();
    final years = {for (final p in widget.open) p.year}.toList()..sort();
    _year = widget.child.year ?? (years.isEmpty ? 0 : years.first);
    _subjects = [
      for (final s in const ['maths', 'english'])
        if (widget.open.any((p) => p.subject == s)) s,
    ];
    if (_subjects.isEmpty) _subjects.add('maths');
    _subject = _subjects.first;
  }

  List<PoolItem> get _eligible => ExamSession.eligible(
    widget.open,
    subject: _subject,
    year: _year,
    topic: _topic,
  );

  List<String> get _topics => {
    for (final p in ExamSession.eligible(
      widget.open,
      subject: _subject,
      year: _year,
    ))
      p.topic,
  }.toList()..sort();

  int get _effectiveCount {
    final c = ExamSession.countChoices(_eligible.length);
    if (c.isEmpty) return 0;
    return c.contains(_count) ? _count : c.last;
  }

  Future<void> _start() async {
    final s = ServicesScope.of(context);
    final nav = Navigator.of(context);
    final child = s.profile.children.firstWhere(
      (c) => c.id == widget.child.id,
      orElse: () => widget.child,
    );
    final session = ExamSession.start(
      open: widget.open,
      subject: _subject,
      year: _year,
      topic: _topic,
      count: _effectiveCount,
      minutes: _minutes,
      extra: child.extraTime,
      random: widget.random ?? Random(),
      clock: widget.clock,
    );
    if (session == null) return;
    await nav.push(
      MaterialPageRoute<void>(
        builder: (_) => ExamScreen(
          session: session,
          packs: widget.packs,
          onSubmitted: (r) async {
            final fresh = s.profile.children.firstWhere(
              (c) => c.id == child.id,
              orElse: () => child,
            );
            await s.profile.recordExam(
              child.id,
              session.applyTo(fresh.progress, day: s.profile.today),
              session.toRecord(day: s.profile.today),
            );
          },
          onPractise: (subject, year, topic) {
            nav.pop(); // the exam
            nav.pop(); // the setup
            widget.onPractise(subject, year, topic);
          },
          onDone: () {
            nav.pop();
            nav.pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = ServicesScope.of(context);
    final child = s.profile.children.firstWhere(
      (c) => c.id == widget.child.id,
      orElse: () => widget.child,
    );
    final avail = _eligible.length;
    final enough = avail >= ExamSession.minQuestions;
    final limit = ExamSession.limitFor(_minutes, child.extraTime);
    return Scaffold(
      key: TestIds.examSetupScreen,
      appBar: AppBar(title: const Text('Exam practice')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'A longer set with one overall timer. You will see the answers and '
              'explanations at the end.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Text('Subject', style: theme.textTheme.titleMedium),
            Wrap(
              spacing: 8,
              children: [
                for (final sub in _subjects)
                  ChoiceChip(
                    key: TestIds.examSubject(sub),
                    label: Text(_subjectLabel(sub)),
                    selected: _subject == sub,
                    onSelected: (_) => setState(() {
                      _subject = sub;
                      _topic = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Topic', style: theme.textTheme.titleMedium),
            DropdownButton<String?>(
              key: TestIds.examTopic,
              value: _topic,
              isExpanded: true,
              items: [
                DropdownMenuItem<String?>(
                  key: TestIds.examTopicOption(null),
                  value: null,
                  child: const Text('Mixed'),
                ),
                for (final t in _topics)
                  DropdownMenuItem<String?>(
                    key: TestIds.examTopicOption(t),
                    value: t,
                    child: Text(
                      topicDisplayName(widget.packs, _subject, _year, t),
                    ),
                  ),
              ],
              onChanged: (t) => setState(() => _topic = t),
            ),
            const SizedBox(height: 16),
            if (!enough) ...[
              Text(
                'Open a few more questions first',
                key: TestIds.examNotEnough,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextButton(
                key: TestIds.examPractiseLink,
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onPractise(_subject, _year, _topic);
                },
                child: const Text('Go to practice'),
              ),
            ] else ...[
              Text('Questions', style: theme.textTheme.titleMedium),
              Wrap(
                spacing: 8,
                children: [
                  for (final n in ExamSession.countChoices(avail))
                    ChoiceChip(
                      key: TestIds.examCount(n),
                      label: Text('$n'),
                      selected: _effectiveCount == n,
                      onSelected: (_) => setState(() => _count = n),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Time', style: theme.textTheme.titleMedium),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in [...ExamSession.minuteChoices, null])
                    ChoiceChip(
                      key: TestIds.examMinutes(m),
                      label: Text(m == null ? 'No timer' : '$m minutes'),
                      selected: _minutes == m,
                      onSelected: (_) => setState(() => _minutes = m),
                    ),
                ],
              ),
              if (limit != null && child.extraTime != ExtraTime.none)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Extra time is on: ${examClock(limit)} in total.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                key: TestIds.examStart,
                onPressed: _start,
                child: const Text('Start'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The exam itself, and the results once it is submitted (or the time runs out).
class ExamScreen extends StatefulWidget {
  const ExamScreen({
    super.key,
    required this.session,
    required this.packs,
    required this.onSubmitted,
    required this.onPractise,
    required this.onDone,
  });
  final ExamSession session;
  final List<LoadedPack> packs;

  /// Called once, when the exam is submitted (save the progress and the history here).
  final Future<void> Function(ExamResult result) onSubmitted;
  final void Function(String subject, int year, String? topic) onPractise;
  final VoidCallback onDone;

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> with WidgetsBindingObserver {
  Timer? _tick;
  final _numeric = TextEditingController();
  int _numericFor = -1;

  ExamSession get _s => widget.session;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _numeric.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // In-app time only: the countdown stops while the app is in the background.
    if (state == AppLifecycleState.resumed) {
      _s.resume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _s.pause();
    }
  }

  void _onTick() {
    if (!mounted || _s.submitted) return;
    if (_s.timeUp) {
      unawaited(_submit());
    } else {
      setState(() {});
    }
  }

  Future<void> _submit() async {
    final r = _s.submit();
    _tick?.cancel();
    if (mounted) setState(() {});
    await widget.onSubmitted(r);
  }

  Future<void> _confirmSubmit() async {
    final missing = _s.unansweredNumbers;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit your answers?'),
        content: Text(
          missing.isEmpty
              ? 'You answered every question.'
              : 'Not answered yet: ${missing.join(', ')}. Unanswered questions '
                    'are not counted as wrong answers in your progress.',
          key: TestIds.examSubmitUnanswered,
        ),
        actions: [
          TextButton(
            key: TestIds.examSubmitKeep,
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            key: TestIds.examSubmitConfirm,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (yes == true && mounted && !_s.submitted) await _submit();
  }

  Future<void> _confirmExit() async {
    if (_s.submitted) {
      widget.onDone();
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave the exam?'),
        content: const Text('Your answers will not be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            key: TestIds.examExitConfirm,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final submitted = _s.submitted;
    return Scaffold(
      key: submitted ? TestIds.examResults : TestIds.examScreen,
      appBar: AppBar(
        title: Text(submitted ? 'Your results' : 'Exam practice'),
        leading: IconButton(
          key: TestIds.examExit,
          tooltip: 'Leave',
          icon: const Icon(Icons.close),
          onPressed: _confirmExit,
        ),
        actions: [
          if (!submitted && _s.limitSeconds != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Semantics(
                  label: 'Time left ${examClock(_s.remainingSeconds ?? 0)}',
                  child: Text(
                    examClock(_s.remainingSeconds ?? 0),
                    key: TestIds.examTimer,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: submitted
            ? ExamResultsView(
                result: _s.result!,
                packs: widget.packs,
                onPractise: widget.onPractise,
                onDone: widget.onDone,
              )
            : _question(context),
      ),
    );
  }

  // ---- the question ---------------------------------------------------------------------

  Widget _question(BuildContext context) {
    final theme = Theme.of(context);
    final i = _s.index;
    final p = _s.current;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Question ${i + 1} of ${_s.total}',
          key: TestIds.examProgress,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: Text(
            examPrompt(p.item),
            key: TestIds.examPrompt,
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 16),
        if (p.item.type == ItemType.numeric)
          _numericField(p, i)
        else
          ..._options(theme, p, i),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: TestIds.examPrev,
                onPressed: i == 0 ? null : () => setState(_s.previous),
                child: const Text('Previous'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                key: TestIds.examFlag,
                icon: Icon(_s.isFlagged(i) ? Icons.flag : Icons.outlined_flag),
                label: Text(_s.isFlagged(i) ? 'Flagged' : 'Flag'),
                onPressed: () => setState(() => _s.toggleFlag(i)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                key: TestIds.examNext,
                onPressed: i == _s.total - 1 ? null : () => setState(_s.next),
                child: const Text('Next'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _grid(theme),
        const SizedBox(height: 16),
        FilledButton(
          key: TestIds.examSubmit,
          onPressed: _confirmSubmit,
          child: const Text('Submit'),
        ),
      ],
    );
  }

  List<Widget> _options(ThemeData theme, PoolItem p, int i) {
    final options = mcqOptions(p.item);
    final multi = mcqCorrectIndexes(p.item).length > 1;
    final picked = _s.answerAt(i)?.picked ?? const <int>{};
    return [
      if (multi)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Pick every right answer.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      for (var k = 0; k < options.length; k++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Semantics(
            button: true,
            excludeSemantics: true,
            label: picked.contains(k) ? '${options[k]}, selected' : options[k],
            onTap: () => _pick(i, k, multi),
            child: OutlinedButton(
              key: TestIds.examOption(k),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                alignment: Alignment.centerLeft,
                side: BorderSide(
                  color: picked.contains(k)
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                  width: picked.contains(k) ? 3 : 1,
                ),
              ),
              onPressed: () => _pick(i, k, multi),
              child: Row(
                children: [
                  if (picked.contains(k)) ...[
                    const Icon(Icons.check_box),
                    const SizedBox(width: 8),
                  ],
                  Expanded(child: Text(options[k])),
                ],
              ),
            ),
          ),
        ),
    ];
  }

  void _pick(int i, int k, bool multi) {
    final now = {...(_s.answerAt(i)?.picked ?? const <int>{})};
    if (multi) {
      now.contains(k) ? now.remove(k) : now.add(k);
    } else {
      // Tapping the chosen option again clears it.
      if (now.contains(k)) {
        now.clear();
      } else {
        now
          ..clear()
          ..add(k);
      }
    }
    setState(() => _s.setAnswer(i, ExamAnswer.choice(now)));
  }

  Widget _numericField(PoolItem p, int i) {
    if (_numericFor != i) {
      _numericFor = i;
      _numeric.text = _s.answerAt(i)?.text ?? '';
    }
    final unit = p.item.json['unit'];
    return TextField(
      key: TestIds.examNumericField,
      controller: _numeric,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(
        labelText: 'Your answer',
        suffixText: unit is String && unit.isNotEmpty ? unit : null,
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) => setState(() => _s.setAnswer(i, ExamAnswer.typed(v))),
    );
  }

  Widget _grid(ThemeData theme) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var k = 0; k < _s.total; k++)
          Semantics(
            button: true,
            excludeSemantics: true,
            label:
                'Question ${k + 1}, ${_s.isAnswered(k) ? 'answered' : 'not answered'}'
                '${_s.isFlagged(k) ? ', flagged' : ''}',
            onTap: () => setState(() => _s.goTo(k)),
            child: SizedBox(
              width: 48,
              height: 48,
              child: OutlinedButton(
                key: TestIds.examGridCell(k),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: _s.isAnswered(k)
                      ? theme.colorScheme.primaryContainer
                      : null,
                  side: BorderSide(
                    color: k == _s.index
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    width: k == _s.index ? 3 : 1,
                  ),
                ),
                onPressed: () => setState(() => _s.goTo(k)),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text('${k + 1}'),
                    if (_s.isFlagged(k))
                      const Positioned(
                        top: 2,
                        right: 2,
                        child: Icon(Icons.flag, size: 12),
                      ),
                    if (_s.isAnswered(k))
                      const Positioned(
                        bottom: 2,
                        right: 2,
                        child: Icon(Icons.check, size: 12),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String examPrompt(ContentItem item) => item.json['prompt'] as String;

/// The student's answer as words, for the review.
String examYourAnswer(ContentItem item, ExamAnswer? a) {
  if (a == null || a.isEmpty) return 'Not answered';
  if (item.type == ItemType.numeric) return (a.text ?? '').trim();
  final o = mcqOptions(item);
  return [
    for (final i in a.picked.toList()..sort())
      if (i < o.length) o[i],
  ].join(', ');
}

/// The right answer as words, for the review.
String examCorrectAnswer(ContentItem item) {
  if (item.type == ItemType.numeric) {
    final unit = item.json['unit'];
    return '${item.json['answer']}${unit is String && unit.isNotEmpty ? ' $unit' : ''}';
  }
  final o = mcqOptions(item);
  return [
    for (final i in mcqCorrectIndexes(item).toList()..sort())
      if (i < o.length) o[i],
  ].join(', ');
}

class ExamResultsView extends StatelessWidget {
  const ExamResultsView({
    super.key,
    required this.result,
    required this.packs,
    required this.onPractise,
    required this.onDone,
  });
  final ExamResult result;
  final List<LoadedPack> packs;
  final void Function(String subject, int year, String? topic) onPractise;
  final VoidCallback onDone;

  String _name(String key) {
    final k = splitTopicKey(key);
    return topicDisplayName(packs, k.subject, k.year, k.topic);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = result;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Semantics(
          container: true,
          label: '${r.correct} of ${r.total} correct, ${r.percent} percent.',
          child: Text(
            '${r.correct} of ${r.total} correct (${r.percent}%)',
            key: TestIds.examScore,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Time used: ${examClock(r.seconds)}',
          key: TestIds.examTime,
          style: theme.textTheme.bodyLarge,
        ),
        if (r.timedOut)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'The time ran out, so your answers were handed in for you.',
              key: TestIds.examTimedOut,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        if (r.unanswered > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${r.unanswered} not answered. They are not counted as wrong '
              'in your progress.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        const SizedBox(height: 16),
        Text('By topic', style: theme.textTheme.titleMedium),
        for (final t in r.topics)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${_name(t.key)}: ${t.correct} of ${t.questions}',
              key: TestIds.examTopicRow(t.key),
            ),
          ),
        if (r.weakest.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Practise these topics', style: theme.textTheme.titleMedium),
          Wrap(
            spacing: 8,
            children: [
              for (final t in r.weakest)
                ActionChip(
                  key: TestIds.examPractiseTopic(t.key),
                  label: Text(_name(t.key)),
                  onPressed: () {
                    final k = splitTopicKey(t.key);
                    onPractise(k.subject, k.year, k.topic);
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Text('Review', style: theme.textTheme.titleMedium),
        for (var i = 0; i < r.items.length; i++) _reviewItem(theme, i),
        const SizedBox(height: 16),
        FilledButton(
          key: TestIds.examDone,
          onPressed: onDone,
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _reviewItem(ThemeData theme, int i) {
    final it = result.items[i];
    final item = it.item.item;
    final status = !it.answered
        ? 'not answered'
        : it.correct
        ? 'correct'
        : 'not quite';
    return Card(
      key: TestIds.examReviewItem(i),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  !it.answered
                      ? Icons.remove_circle_outline
                      : it.correct
                      ? Icons.check_circle
                      : Icons.info_outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Question ${i + 1}: $status${it.flagged ? ', flagged' : ''}',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(examPrompt(item), style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(
              'Your answer: ${examYourAnswer(item, it.answer)}',
              key: TestIds.examReviewYours(i),
            ),
            Text(
              'Correct answer: ${examCorrectAnswer(item)}',
              key: TestIds.examReviewCorrect(i),
            ),
            if (item.explanation.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.explanation,
                key: TestIds.examReviewExplanation(i),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The last exams and a calm one-line trend, for the Study Progress page.
class ExamHistoryCard extends StatelessWidget {
  const ExamHistoryCard({super.key, required this.history});
  final ExamHistory history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = history.records.reversed.toList();
    return Card(
      key: TestIds.examHistory,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Exam practice', style: theme.textTheme.titleMedium),
            if (history.trend != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  history.trend!,
                  key: TestIds.examHistoryTrend,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            const SizedBox(height: 8),
            for (var i = 0; i < rows.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  key: TestIds.examHistoryRow(i),
                  children: [
                    Expanded(
                      child: Text(
                        '${_date(rows[i].day)}  ${_subjectLabel(rows[i].subject)}, '
                        '${rows[i].questions} questions',
                      ),
                    ),
                    Text(
                      '${rows[i].correct}/${rows[i].questions}'
                      ' (${rows[i].percent}%), ${examClock(rows[i].seconds)}',
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            // A simple trend: one bar per exam, oldest on the left.
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final r in history.records)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Semantics(
                      label: '${r.percent} percent',
                      child: Container(
                        width: 14,
                        height: max(4, r.percent * 0.4),
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _date(int day) {
    final d = DateTime.utc(1970).add(Duration(days: day));
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${m[d.month - 1]}';
  }
}
