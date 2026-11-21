import 'dart:math';

import 'package:game_core/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

final topics = Topics.parse('''
maths:
  3:
    times_tables: A
    fractions: B
''');
final skills = SkillMap.parse('''
maths:
  3:
    times_tables:
      - {id: tt_1, name: Getting started, seq: [1, 6]}
      - {id: tt_2, name: Building up, seq: [7, 13]}
      - {id: tt_3, name: Stretch, seq: [14, 20]}
    fractions:
      - {id: fr_1, name: Getting started, seq: [1, 20]}
''', topics);

PoolItem item(
  int seq, {
  String topic = 'times_tables',
  String type = 'mcq',
  int options = 4,
}) {
  final s = skills.skillOf(
    'maths',
    3,
    topic,
    ContentItem({'seq': seq, 'id': 'x', 'type': type}),
  );
  return PoolItem(
    item: ContentItem({
      'id': '$topic.$seq',
      'seq': seq,
      'difficulty': 1,
      'type': type,
      'explanation': 'e',
      if (type == 'mcq') 'prompt': 'p',
      if (type == 'mcq') 'options': [for (var i = 0; i < options; i++) 'o$i'],
      if (type == 'mcq') 'correct': 0,
      if (type == 'series') 'prompt': 'p',
      if (type == 'series') 'steps': ['1', '2', '3'],
    }),
    packId: 'p',
    subject: 'maths',
    year: 3,
    topic: topic,
    skillKey: s!.key,
  );
}

MiniGame game(
  String id,
  Set<ItemType> types, {
  int minPool = 4,
  GameAccess access = GameAccess.freeWithAds,
  SizeAccept sizes = SizeAccept.any,
}) => MiniGame(
  id: id,
  title: id,
  itemTypes: types,
  build: (_) => Object(),
  minPool: minPool,
  access: access,
  sizes: sizes,
);

List<PoolItem> allOpen() => [
  for (var i = 1; i <= 20; i++) item(i),
  for (var i = 1; i <= 20; i++) item(i, topic: 'fractions'),
];

ChildProgress secureRung(String id, {int day = 1}) {
  const r = SkillRules.ranger;
  var sp = const SkillProgress();
  for (var i = 0; i < 10; i++) {
    sp = sp.add(
      SkillEvidence(correct: true, day: day + i % 2, format: 'mcq'),
      r,
    );
  }
  return ChildProgress(skills: {'maths/3/$id': sp});
}

List<TrailNode> build(ChildProgress p, List<PoolItem> open, {int today = 5}) =>
    Trail.build(
      subject: 'maths',
      year: 3,
      skills: skills,
      progress: p,
      open: open,
      rules: SkillRules.ranger,
      today: today,
    );

void main() {
  test('the rule follows the year', () {
    expect(SkillRules.forYear(0).window, 8);
    expect(SkillRules.forYear(6).minAccuracy, 0.75);
    expect(SkillRules.forYear(7).minAccuracy, 0.80);
    expect(SkillRules.forYear(10).window, 10);
    expect(SkillRules.forYear(11).minAccuracy, 0.85);
    expect(SkillRules.forYear(null).minAccuracy, 0.80);
  });

  group('Trail.build', () {
    test('the first rung is open, the rest are locked until the one before is secure', () {
      final n = build(const ChildProgress(), allOpen());
      expect(n.map((x) => x.state), [
        SkillState.unseen,
        SkillState.locked,
        SkillState.locked,
        SkillState.locked,
      ]);
      expect(n[0].openItems, 6);
      expect(n[0].canPractise, isTrue);
      expect(n[1].canPractise, isFalse);
    });

    test('a secure rung unlocks the next, and the next topic opens from the first rung', () {
      final n = build(secureRung('tt_1'), allOpen());
      expect(n[0].state, SkillState.secure);
      expect(n[0].stars, 2);
      expect(n[1].state, SkillState.unseen);
      expect(n[2].state, SkillState.locked);
      expect(
        n[3].state,
        SkillState.unseen,
        reason: 'first rung of the next topic',
      );
    });

    test('a rung secure by a skip-ahead check unlocks what follows', () {
      final p = SkipCheck.apply(
        const ChildProgress(),
        skills.byKey('maths/3/tt_3')!,
        skills,
        passed: true,
        day: 5,
        rules: SkillRules.ranger,
      );
      final n = build(p, allOpen());
      expect(n[0].state, SkillState.secure);
      expect(n[2].state, SkillState.secure);
      expect(n[3].state, SkillState.unseen);
    });

    test('a rung with no open items opens as you go', () {
      final open = [for (var i = 1; i <= 6; i++) item(i)];
      final n = build(secureRung('tt_1'), open);
      expect(n[1].opensAsYouGo, isTrue);
      expect(n[1].canPractise, isFalse);
    });
  });

  group('Auto', () {
    test('offers the first unlocked rung that is not secure', () {
      expect(
        Trail.autoRung(build(const ChildProgress(), allOpen()))!.skill.id,
        'tt_1',
      );
      expect(
        Trail.autoRung(build(secureRung('tt_1'), allOpen()))!.skill.id,
        'tt_2',
      );
    });

    test('with everything secure it offers the weakest secure rung', () {
      var p = secureRung('tt_1');
      for (final id in ['tt_2', 'tt_3', 'fr_1']) {
        p = p.copyWith(skills: {...p.skills, ...secureRung(id).skills});
      }
      final n = build(p, allOpen(), today: 6);
      expect(n.every((x) => x.state == SkillState.secure), isTrue);
      expect(Trail.autoRung(n), isNotNull);
    });

    test('nothing to offer when no rung has open items', () {
      expect(Trail.autoRung(build(const ChildProgress(), const [])), isNull);
    });

    test('the game is one that can play the rung, never a locked one', () {
      final reg = MiniGameRegistry([
        RegistryEntry(game('quiz', {ItemType.mcq})),
        RegistryEntry(game('paid', {ItemType.mcq}, access: GameAccess.coins)),
        RegistryEntry(game('series', {ItemType.series})),
      ]);
      final open = allOpen();
      final n = build(const ChildProgress(), open);
      final rung = open.where((p) => p.skillKey == n[0].key);
      final games = NextStep.gamesFor(
        registry: reg,
        rungItems: rung,
        year: 3,
        mode: MiniGameMode.game,
        unlocked: const {},
      );
      expect(games.map((g) => g.id), [
        'quiz',
        'paid',
      ], reason: 'free first; series has no items');
      final g = NextStep.autoGame(
        games,
        const ChildProgress(),
        const {},
        Random(1),
      );
      expect(g!.id, 'quiz');
    });

    test('the game played least is chosen', () {
      final a = game('a', {ItemType.mcq});
      final b = game('b', {ItemType.mcq});
      final p = ChildProgress(
        games: {'a': const GameStat(passed: 9), 'b': const GameStat(passed: 2)},
      );
      expect(NextStep.autoGame([a, b], p, const {}, Random(1))!.id, 'b');
    });

    test('size: an action game gets only short items', () {
      final longItem = PoolItem(
        item: ContentItem({
          'id': 'long.1',
          'seq': 1,
          'difficulty': 1,
          'type': 'mcq',
          'explanation': 'e',
          'prompt': 'p',
          'options': ['a' * 31, 'b', 'c'],
          'correct': 0,
        }),
        packId: 'p',
        subject: 'maths',
        year: 3,
        topic: 'times_tables',
        skillKey: 'maths/3/tt_1',
      );
      final action = game('act', {ItemType.mcq}, sizes: SizeAccept.shortOnly);
      final card = game('card', {ItemType.mcq});
      expect(action.canPlay(longItem), isFalse);
      expect(card.canPlay(longItem), isTrue);
    });
  });

  group('rounds', () {
    final quiz = game('quiz', {ItemType.mcq});
    final reg = MiniGameRegistry([RegistryEntry(quiz)]);

    test('a round holds items of the rung only, ten at most', () {
      final open = allOpen();
      final node = build(const ChildProgress(), open)[0];
      final r = NextStep.round(
        node: node,
        game: quiz,
        open: open,
        progress: const ChildProgress(),
        today: 5,
        random: Random(1),
      )!;
      expect(r.items.length, 6);
      expect(r.items.every((p) => p.skillKey == node.key), isTrue);
    });

    test(
      'due review items are added, at most two, only ones the game can play',
      () {
        final open = allOpen();
        // two older answered items in another rung, wrong, so they are due for review
        var p = const ChildProgress();
        for (final i in [7, 8, 9]) {
          p = p.record(
            open.firstWhere((x) => x.id == 'times_tables.$i'),
            correct: false,
            day: 1,
          );
        }
        final node = build(p, open)[0];
        final r = NextStep.round(
          node: node,
          game: quiz,
          open: open,
          progress: p,
          today: 5,
          random: Random(1),
        )!;
        expect(r.items.length, 6 + 2);
        expect(r.items.where((x) => x.skillKey != node.key).length, 2);
      },
    );

    test('Auto picks rung and game together', () {
      final open = allOpen();
      final nodes = build(const ChildProgress(), open);
      final r = NextStep.auto(
        nodes: nodes,
        registry: reg,
        open: open,
        progress: const ChildProgress(),
        mode: MiniGameMode.game,
        unlocked: const {},
        today: 5,
        random: Random(1),
      );
      expect(r!.skill.id, 'tt_1');
      expect(r.game.id, 'quiz');
    });

    test('pick a game: the rung it serves best', () {
      final open = allOpen();
      final series = game('series', {ItemType.series}, minPool: 3);
      final more = [
        ...open,
        for (var i = 1; i <= 4; i++) item(i + 6, type: 'series'),
      ];
      final nodes = build(secureRung('tt_1'), more);
      expect(NextStep.rungForGame(nodes, series, more)!.skill.id, 'tt_2');
      expect(
        NextStep.rungForGame(nodes, game('none', {ItemType.pairs}), more),
        isNull,
      );
    });

    test('the skip-ahead check needs 5 items with 3 or more options', () {
      final open = allOpen();
      final nodes = build(const ChildProgress(), open);
      final tt3 = nodes[2];
      final items = NextStep.checkItems(
        tt3,
        open,
        SkillRules.ranger,
        Random(1),
      );
      expect(items!.length, 5);
      expect(items.every((p) => p.skillKey == tt3.key), isTrue);
      final fewer = [
        for (final p in open)
          if (p.skillKey != tt3.key || p.item.seq < 18) p,
      ];
      expect(
        NextStep.checkItems(tt3, fewer, SkillRules.ranger, Random(1)),
        isNull,
      );
    });
  });
}
