/// Door runner rules: the player chooses the door with the right answer. Pure Dart.
library;

import 'dart:math';

import '../../../content/models.dart';
import '../../minigame_level.dart';
import '../../quick_quiz.dart';

const String doorRunnerId = 'door_runner';

class DoorRunnerSettings {
  const DoorRunnerSettings({
    required this.doors,
    required this.secondsPerQuestion,
    required this.runSeconds,
    required this.retry,
    required this.streaks,
  });

  /// Doors per question.
  final int doors;

  /// Time to choose; 0 means no timer.
  final int secondsPerQuestion;

  /// Seconds the runner takes to reach the doors (the run animation).
  final double runSeconds;

  /// A wrong door can be tried again without the child failing the round.
  final bool retry;
  final bool streaks;

  factory DoorRunnerSettings.forLevel(MiniGameLevel l) {
    if (!l.older) {
      return const DoorRunnerSettings(
        doors: 2,
        secondsPerQuestion: 0,
        runSeconds: 3,
        retry: true,
        streaks: false,
      );
    }
    return DoorRunnerSettings(
      doors: l.harder ? 4 : 3,
      secondsPerQuestion: l.harder ? 12 : 20,
      runSeconds: l.harder ? 1.2 : 2,
      retry: false,
      streaks: true,
    );
  }
}

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
