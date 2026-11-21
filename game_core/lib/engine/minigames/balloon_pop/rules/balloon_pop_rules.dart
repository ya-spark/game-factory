/// Balloon pop rules: balloons float up and the player pops the right one. Pure Dart.
library;

import 'dart:math';

import '../../../content/models.dart';
import '../../../content/numeric.dart';
import '../../minigame_level.dart';
import '../../quick_quiz.dart';

const String balloonPopId = 'balloon_pop';

class BalloonPopSettings {
  const BalloonPopSettings({
    required this.balloons,
    required this.secondsPerQuestion,
    required this.riseSeconds,
    required this.large,
  });
  final int balloons;

  /// Time to pop; 0 means no timer.
  final int secondsPerQuestion;

  /// Seconds a balloon takes to float up the screen.
  final double riseSeconds;
  final bool large;

  factory BalloonPopSettings.forLevel(MiniGameLevel l) {
    if (!l.older) {
      return const BalloonPopSettings(
        balloons: 3,
        secondsPerQuestion: 0,
        riseSeconds: 9,
        large: true,
      );
    }
    return BalloonPopSettings(
      balloons: l.harder ? 6 : 5,
      secondsPerQuestion: l.harder ? 15 : 25,
      riseSeconds: l.harder ? 5 : 7,
      large: false,
    );
  }
}

class Balloon {
  const Balloon(this.label, this.correct);
  final String label;
  final bool correct;
}

/// A number as shown on a balloon: whole numbers without a decimal point.
String formatNumber(double v) {
  if (v == v.roundToDouble() && v.abs() < 1e12) return v.toInt().toString();
  return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

/// The balloons for one question. `mcq`: the options. `numeric`: the answer plus nearby
/// numbers that are not equal to it (within the item's tolerance). Null when it cannot be built.
List<Balloon>? layoutBalloons(ContentItem item, int count, Random random) {
  if (item.type == ItemType.mcq) {
    final options = mcqOptions(item);
    final right = mcqCorrectIndexes(item);
    if (right.isEmpty || options.length < 2) return null;
    final correct = right.toList()..shuffle(random);
    final wrong = [
      for (var i = 0; i < options.length; i++)
        if (!right.contains(i)) i,
    ]..shuffle(random);
    final n = min(count, options.length);
    final out = <Balloon>[
      Balloon(options[correct.first], true),
      for (final i in wrong.take(n - 1)) Balloon(options[i], false),
    ]..shuffle(random);
    return out.length < 2 ? null : out;
  }
  if (item.type == ItemType.numeric) {
    final answer = numericFromJson(item.json['answer']);
    if (answer == null) return null;
    final tol = numericFromJson(item.json['tolerance']) ?? 0;
    final step = answer == answer.roundToDouble() ? 1.0 : 0.1;
    final shown = <String>{formatNumber(answer)};
    final out = <Balloon>[Balloon(formatNumber(answer), true)];
    var guard = 0;
    while (out.length < count && guard++ < 200) {
      final span = 1 + guard ~/ 8;
      final k = (1 + random.nextInt(3 * span)).toDouble();
      final v = answer + (random.nextBool() ? k : -k) * step;
      if (answer >= 0 && v < 0) continue;
      if (numbersMatch(v, answer, tolerance: tol)) continue;
      if (shown.add(formatNumber(v))) out.add(Balloon(formatNumber(v), false));
    }
    if (out.length < 2) return null;
    out.shuffle(random);
    return out;
  }
  return null;
}

/// The prompt of an `mcq` or `numeric` item.
String balloonPrompt(ContentItem item) => item.json['prompt'] as String;

/// Where balloon [i] of [n] sits across the screen (0 to 1), spread evenly.
double balloonLane(int i, int n) => (i + 0.5) / n;

/// The height (0 bottom, 1 top) of balloon [i] of [n] at [t] (0 to 1 of a rise), staggered so
/// they do not travel as a block. Balloons wrap round to the bottom.
double balloonHeight(int i, int n, double t) => (t + i / n) % 1.0;

class BalloonPopRun {
  BalloonPopRun(this.level);
  final MiniGameLevel level;
  int score = 0;
  int streak = 0;
  int passed = 0;

  void right() {
    score += scoreForAnswer(streak: streak, older: level.older);
    streak++;
    passed++;
  }

  void miss() => streak = 0;
}
