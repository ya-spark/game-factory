/// Quick quiz: the reference minigame. Plain multiple choice (and true or false), free.
library;

import '../content/models.dart';
import '../content/progress.dart';

const String quickQuizId = 'quick_quiz';

/// True when the picked option indexes are exactly the item's correct ones.
bool mcqIsCorrect(ContentItem item, Set<int> picked) =>
    mcqCorrectIndexes(item).difference(picked).isEmpty &&
    picked.difference(mcqCorrectIndexes(item)).isEmpty;

Set<int> mcqCorrectIndexes(ContentItem item) {
  final c = item.json['correct'];
  return c is List ? {for (final i in c) i as int} : {c as int};
}

List<String> mcqOptions(ContentItem item) => [
  for (final o in (item.json['options'] as List)) '$o',
];

String mcqPrompt(ContentItem item) => item.json['prompt'] as String;

/// Items Quick quiz can play.
bool quickQuizPlays(PoolItem p) => p.item.type == ItemType.mcq;
