import 'package:flutter/material.dart';
import 'package:flutter_game_template/core/services.dart';
import 'package:game_core/engine/engine.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_game_template/ui/theme/app_theme.dart';
import 'package:flutter_game_template/ui/theme/design_scope.dart';
import 'package:flutter_game_template/ui/trail_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';
import 'kit/kit_test.dart' show FileDesignBundle, appIds, loadDesign;

final topics = Topics.parse('''
maths:
  3:
    times_tables: Times tables
    fractions: Fractions
''');
final skills = SkillMap.parse('''
maths:
  3:
    times_tables:
      - {id: tt_1, name: Getting started, seq: [1, 6]}
      - {id: tt_2, name: Building up, seq: [7, 13]}
      - {id: tt_3, name: Stretch, seq: [14, 20]}
    fractions:
      - {id: fr_1, name: First steps, seq: [1, 20]}
''', topics);

PoolItem item(String topic, int seq) {
  final base = ContentItem({
    'id': '$topic.$seq',
    'seq': seq,
    'difficulty': 1,
    'type': 'mcq',
    'explanation': 'e',
    'prompt': 'p',
    'options': ['a', 'b', 'c', 'd'],
    'correct': 0,
  });
  return PoolItem(
    item: base,
    packId: 'p_$topic',
    subject: 'maths',
    year: 3,
    topic: topic,
    skillKey: skills.skillOf('maths', 3, topic, base)!.key,
  );
}

MiniGame fakeGame() => MiniGame(
  id: 'fake_quiz',
  title: 'Fake quiz',
  itemTypes: const {ItemType.mcq},
  build: (_) => const SizedBox(key: Key('fake.game')),
);

Future<void> pump(
  WidgetTester tester,
  String id, {
  required List<PoolItem> open,
  ChildProgressSetup? setup,
}) async {
  tester.view.physicalSize = const Size(420, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = await buildFakeServices(contentEnabled: true);
  final kid = (await s.profile.addChild('Mia', year: 3))!;
  if (setup != null) await s.profile.setChildProgress(kid.id, setup());
  s.profile.selectChild(kid.id);
  final design = loadDesign(id);
  final mode = design.app.modes.keys.first;
  await tester.pumpWidget(
    DefaultAssetBundle(
      bundle: FileDesignBundle(),
      child: ServicesScope(
        services: s,
        child: MaterialApp(
          theme: buildDesignTheme(
            app: design.app,
            shared: design.shared,
            mode: mode,
            level: design.app.levelForYear(3),
          ),
          builder: (context, child) => DesignScope(
            design: design,
            mode: mode,
            level: design.app.levelForYear(3),
            child: child!,
          ),
          home: TrailScreen(
            child: s.profile.children.first,
            registry: MiniGameRegistry([RegistryEntry(fakeGame())]),
            mode: MiniGameMode.game,
            loader: () async => TrailData(skills, open, const []),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

typedef ChildProgressSetup = ChildProgress Function();

List<PoolItem> allOpen() => [
  for (var i = 1; i <= 20; i++) item('times_tables', i),
  for (var i = 1; i <= 20; i++) item('fractions', i),
];

ChildProgress secureFirst() {
  const r = SkillRules.scout;
  var sp = const SkillProgress();
  for (var i = 0; i < 8; i++) {
    sp = sp.add(SkillEvidence(correct: true, day: 1 + i % 2, format: 'mcq'), r);
  }
  return ChildProgress(skills: {'maths/3/tt_1': sp});
}

void main() {
  for (final id in appIds) {
    final design = loadDesign(id);
    if (design.app.modes.length < 2) continue;

    testWidgets('$id: the trail lists rungs, locks and stars', (tester) async {
      await pump(tester, id, open: allOpen());
      expect(find.byKey(TestIds.trailScreen), findsOneWidget);
      expect(find.byKey(TestIds.trailNode('maths/3/tt_1')), findsOneWidget);
      expect(find.byKey(TestIds.trailNode('maths/3/tt_2')), findsOneWidget);
      expect(find.byKey(TestIds.trailNode('maths/3/fr_1')), findsOneWidget);
      expect(find.text('Opens when the step before is done'), findsWidgets);
      expect(find.byKey(TestIds.trailContinue), findsOneWidget);
    });

    testWidgets('$id: a secure rung shows two stars and unlocks the next', (
      tester,
    ) async {
      await pump(tester, id, open: allOpen(), setup: secureFirst);
      final stars = find.descendant(
        of: find.byKey(TestIds.trailStars('maths/3/tt_1')),
        matching: find.byIcon(Icons.star),
      );
      expect(stars, findsNWidgets(2));
      expect(find.text('Secure'), findsOneWidget);
      // tt_2 is now ready, tt_3 is still locked
      await tester.tap(find.byKey(TestIds.trailNode('maths/3/tt_2')));
      await tester.pumpAndSettle();
      expect(find.byKey(TestIds.trailSheet), findsOneWidget);
      final practise = tester.widget<FilledButton>(
        find.byKey(TestIds.trailPractise),
      );
      expect(practise.onPressed, isNotNull);
    });

    testWidgets(
      '$id: a locked rung cannot be practised; skip ahead is offered',
      (tester) async {
        await pump(tester, id, open: allOpen());
        await tester.tap(find.byKey(TestIds.trailNode('maths/3/tt_3')));
        await tester.pumpAndSettle();
        final practise = tester.widget<FilledButton>(
          find.byKey(TestIds.trailPractise),
        );
        expect(practise.onPressed, isNull);
        expect(find.byKey(TestIds.trailSkip), findsOneWidget);
      },
    );

    testWidgets('$id: Continue starts a round in a game that fits', (
      tester,
    ) async {
      await pump(tester, id, open: allOpen());
      await tester.tap(find.byKey(TestIds.trailContinue));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fake.game')), findsOneWidget);
    });

    testWidgets('$id: nothing open means nothing to continue with', (
      tester,
    ) async {
      await pump(tester, id, open: const []);
      final cont = tester.widget<FilledButton>(
        find.byKey(TestIds.trailContinue),
      );
      expect(cont.onPressed, isNull);
      expect(find.text('Opens as you go'), findsWidgets);
    });
  }
}
