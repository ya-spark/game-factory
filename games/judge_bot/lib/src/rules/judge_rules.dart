/// Judge bot rules: a ticket shows a claim and the child judges it TRUE or FALSE. Claims are built
/// from `mcq` items (CONTENT_FORMAT has no true or false item type; native True/False items keep
/// their authored truth). Pure Dart: no Flutter import, the random source is injected.
/// Spec: `docs/SPEC.md`.
library;

import 'dart:math';

import 'package:game_core/engine/engine.dart';

/// The game's id, package suffix and the name the child sees (owner, 2026-11-22: id = title).
const String judgeBotId = 'judge_bot';
const String judgeBotTitle = 'Judge bot';

/// Streak bulbs on the robot's hat: one row of 5, then a gold row.
const int judgeBulbs = 5;

/// A right answer without an explanation moves on by itself after this long (older level only).
const Duration judgeAutoMove = Duration(milliseconds: 1200);

/// Older level: a right answer in the first half of the timer earns this extra, never needed to pass.
const int judgeFastBonus = 2;

/// The same verdict never comes more than this many times in a row.
const int judgeMaxRun = 3;

/// At most this many missed tickets are listed on the results screen.
const int judgeMaxReview = 3;

class JudgeSettings {
  const JudgeSettings({
    required this.secondsPerQuestion,
    required this.autoMove,
  });

  /// 0 means no timer.
  final int secondsPerQuestion;

  /// Whether a right answer with no explanation moves on by itself after [judgeAutoMove].
  final bool autoMove;

  bool get timed => secondsPerQuestion > 0;

  /// Younger: no timer. Older: 10 s a ticket. Hard (internal flag): 6 s. Study is never timed and
  /// never moves on by itself.
  factory JudgeSettings.forLevel(MiniGameLevel l, {bool study = false}) => study
      ? const JudgeSettings(secondsPerQuestion: 0, autoMove: false)
      : JudgeSettings(
          secondsPerQuestion: l.older ? (l.harder ? 6 : 10) : 0,
          autoMove: l.older,
        );
}

/// True when an answer given [elapsed] seconds into a [limit]-second timer is "fast" (first half).
bool isFastAnswer(double elapsed, int limit) =>
    limit > 0 && elapsed * 2 <= limit;

/// Score of one right answer: the shared gentle score plus the fast bonus.
int judgeScore({required int streak, required bool older, bool fast = false}) =>
    scoreForAnswer(streak: streak, older: older) + (fast ? judgeFastBonus : 0);

/// Skill evidence is light (owner, 2026-11-22): with two choices a lucky guess is half the time,
/// so a right answer counts for the skill only as the second or later right answer in a row (two
/// in a row make one pass). A wrong answer or a time up always counts, as everywhere.
bool countsAsSkillEvidence({
  required bool correct,
  required int streakBefore,
}) => !correct || streakBefore >= 1;

/// How many streak bulbs are lit, and whether the row is the gold one (a streak past 5).
({int lit, bool gold}) bulbsFor(int streak) => (
  lit: streak <= 0 ? 0 : ((streak - 1) % judgeBulbs) + 1,
  gold: streak > judgeBulbs,
);

/// The item as a ticket: [question] (small), [shown] (the claim, large) and what is right.
class Claim {
  const Claim({
    required this.question,
    required this.shown,
    required this.isTrue,
    required this.rightAnswer,
    required this.explanation,
    required this.feedback,
    this.derived = false,
    this.claimed,
  });

  /// The item's own question (for a native True/False item: the statement itself).
  final String question;

  /// The claim the child judges: the statement, "10 x 7 = 70?" or "The answer is: 70".
  final String shown;

  /// Whether the claim is true. The stamp shows this, not the child's pick.
  final bool isTrue;

  /// The item's right option text ("True" or "False" for a native item).
  final String rightAnswer;

  /// The item's explanation (may be empty).
  final String explanation;

  /// The verdict line: "True. 10 x 7 is 70." or "False. The claim was 63. 10 x 7 is 70.". It names
  /// the question's own words and never another question's.
  final String feedback;

  /// Built from an `mcq` item rather than authored as a statement.
  final bool derived;

  /// The option the ticket claims (derived claims only).
  final String? claimed;

  String get verdict => isTrue ? 'TRUE' : 'FALSE';
}

bool _isTrueWord(String s) => s.trim().toLowerCase() == 'true';

/// True when the item's two options are "True" and "False" (any case): the prompt already is the
/// statement.
bool isTrueFalseItem(ContentItem item) {
  if (item.type != ItemType.mcq) return false;
  final o = [for (final s in mcqOptions(item)) s.trim().toLowerCase()];
  return o.length == 2 && o.contains('true') && o.contains('false');
}

/// Whether [buildClaim] can make a ticket of the item (a right option, two options or more).
bool isClaimable(ContentItem item) {
  if (item.type != ItemType.mcq) return false;
  final options = mcqOptions(item);
  final right = mcqCorrectIndexes(item);
  if (right.isEmpty || options.length < 2) return false;
  return !right.any((i) => i < 0 || i >= options.length);
}

final RegExp _askExpr = RegExp(
  r"^(?:what is|what's|what’s|work out|calculate|find|solve)\s+(.+?)\s*[?.:]?\s*$",
  caseSensitive: false,
);
final RegExp _exprChars = RegExp(r'^[0-9\s.,+\-−x×÷*/()%$]+$');
final RegExp _hasOperator = RegExp(r'[0-9)]\s*[+\-−x×÷*/]\s*[0-9($]');
final RegExp _numberLike = RegExp(r'^\$?-?[0-9][0-9,]*(\.[0-9]+)?%?$');

/// The expression of a plain maths question ("What is 10 x 7?" gives "10 x 7"), else null.
String? _expression(String question, String option) {
  final m = _askExpr.firstMatch(question.trim());
  if (m == null) return null;
  final expr = m.group(1)!.trim();
  if (!_exprChars.hasMatch(expr) || !_hasOperator.hasMatch(expr)) return null;
  if (!_numberLike.hasMatch(option.trim())) return null;
  return expr;
}

String _stripEnd(String s) => s.trim().replaceFirst(RegExp(r'[?.!:\s]+$'), '');

/// The ticket for one `mcq` item. A native True/False item keeps its prompt and authored truth.
/// Any other item becomes a two-line claim: the right option (true) or one wrong option (false,
/// never equal to a right one), chosen by [wantTrue] (null: a coin flip). A false claim that
/// cannot be made (no distractor) falls back to the true claim. Null when the item cannot be used.
Claim? buildClaim(ContentItem item, Random random, {bool? wantTrue}) {
  if (!isClaimable(item)) return null;
  final options = mcqOptions(item);
  final right = mcqCorrectIndexes(item);
  final prompt = mcqPrompt(item);
  final explanation = item.explanation;
  if (isTrueFalseItem(item)) {
    final isTrue = _isTrueWord(options[right.first]);
    return Claim(
      question: prompt,
      shown: prompt,
      isTrue: isTrue,
      rightAnswer: isTrue ? 'True' : 'False',
      explanation: explanation,
      feedback: isTrue
          ? 'True. That statement is true.'
          : 'False. That statement is false.',
    );
  }
  final rightTexts = {for (final i in right) options[i].trim().toLowerCase()};
  final wrong = [
    for (var i = 0; i < options.length; i++)
      if (!right.contains(i) &&
          options[i].trim().isNotEmpty &&
          !rightTexts.contains(options[i].trim().toLowerCase()))
        i,
  ];
  final rightList = right.toList()..sort();
  final rightIdx = rightList[random.nextInt(rightList.length)];
  final rightText = options[rightIdx].trim();
  final isTrue = wrong.isEmpty || (wantTrue ?? random.nextBool());
  final claimed = isTrue
      ? rightText
      : options[wrong[random.nextInt(wrong.length)]].trim();
  final expr = _expression(prompt, rightText);
  final shown = expr != null ? '$expr = $claimed?' : 'The answer is: $claimed';
  final restated = expr != null
      ? '$expr is $rightText'
      : 'The answer to "${_stripEnd(prompt)}" is $rightText';
  return Claim(
    question: prompt,
    shown: shown,
    isTrue: isTrue,
    rightAnswer: rightText,
    explanation: explanation,
    feedback: isTrue
        ? 'True. $restated.'
        : 'False. The claim was $claimed. $restated.',
    derived: true,
    claimed: claimed,
  );
}

/// The planned truth of every ticket. [fixed] holds the authored truth of native items and null
/// for derived ones; the derived ones get 40 to 60 percent true and no verdict comes more than
/// [judgeMaxRun] times in a row (when the authored items allow it). Deterministic per seed.
List<bool> planVerdicts(List<bool?> fixed, Random random, {int tries = 400}) {
  final free = [
    for (var i = 0; i < fixed.length; i++)
      if (fixed[i] == null) i,
  ];
  final n = free.length;
  var lo = (0.4 * n).ceil();
  var hi = (0.6 * n).floor();
  if (lo > hi) lo = hi = (0.5 * n).round(); // 1, 3 or 6 tickets: no whole number fits
  List<bool>? best;
  var bestRun = 1 << 30;
  for (var t = 0; t < tries; t++) {
    final trues = lo + random.nextInt(hi - lo + 1);
    final picks = [for (var i = 0; i < n; i++) i < trues]..shuffle(random);
    final plan = [for (final f in fixed) f ?? true];
    for (var k = 0; k < n; k++) {
      plan[free[k]] = picks[k];
    }
    final run = longestRun(plan);
    if (run <= judgeMaxRun) return plan;
    if (run < bestRun) {
      bestRun = run;
      best = plan;
    }
  }
  return best ?? [for (final f in fixed) f ?? true];
}

/// The longest run of the same value in [v].
int longestRun(List<bool> v) {
  var best = 0, run = 0;
  bool? last;
  for (final x in v) {
    run = x == last ? run + 1 : 1;
    last = x;
    if (run > best) best = run;
  }
  return best;
}

/// Deals the tickets of one round: plans the verdicts once, then builds each claim on demand and
/// keeps it, so a ticket never changes once it has been dealt.
class ClaimDealer {
  ClaimDealer(this.items, Random random)
    : _random = random,
      _plan = planVerdicts([
        for (final it in items)
          isClaimable(it)
              ? (isTrueFalseItem(it)
                    ? _isTrueWord(mcqOptions(it)[mcqCorrectIndexes(it).first])
                    : null)
              : true,
      ], random);

  final List<ContentItem> items;
  final Random _random;
  final List<bool> _plan;
  final Map<int, Claim?> _dealt = {};

  /// The planned verdicts, in order (tests).
  List<bool> get plan => List.unmodifiable(_plan);

  Claim? claimAt(int index) => _dealt.putIfAbsent(
    index,
    () => index < 0 || index >= items.length
        ? null
        : buildClaim(items[index], _random, wantTrue: _plan[index]),
  );
}
