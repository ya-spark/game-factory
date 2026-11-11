import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

PoolItem _item(String id, {String topic = 't'}) => PoolItem(
  item: ContentItem({
    'id': id,
    'type': 'mcq',
    'seq': 1,
    'difficulty': 1,
    'explanation': 'e',
    'prompt': 'p',
    'options': ['a', 'b'],
    'correct': 0,
  }),
  packId: 'pk',
  subject: 'maths',
  year: 3,
  topic: topic,
);

void main() {
  test('mastery follows the rule in design/tokens.json', () {
    Mastery m(int passed, int answers, int correct) => masteryOf(
      passed: passed,
      total: 10,
      answers: answers,
      correct: correct,
    );
    expect(m(9, 10, 8), Mastery.mastered);
    expect(m(9, 10, 7), Mastery.gettingThere); // passed enough, accuracy low
    expect(m(3, 10, 10), Mastery.learning);
    expect(m(5, 10, 5), Mastery.gettingThere);
    expect(
      masteryOf(passed: 0, total: 0, answers: 0, correct: 0),
      Mastery.learning,
    );
  });

  test('topic accuracy, per-game stats and try-next survive a round trip', () {
    var p = const ChildProgress();
    p = p.record(_item('a'), correct: true, gameId: 'quick_quiz');
    p = p.record(_item('b'), correct: false, gameId: 'quick_quiz');
    p = p.record(_item('c', topic: 'u'), correct: false);
    p = p.recordScore('quick_quiz', 40).recordScore('quick_quiz', 25);
    expect(p.topics[topicKey('maths', 3, 't')]!.accuracy, 0.5);
    expect(p.games['quick_quiz']!.passed, 1);
    expect(p.games['quick_quiz']!.best, 40);
    final back = ChildProgress.fromJson(p.toJson());
    expect(back.topics[topicKey('maths', 3, 't')]!.answers, 2);
    expect(back.games['quick_quiz']!.best, 40);
    final pool = [
      _item('a'),
      _item('b'),
      _item('c', topic: 'u'),
      _item('d', topic: 'u'),
    ];
    // b (topic t) and c (topic u) are wrong, one each: ties go to the smaller key.
    expect(p.topicToRevise(pool: pool), topicKey('maths', 3, 't'));
    p = p.record(_item('d', topic: 'u'), correct: false);
    expect(p.topicToRevise(pool: pool), topicKey('maths', 3, 'u'));
    expect(const ChildProgress().topicToRevise(), isNull);
  });
}
