/// Door runner door choice and score: one right door among wrong ones, seeded. Pure Dart.
library;

import 'dart:math';

import 'package:game_core/engine/engine.dart';

const String doorRunnerId = 'door_runner';

class Door {
  const Door(this.label, this.correct);
  final String label;
  final bool correct;
}

/// The doors for one question: one correct option and wrong ones, in a random order.
/// Returns null when the item has too few options.
List<Door>? layoutDoors(ContentItem item, int doors, Random random) {
  final options = mcqOptions(item);
  final right = mcqCorrectIndexes(item);
  if (right.isEmpty || options.length < 2) return null;
  final correct = right.toList()..shuffle(random);
  final wrong = [
    for (var i = 0; i < options.length; i++)
      if (!right.contains(i)) i,
  ]..shuffle(random);
  final n = min(doors, options.length);
  final picked = <Door>[
    Door(options[correct.first], true),
    for (final i in wrong.take(n - 1)) Door(options[i], false),
  ]..shuffle(random);
  return picked.length < 2 ? null : picked;
}

/// Score and streak of one run.
class DoorRunnerRun {
  DoorRunnerRun(this.level);
  final MiniGameLevel level;
  int score = 0;
  int streak = 0;
  int bestStreak = 0;
  int passed = 0;

  void right() {
    score += scoreForAnswer(streak: streak, older: level.older);
    streak++;
    passed++;
    if (streak > bestStreak) bestStreak = streak;
  }

  /// A wrong door or a timeout: the streak starts again; the score is never taken away.
  void miss() => streak = 0;
}
