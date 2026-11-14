import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

ContentItem _it(String id) => ContentItem({
  'id': id,
  'type': 'mcq',
  'seq': 1,
  'difficulty': 1,
  'explanation': 'e',
  'prompt': 'p',
  'options': ['a', 'b'],
  'correct': 0,
});

LoadedPack _pack(String topic, {int year = 3, String subject = 'maths'}) =>
    LoadedPack(
      ContentPack({
        'id': '${subject}_${year}_$topic',
        'version': 1,
        'lang': 'en',
        'subject': subject,
        'year': year,
        'topic': topic,
        'title': 'T $topic',
        'items': <Object>[],
      }),
    );

PoolItem _p(String id, String topic, {int year = 3}) => PoolItem(
  item: _it(id),
  packId: 'p',
  subject: 'maths',
  year: year,
  topic: topic,
);

const _yaml = '''
maths:
  3:
    zeta: Zeta
    alpha: Alpha
    mid: Middle
    unused: Unused
  4:
    other: Other
english:
  3:
    words: Words
''';

void main() {
  final topics = Topics.parse(_yaml);
  final packs = [_pack('alpha'), _pack('mid'), _pack('zeta')];

  List<MapNode> build({
    List<PoolItem> open = const [],
    ChildProgress progress = const ChildProgress(),
    int today = 10,
    bool spaced = true,
    Topics? t,
  }) => TopicMap.build(
    subject: 'maths',
    year: 3,
    packs: packs,
    open: open,
    progress: progress,
    today: today,
    topics: t ?? topics,
    spaced: spaced,
  );

  test('Topics keeps the file order (the teaching order)', () {
    expect(topics.orderFor('maths', 3), ['zeta', 'alpha', 'mid', 'unused']);
    expect(topics.orderFor('maths', 9), isEmpty);
  });

  test('nodes follow the file order; topics without a pack are not shown', () {
    expect([for (final n in build()) n.topic], ['zeta', 'alpha', 'mid']);
    final noFile = TopicMap.build(
      subject: 'maths',
      year: 3,
      packs: packs,
      open: const [],
      progress: const ChildProgress(),
      today: 10,
    );
    expect([for (final n in noFile) n.topic], ['alpha', 'mid', 'zeta']);
  });

  test('a topic with no open items is "not open yet" and never revises', () {
    final n = build(open: [_p('a1', 'alpha')]);
    expect(n[0].state, MapNodeState.notOpen);
    expect(n[0].stateLabel, 'Opens as you go');
    expect(n[0].pips, 0);
    expect(n[1].isOpen, isTrue);
    expect(n[1].total, 1);
  });

  test('node states follow masteryOf', () {
    final items = [for (var i = 0; i < 10; i++) _p('a$i', 'alpha')];
    var prog = const ChildProgress();
    MapNode alpha() => build(open: items, progress: prog)[1];
    expect(alpha().state, MapNodeState.learning);
    for (var i = 0; i < 5; i++) {
      prog = prog.record(items[i], correct: true, day: 5);
    }
    expect(alpha().state, MapNodeState.gettingThere);
    expect(alpha().passed, 5);
    for (var i = 5; i < 10; i++) {
      prog = prog.record(items[i], correct: true, day: 5);
    }
    expect(alpha().state, MapNodeState.mastered);
    expect(alpha().pips, 3);
    expect(alpha().accuracyPercent, 100);
  });

  test('revise counts mistakes plus due items, each item once', () {
    final items = [for (var i = 0; i < 4; i++) _p('a$i', 'alpha')];
    final prog = const ChildProgress()
        .record(items[0], correct: false, day: 10) // mistake, not due
        .record(items[1], correct: true, day: 5) // box 1, due after 1 day
        .record(items[2], correct: true, day: 10); // not due
    expect(build(open: items, progress: prog)[1].toRevise, 2);
    expect(build(open: items, progress: prog, spaced: false)[1].toRevise, 1);
    expect(build(open: items, progress: prog, today: 5)[1].toRevise, 1);
    expect(build(open: items, progress: prog)[1].reviseItems.length, 2);
  });

  test('years and subjects list only built-in content', () {
    final all = [
      ..._packs(),
      LoadedPack(
        ContentPack({
          'id': 'x',
          'version': 1,
          'lang': 'en',
          'subject': 'maths',
          'year': 11,
          'topic': 'e',
          'title': 'e',
          'product_id': 'pack_x',
          'items': <Object>[],
        }),
      ),
    ];
    expect(TopicMap.years(all), [3, 4]);
    expect(TopicMap.subjects(all, 3), ['maths', 'english']);
    expect(TopicMap.subjects(all, 4), ['maths']);
  });
}

List<LoadedPack> _packs() => [
  _pack('alpha'),
  _pack('other', year: 4),
  _pack('words', subject: 'english'),
];
