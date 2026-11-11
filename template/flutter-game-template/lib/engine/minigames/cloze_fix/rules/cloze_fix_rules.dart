/// Cloze and grammar fix rules: choose the word that completes a sentence (`cloze` items) or
/// the corrected version of a sentence (`mcq` items about grammar). Pure Dart, random injected.
library;

import 'dart:math';

import '../../../content/models.dart';
import '../../../content/progress.dart';
import '../../minigame_level.dart';
import '../../quick_quiz.dart';

const String clozeFixId = 'cloze_fix';

class ClozeFixSettings {
  const ClozeFixSettings({
    required this.options,
    required this.secondsPerQuestion,
  });
  final int options;

  /// 0 means no timer.
  final int secondsPerQuestion;

  factory ClozeFixSettings.forLevel(MiniGameLevel l) => ClozeFixSettings(
    options: l.older ? 4 : 3,
    secondsPerQuestion: l.older ? (l.harder ? 15 : 25) : 0,
  );
}

final RegExp _gap = RegExp(r'\{\{\s*(\w+)\s*\}\}');

/// True when an `mcq` item is a grammar item: its topic or id says grammar or punctuation.
bool isGrammarItem(PoolItem p) {
  if (p.item.type != ItemType.mcq) return false;
  final k = '${p.topic} ${p.item.id}'.toLowerCase();
  return k.contains('grammar') || k.contains('punctuation');
}

/// Items the game plays: every `cloze` item and the grammar `mcq` items.
bool clozeFixPlays(PoolItem p) =>
    p.item.type == ItemType.cloze || isGrammarItem(p);

/// Accepted words for each gap number of a cloze item.
Map<String, List<String>> clozeGaps(ContentItem item) => {
  for (final e in (item.json['gaps'] as Map).entries)
    '${e.key}': [for (final w in (e.value as List)) '$w'],
};

/// One question: the text to show and the options.
class ClozeQuestion {
  const ClozeQuestion({
    required this.text,
    required this.options,
    required this.correct,
  });
  final String text;
  final List<String> options;

  /// Indexes in [options] that are right.
  final Set<int> correct;

  String get answer => options[correct.first];
}

/// The text with the first gap shown as a blank and the others filled with their first word.
String clozeDisplayText(ContentItem item) {
  final gaps = clozeGaps(item);
  final text = item.json['text'] as String;
  final firstKey = _gap.firstMatch(text)?.group(1);
  return text.replaceAllMapped(_gap, (m) {
    final k = m.group(1)!;
    if (k == firstKey) return '____';
    return gaps[k]?.first ?? '____';
  });
}

/// Builds the question for one item. For a `cloze` item the options are the first accepted word
/// of the first gap plus wrong words borrowed from other items' gaps. For a grammar `mcq`
/// item the options are the item's own. Null when the item cannot be used.
ClozeQuestion? buildCloze(
  PoolItem p,
  List<PoolItem> others,
  ClozeFixSettings s,
  Random random,
) {
  final item = p.item;
  if (item.type == ItemType.mcq) {
    if (!isGrammarItem(p)) return null;
    final opts = mcqOptions(item);
    final right = mcqCorrectIndexes(item);
    if (opts.length < 2 || right.isEmpty) return null;
    if (right.any((i) => i < 0 || i >= opts.length)) return null;
    return ClozeQuestion(text: mcqPrompt(item), options: opts, correct: right);
  }
  if (item.type != ItemType.cloze) return null;
  final text = item.json['text'] as String;
  final firstKey = _gap.firstMatch(text)?.group(1);
  if (firstKey == null) return null;
  final accepted = clozeGaps(item)[firstKey];
  if (accepted == null || accepted.isEmpty) return null;
  final right = accepted.first;
  final lower = {for (final w in accepted) w.toLowerCase()};
  final pool = <String>{};
  for (final o in others) {
    if (o.item.id == item.id || o.item.type != ItemType.cloze) continue;
    final t = o.item.json['text'] as String;
    final k = _gap.firstMatch(t)?.group(1);
    final w = k == null ? null : clozeGaps(o.item)[k];
    if (w == null) continue;
    for (final x in w) {
      if (!lower.contains(x.toLowerCase())) pool.add(x);
    }
  }
  final wrong = pool.toList()..shuffle(random);
  final opts = [right, ...wrong.take(s.options - 1)];
  if (opts.length < 2) return null;
  opts.shuffle(random);
  return ClozeQuestion(
    text: clozeDisplayText(item),
    options: opts,
    correct: {opts.indexOf(right)},
  );
}
