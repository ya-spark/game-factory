/// Flash review rules: cards for the child's mistakes and due items. The child flips a card
/// and says "I knew it" or "Not yet". Works with every item type. Pure Dart.
library;

import '../../../content/models.dart';
import '../../../content/numeric.dart';
import '../../quick_quiz.dart';

const String flashReviewId = 'flash_review';

final RegExp _gap = RegExp(r'\{\{(\d+)\}\}');

String _num(double v) =>
    v == v.roundToDouble() && v.abs() < 1e12 ? '${v.toInt()}' : '$v';

List<String> _strings(Object? v) =>
    v is List ? [for (final e in v) '$e'] : (v == null ? const [] : ['$v']);

/// The front of the card: what the child is asked.
String flashPrompt(ContentItem item) {
  final j = item.json;
  switch (item.type) {
    case ItemType.mcq:
    case ItemType.numeric:
      return '${j['prompt']}';
    case ItemType.series:
      return j['prompt'] == null
          ? 'Put these in order: ${_strings(j['steps']).join(', ')}'
          : '${j['prompt']}';
    case ItemType.pairs:
      final lefts = [
        for (final p in (j['pairs'] as List)) '${(p as Map)['left']}',
      ];
      return '${j['prompt'] ?? 'Match each pair'}\n${lefts.join(', ')}';
    case ItemType.word:
      return 'Spell the word. Hint: ${j['hint']}';
    case ItemType.category:
      final cats = _strings(j['categories']).join(', ');
      return '${j['prompt'] ?? 'Which group does each belong to?'}\n$cats';
    case ItemType.cloze:
      return '${j['text']}'.replaceAll(_gap, '___');
  }
}

/// The back of the card: the answer, as text.
String flashAnswer(ContentItem item) {
  final j = item.json;
  switch (item.type) {
    case ItemType.mcq:
      final options = mcqOptions(item);
      return [
        for (final i in (mcqCorrectIndexes(item).toList()..sort()))
          if (i >= 0 && i < options.length) options[i],
      ].join(', ');
    case ItemType.series:
      return _strings(j['steps']).join(', then ');
    case ItemType.pairs:
      return [
        for (final p in (j['pairs'] as List))
          '${(p as Map)['left']} goes with ${p['right']}',
      ].join('\n');
    case ItemType.word:
      return '${j['answer']}';
    case ItemType.category:
      return [
        for (final x in (j['items'] as List))
          '${(x as Map)['text']}: ${x['category']}',
      ].join('\n');
    case ItemType.numeric:
      final a = numericFromJson(j['answer']);
      final unit = j['unit'] == null ? '' : ' ${j['unit']}';
      return '${a == null ? j['answer'] : _num(a)}$unit';
    case ItemType.cloze:
      final gaps = (j['gaps'] as Map?) ?? const {};
      return '${j['text']}'.replaceAllMapped(_gap, (m) {
        final g = _strings(gaps[m.group(1)]);
        return g.isEmpty ? '___' : g.first;
      });
  }
}

/// A round of cards: how many were known and how many go back to the revise list.
class FlashReviewRun {
  int known = 0;
  int notYet = 0;

  void mark({required bool knew}) => knew ? known++ : notYet++;
  int get total => known + notYet;
}
