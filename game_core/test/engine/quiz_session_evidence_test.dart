import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';

QuizSession _session() {
  final item = ContentItem({
    'id': 'q.1',
    'seq': 1,
    'difficulty': 1,
    'type': 'mcq',
    'explanation': 'e',
    'prompt': 'p',
    'options': ['a', 'b'],
    'correct': 0,
  });
  final p = PoolItem(
    item: item,
    packId: 'q',
    subject: 'maths',
    year: 3,
    topic: 't',
    skillKey: 'maths/3/a',
  );
  return QuizSession(
    items: [p],
    progress: const ChildProgress(),
    packs: const [],
    rewardsConfig: const RewardsConfig(),
    today: 100,
  );
}

void main() {
  test('skillEvidence false records the item but adds no skill evidence (Judge bot)', () {
    final light = _session();
    final r = light.answer(correct: true, skillEvidence: false);
    expect(r.correct, isTrue);
    expect(light.progress.items['q.1']!.passed, isTrue);
    expect(light.progress.skills, isEmpty);
    final normal = _session()..answer(correct: true);
    expect(normal.progress.skills['maths/3/a']!.evidence, hasLength(1));
  });
}
