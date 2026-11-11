/// Tug-of-war quiz rules: a rope marker moves toward the child's side with each right answer
/// and back with a wrong or slow one. Pure Dart, random is injected.
library;

import 'dart:math';

import '../../../content/models.dart';
import '../../minigame_level.dart';
import '../../quick_quiz.dart';

const String tugOfWarId = 'tug_of_war';

/// Coins to unlock the game in the Craft apps.
const int tugOfWarCoinPrice = 200;

class TugSettings {
  const TugSettings({
    required this.reach,
    required this.secondsPerQuestion,
    required this.options,
    required this.pullsBack,
  });

  /// Steps from the middle to either end; the marker reaching an end finishes the round.
  final int reach;

  /// 0 means no timer.
  final int secondsPerQuestion;
  final int options;

  /// Younger: a wrong try never pulls the rope back.
  final bool pullsBack;

  factory TugSettings.forLevel(MiniGameLevel l) {
    if (!l.older) {
      return const TugSettings(
        reach: 3,
        secondsPerQuestion: 0,
        options: 2,
        pullsBack: false,
      );
    }
    return TugSettings(
      reach: l.harder ? 5 : 4,
      secondsPerQuestion: l.harder ? 12 : 20,
      options: l.harder ? 4 : 3,
      pullsBack: true,
    );
  }
}

class TugOption {
  const TugOption(this.label, this.correct);
  final String label;
  final bool correct;
}

/// The options for one `mcq` item: one right answer and up to [count] - 1 wrong ones, shuffled.
/// Null when the item cannot be played.
List<TugOption>? layoutTugOptions(ContentItem item, int count, Random random) {
  if (item.type != ItemType.mcq) return null;
  final options = mcqOptions(item);
  final right = mcqCorrectIndexes(item);
  if (right.isEmpty || options.length < 2) return null;
  if (right.any((i) => i < 0 || i >= options.length)) return null;
  final correct = right.toList()..shuffle(random);
  final wrong = [
    for (var i = 0; i < options.length; i++)
      if (!right.contains(i)) i,
  ]..shuffle(random);
  final n = min(max(2, count), options.length);
  final out = <TugOption>[
    TugOption(options[correct.first], true),
    for (final i in wrong.take(n - 1)) TugOption(options[i], false),
  ]..shuffle(random);
  return out.length < 2 ? null : out;
}

enum TugRoundEnd { none, won, lost }

/// The rope and the rounds. Position runs from `-reach` (the quiz's end) to `reach` (the
/// child's end); the first to the end wins the round and the rope returns to the middle.
class TugOfWarRun {
  TugOfWarRun(this.level) : settings = TugSettings.forLevel(level);
  final MiniGameLevel level;
  final TugSettings settings;

  int position = 0;
  int roundsWon = 0;
  int roundsLost = 0;
  TugRoundEnd lastEnd = TugRoundEnd.none;

  /// Moves the rope for one answer and says whether it ended a round. [correct] is false for a
  /// wrong or a slow answer.
  TugRoundEnd answer({required bool correct}) {
    lastEnd = TugRoundEnd.none;
    if (correct) {
      position++;
    } else if (settings.pullsBack) {
      position--;
    }
    if (position >= settings.reach) {
      roundsWon++;
      position = 0;
      lastEnd = TugRoundEnd.won;
    } else if (position <= -settings.reach) {
      roundsLost++;
      position = 0;
      lastEnd = TugRoundEnd.lost;
    }
    return lastEnd;
  }
}
