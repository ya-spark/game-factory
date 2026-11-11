/// True or false rules: a statement appears and the child says whether it is true. Built from
/// `mcq` items (CONTENT_FORMAT has no true or false item type). Pure Dart, random is injected.
library;

import 'dart:math';

import '../../../content/models.dart';
import '../../minigame_level.dart';
import '../../quick_quiz.dart';

const String trueFalseId = 'true_false';

class TrueFalseSettings {
  const TrueFalseSettings({required this.secondsPerQuestion});

  /// 0 means no timer.
  final int secondsPerQuestion;

  factory TrueFalseSettings.forLevel(MiniGameLevel l) =>
      TrueFalseSettings(secondsPerQuestion: l.older ? (l.harder ? 6 : 10) : 0);
}

class Statement {
  const Statement(this.text, this.isTrue);
  final String text;
  final bool isTrue;
}

/// True when the item's two options are "True" and "False" (any case): the prompt already is
/// the statement.
bool isTrueFalseItem(ContentItem item) {
  if (item.type != ItemType.mcq) return false;
  final o = [for (final s in mcqOptions(item)) s.trim().toLowerCase()];
  return o.length == 2 && o.contains('true') && o.contains('false');
}

/// The statement for one `mcq` item. A True/False item keeps its prompt and answer. Any other
/// item pairs the question with the right answer (a true statement) or a wrong one (false),
/// chosen at random. Null when the item cannot be used.
Statement? buildStatement(ContentItem item, Random random) {
  if (item.type != ItemType.mcq) return null;
  final options = mcqOptions(item);
  final right = mcqCorrectIndexes(item);
  if (right.isEmpty || options.length < 2) return null;
  if (right.any((i) => i < 0 || i >= options.length)) return null;
  final prompt = mcqPrompt(item);
  if (isTrueFalseItem(item)) {
    final isTrue = options[right.first].trim().toLowerCase() == 'true';
    return Statement(prompt, isTrue);
  }
  final wrong = [
    for (var i = 0; i < options.length; i++)
      if (!right.contains(i)) i,
  ];
  final useTrue = wrong.isEmpty || random.nextBool();
  final i = useTrue
      ? (right.toList()..shuffle(random)).first
      : wrong[random.nextInt(wrong.length)];
  return Statement('$prompt Answer: ${options[i]}', useTrue);
}
