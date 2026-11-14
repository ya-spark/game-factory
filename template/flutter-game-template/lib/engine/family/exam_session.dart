/// Exam practice (C7): a longer set under one overall timer, no feedback while answering and a
/// full review at the end. Study mode only: no coins and no stars. Pure Dart; the clock and the
/// random source are injected.
library;

import 'dart:math';

import '../content/models.dart';
import '../content/numeric.dart';
import '../content/progress.dart';
import '../minigames/quick_quiz.dart';

/// Parent setting: extra time on the countdown.
enum ExtraTime {
  none('None', 1.0),
  quarter('+25 percent', 1.25),
  half('+50 percent', 1.5);

  const ExtraTime(this.label, this.factor);
  final String label;
  final double factor;

  static ExtraTime parse(Object? v) {
    for (final e in values) {
      if (e.name == v) return e;
    }
    return none;
  }
}

/// One finished exam, kept on the device (the last [ExamHistory.keep] per child).
class ExamRecord {
  const ExamRecord({
    required this.day,
    required this.subject,
    required this.questions,
    required this.correct,
    required this.seconds,
  });
  final int day;
  final String subject;
  final int questions;
  final int correct;
  final int seconds;

  int get percent => questions == 0 ? 0 : (correct * 100 / questions).round();

  Map<String, Object?> toJson() => {
    'd': day,
    's': subject,
    'q': questions,
    'c': correct,
    't': seconds,
  };

  static ExamRecord? fromJson(Object? j) {
    if (j is! Map) return null;
    int n(Object? v) => v is num && v >= 0 ? v.toInt() : 0;
    final q = n(j['q']);
    final s = j['s'];
    if (q <= 0 || s is! String) return null;
    return ExamRecord(
      day: n(j['d']),
      subject: s,
      questions: q,
      correct: n(j['c']).clamp(0, q),
      seconds: n(j['t']),
    );
  }
}

/// The last 10 exams, oldest first.
class ExamHistory {
  const ExamHistory([this.records = const []]);
  static const int keep = 10;
  final List<ExamRecord> records;

  ExamHistory add(ExamRecord r) {
    final all = [...records, r];
    return ExamHistory(
      all.length > keep ? all.sublist(all.length - keep) : all,
    );
  }

  /// A calm one-line trend from the last scores: compares the newest exam with the average of
  /// the ones before it. Null with fewer than two exams.
  String? get trend {
    if (records.length < 2) return null;
    final last = records.last.percent;
    final before = records.sublist(0, records.length - 1);
    final avg = before.fold<int>(0, (a, r) => a + r.percent) / before.length;
    if (last >= avg + 5) return 'Your latest practice went up. Nice work.';
    if (last <= avg - 5) {
      return 'Your latest practice was a bit lower. That is fine.';
    }
    return 'Your practice scores are steady.';
  }

  List<Object?> toJson() => [for (final r in records) r.toJson()];

  factory ExamHistory.fromJson(Object? j) {
    if (j is! List) return const ExamHistory();
    final out = [for (final e in j) ?ExamRecord.fromJson(e)];
    return ExamHistory(
      out.length > keep ? out.sublist(out.length - keep) : out,
    );
  }
}

/// A student's answer to one question: picked options (multiple choice) or typed text.
class ExamAnswer {
  const ExamAnswer.choice(this.picked) : text = null;
  const ExamAnswer.typed(String this.text) : picked = const {};
  final Set<int> picked;
  final String? text;

  bool get isEmpty => text == null ? picked.isEmpty : text!.trim().isEmpty;
}

/// How one question went.
class ExamReviewItem {
  const ExamReviewItem({
    required this.item,
    required this.answer,
    required this.answered,
    required this.correct,
    required this.flagged,
  });
  final PoolItem item;
  final ExamAnswer? answer;
  final bool answered;
  final bool correct;
  final bool flagged;
}

class ExamTopicScore {
  const ExamTopicScore({
    required this.key,
    required this.questions,
    required this.correct,
  });
  final String key;
  final int questions;
  final int correct;
  double get ratio => questions == 0 ? 0 : correct / questions;
}

class ExamResult {
  const ExamResult({
    required this.items,
    required this.correct,
    required this.seconds,
    required this.timedOut,
    required this.topics,
  });
  final List<ExamReviewItem> items;
  final int correct;
  final int seconds;
  final bool timedOut;
  final List<ExamTopicScore> topics;

  int get total => items.length;
  int get unanswered => items.where((i) => !i.answered).length;
  int get percent => total == 0 ? 0 : (correct * 100 / total).round();

  /// Topics with a question not answered correctly, lowest score first (at most 3).
  List<ExamTopicScore> get weakest {
    final w = topics.where((t) => t.correct < t.questions).toList()
      ..sort((a, b) {
        final c = a.ratio.compareTo(b.ratio);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return w.take(3).toList();
  }
}

class ExamSession {
  ExamSession({
    required this.items,
    required this.subject,
    required this.limitSeconds,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _running = true {
    _since = _clock();
  }

  /// Item types an exam draws from in v1.
  static const Set<ItemType> types = {ItemType.mcq, ItemType.numeric};
  static const List<int> questionChoices = [10, 20, 30];
  static const List<int> minuteChoices = [10, 20, 30];

  /// Fewer open matching questions than this: the exam is not offered.
  static const int minQuestions = 10;

  /// Open questions an exam could use for the chosen filters.
  static List<PoolItem> eligible(
    List<PoolItem> open, {
    required String subject,
    required int year,
    String? topic,
  }) => [
    for (final p in open)
      if (p.subject == subject &&
          p.year == year &&
          (topic == null || p.topic == topic) &&
          types.contains(p.item.type))
        p,
  ];

  /// How many questions can be offered: the choices not above what is open.
  static List<int> countChoices(int available) => [
    for (final c in questionChoices)
      if (c <= available) c,
  ];

  /// The countdown in seconds, or null for no timer.
  static int? limitFor(int? minutes, ExtraTime extra) =>
      minutes == null ? null : (minutes * 60 * extra.factor).round();

  /// Builds a set, or returns null when fewer than [minQuestions] matching questions are open.
  /// [count] is capped by what is open. A mixed set (no [topic]) is spread over topics.
  static ExamSession? start({
    required List<PoolItem> open,
    required String subject,
    required int year,
    String? topic,
    required int count,
    int? minutes,
    ExtraTime extra = ExtraTime.none,
    required Random random,
    DateTime Function()? clock,
  }) {
    final pool = eligible(open, subject: subject, year: year, topic: topic)
      ..sort((a, b) => a.id.compareTo(b.id));
    if (pool.length < minQuestions) return null;
    final want = min(count, pool.length);
    final picked = _spread(pool, want, random);
    return ExamSession(
      items: picked,
      subject: subject,
      limitSeconds: limitFor(minutes, extra),
      clock: clock,
    );
  }

  /// Round-robin over shuffled topics so a mixed set covers several topics.
  static List<PoolItem> _spread(List<PoolItem> pool, int n, Random random) {
    final by = <String, List<PoolItem>>{};
    for (final p in pool) {
      by.putIfAbsent(p.topic, () => []).add(p);
    }
    final keys = by.keys.toList()..sort();
    keys.shuffle(random);
    for (final l in by.values) {
      l.shuffle(random);
    }
    final out = <PoolItem>[];
    var i = 0;
    while (out.length < n) {
      final l = by[keys[i % keys.length]]!;
      if (l.isNotEmpty) out.add(l.removeLast());
      i++;
    }
    return out..shuffle(random);
  }

  final List<PoolItem> items;
  final String subject;

  /// Countdown length in seconds; null: no timer.
  final int? limitSeconds;
  final DateTime Function() _clock;

  final Map<int, ExamAnswer> _answers = {};
  final Set<int> _flags = {};
  int _index = 0;

  // Timer: in-app time only. [_used] is time banked before the current running stretch.
  bool _running;
  late DateTime _since;
  Duration _used = Duration.zero;
  bool _submitted = false;
  ExamResult? _result;

  int get total => items.length;
  int get index => _index;
  PoolItem get current => items[_index];
  bool get submitted => _submitted;
  ExamResult? get result => _result;

  void goTo(int i) {
    if (i >= 0 && i < total) _index = i;
  }

  void next() => goTo(_index + 1);
  void previous() => goTo(_index - 1);

  // ---- answers and flags ----------------------------------------------------------------

  ExamAnswer? answerAt(int i) => _answers[i];

  /// Stores the answer to question [i]; an empty answer clears it. Ignored once submitted.
  void setAnswer(int i, ExamAnswer a) {
    if (_submitted || i < 0 || i >= total) return;
    if (a.isEmpty) {
      _answers.remove(i);
    } else {
      _answers[i] = a;
    }
  }

  bool isAnswered(int i) => _answers.containsKey(i);
  bool isFlagged(int i) => _flags.contains(i);

  void toggleFlag(int i) {
    if (_submitted || i < 0 || i >= total) return;
    if (!_flags.remove(i)) _flags.add(i);
  }

  /// Question numbers (1-based) with no answer, for the submit confirmation.
  List<int> get unansweredNumbers => [
    for (var i = 0; i < total; i++)
      if (!isAnswered(i)) i + 1,
  ];

  List<int> get flaggedNumbers => [
    for (final i in _flags.toList()..sort()) i + 1,
  ];

  // ---- timer ----------------------------------------------------------------------------

  /// In-app time used so far (frozen while paused or after submit).
  Duration get elapsed =>
      _running ? _used + _clock().difference(_since) : _used;

  /// Seconds left, or null with no timer. Never below 0.
  int? get remainingSeconds {
    final l = limitSeconds;
    if (l == null) return null;
    return max(0, l - elapsed.inSeconds);
  }

  bool get timeUp => limitSeconds != null && elapsed.inSeconds >= limitSeconds!;

  /// The app went to the background: the countdown stops.
  void pause() {
    if (!_running) return;
    final d = _clock().difference(_since);
    _used += d.isNegative ? Duration.zero : d;
    _running = false;
  }

  void resume() {
    if (_running || _submitted) return;
    _since = _clock();
    _running = true;
  }

  // ---- scoring --------------------------------------------------------------------------

  static bool isCorrect(ContentItem item, ExamAnswer? a) {
    if (a == null || a.isEmpty) return false;
    switch (item.type) {
      case ItemType.mcq:
        return mcqIsCorrect(item, a.picked);
      case ItemType.numeric:
        final tol = numericFromJson(item.json['tolerance']) ?? 0;
        return isNumericAnswerCorrect(
          a.text ?? '',
          item.json['answer'] as Object,
          tolerance: tol,
        );
      default:
        return false;
    }
  }

  /// Ends the exam (idempotent) and scores it. Unanswered questions count as not correct in the
  /// score, but are never recorded as wrong answers.
  ExamResult submit() {
    final existing = _result;
    if (existing != null) return existing;
    final timedOut = timeUp;
    pause();
    _submitted = true;
    final review = <ExamReviewItem>[];
    final byTopic = <String, List<bool>>{};
    var correct = 0;
    for (var i = 0; i < total; i++) {
      final a = _answers[i];
      final ok = isCorrect(items[i].item, a);
      if (ok) correct++;
      review.add(
        ExamReviewItem(
          item: items[i],
          answer: a,
          answered: a != null,
          correct: ok,
          flagged: _flags.contains(i),
        ),
      );
      byTopic
          .putIfAbsent(
            topicKey(items[i].subject, items[i].year, items[i].topic),
            () => [],
          )
          .add(ok);
    }
    final keys = byTopic.keys.toList()..sort();
    return _result = ExamResult(
      items: review,
      correct: correct,
      seconds: _used.inSeconds,
      timedOut: timedOut,
      topics: [
        for (final k in keys)
          ExamTopicScore(
            key: k,
            questions: byTopic[k]!.length,
            correct: byTopic[k]!.where((b) => b).length,
          ),
      ],
    );
  }

  /// Progress after the answered questions are recorded like a quiz round (accuracy, passes,
  /// mistakes, box). No rewards are touched. Unanswered questions are skipped. Needs [submit].
  ChildProgress applyTo(ChildProgress progress, {required int day}) {
    final r = _result;
    if (r == null) throw StateError('Submit the exam first');
    var p = progress;
    for (final i in r.items) {
      if (!i.answered) continue;
      p = p.record(i.item, correct: i.correct, day: day);
    }
    return p;
  }

  ExamRecord toRecord({required int day}) {
    final r = _result;
    if (r == null) throw StateError('Submit the exam first');
    return ExamRecord(
      day: day,
      subject: subject,
      questions: r.total,
      correct: r.correct,
      seconds: r.seconds,
    );
  }
}
