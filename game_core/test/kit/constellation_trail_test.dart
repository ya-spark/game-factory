import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

TrailNode node(int rung, SkillState s, {String topic = 'fractions'}) =>
    TrailNode(
      skill: Skill(
        id: '${topic}_$rung',
        subject: 'maths',
        year: 7,
        topic: topic,
        name: 'Rung $rung',
        seqFrom: 0,
        seqTo: 9,
        requires: const [],
        order: rung,
        rung: rung,
      ),
      state: s,
      openItems: 10,
      accuracy: null,
    );

Widget host(List<TrailNode> nodes, ValueChanged<TrailNode> tap, double w) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(w, 900)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: ConstellationTrail(nodes: nodes, onSelect: tap),
          ),
        ),
      ),
    );

void main() {
  final nodes = [
    node(0, SkillState.mastered),
    node(1, SkillState.practising),
    node(2, SkillState.locked),
    node(0, SkillState.unseen, topic: 'algebra'),
    node(1, SkillState.locked, topic: 'algebra'),
    node(2, SkillState.locked, topic: 'algebra'),
  ];

  testWidgets('one card per topic and a keyed star per rung', (t) async {
    await t.pumpWidget(host(nodes, (_) {}, 1200));
    expect(
      find.byKey(ConstellationIds.topicKeyOf('maths/7/fractions')),
      findsOne,
    );
    expect(
      find.byKey(ConstellationIds.topicKeyOf('maths/7/algebra')),
      findsOne,
    );
    expect(find.byKey(ConstellationIds.star('maths/7/fractions_1')), findsOne);
    expect(t.takeException(), isNull);
  });

  testWidgets('tap and keyboard select a rung; labels are spoken', (t) async {
    final got = <String>[];
    final h = t.ensureSemantics();
    await t.pumpWidget(host(nodes, (n) => got.add(n.key), 400));
    await t.tap(find.byKey(ConstellationIds.star('maths/7/fractions_1')));
    expect(got, ['maths/7/fractions_1']);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(got.length, 2);
    expect(
      find.bySemanticsLabel('Rung 0, mastered, 3 of 3 stars'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Rung 2, locked'), findsNWidgets(2));
    h.dispose();
  });

  testWidgets('arrow keys move focus between stars', (t) async {
    final got = <String>[];
    await t.pumpWidget(host(nodes, (n) => got.add(n.key), 1200));
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    expect(got, isNotEmpty);
    expect(got.last, isNot('maths/7/fractions_0'));
  });

  test('stars follow state', () {
    expect(node(0, SkillState.locked).stars, 0);
    expect(node(0, SkillState.mastered).stars, 3);
    expect(starSpots(3).length, 3);
  });
}
