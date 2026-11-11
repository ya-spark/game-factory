import 'package:flutter/material.dart';
import 'package:flutter_game_template/core/profile/child_profile.dart';
import 'package:flutter_game_template/core/services.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_game_template/ui/app_shell.dart';
import 'package:flutter_game_template/ui/tabs/tab_data.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_game_template/ui/theme/app_theme.dart';
import 'package:flutter_game_template/ui/theme/design_scope.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';
import 'kit/kit_test.dart' show FileDesignBundle, appIds, loadDesign;

PoolItem _item(String id, int year, {String pack = 'pk'}) => PoolItem(
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
  packId: pack,
  subject: 'maths',
  year: year,
  topic: 'Fractions',
);

final _extraPack = LoadedPack(
  ContentPack({
    'id': 'extra1',
    'version': 1,
    'lang': 'en',
    'subject': 'maths',
    'year': 3,
    'topic': 'Extra',
    'title': 'Extra fractions',
    'product_id': 'pack_extra1',
    'items': <Object>[],
  }),
  previewOnly: true,
);

MiniGame _game(String id) => MiniGame(
  id: id,
  title: 'Game $id',
  itemTypes: const {ItemType.mcq},
  build: (_) => const SizedBox(),
);

/// Pumps the shell for the design [id] on the Study tab [tab] (null: stay on Game mode).
Future<void> _pump(
  WidgetTester tester,
  String id,
  int year, {
  String? tab,
}) async {
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 1.5;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final s = await buildFakeServices(contentEnabled: true);
  final kid = (await s.profile.addChild('Mia', year: year))!;
  final items = [for (var i = 0; i < 6; i++) _item('i$i', year)];
  // One right and one wrong answer: accuracy 50 percent and one item to revise.
  final progress = const ChildProgress()
      .record(items[0], correct: true)
      .record(items[1], correct: false);
  await s.profile.setChildProgress(kid.id, progress);
  if (tab != null) await s.profile.setChildMode(kid.id, LearnMode.study);
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
            level: design.app.levelForYear(year),
          ),
          builder: (context, child) => DesignScope(
            design: design,
            mode: mode,
            level: design.app.levelForYear(year),
            child: child!,
          ),
          home: AppShell(
            registry: MiniGameRegistry([RegistryEntry(_game('g'))]),
            loaders: TabLoaders(
              openItems: (_) async => [
                ...items,
                _item('x1', year, pack: 'extra1'),
              ],
              packs: () async => [_extraPack],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (tab != null) {
    await tester.tap(find.byKey(TestIds.dsTab(TestIds.shellBottomBar, tab)));
    await tester.pumpAndSettle();
  }
}

void main() {
  for (final id in appIds) {
    final design = loadDesign(id);
    if (design.app.modes.length < 2) {
      testWidgets('$id: the Mind home has no mode toggle', (tester) async {
        await _pump(tester, id, 3);
        expect(find.byKey(TestIds.playTab), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);
        expect(find.byKey(TestIds.modeToggle), findsNothing);
        expect(find.byKey(TestIds.dsSuggestedCard('next')), findsOneWidget);
        expect(find.byKey(TestIds.playGame('g')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
      continue;
    }
    for (final year in [1, 3, 8, 9]) {
      testWidgets('$id year $year: Study tabs build, no overflow', (
        tester,
      ) async {
        await _pump(tester, id, year, tab: 'learn');
        expect(find.byKey(TestIds.learnTab), findsOneWidget);
        expect(find.byKey(TestIds.learnGoal), findsOneWidget);
        final key = topicKey('maths', year, 'Fractions');
        expect(find.byKey(TestIds.dsTopicCard(key)), findsOneWidget);
        // Accuracy only where the design allows it.
        expect(
          find.text('50% correct'),
          design.app.showsAccuracy ? findsOneWidget : findsNothing,
        );
        // Pack cards: no price, only the locked "Full pack".
        await tester.scrollUntilVisible(
          find.byKey(TestIds.dsPackCard('extra1')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Full pack'), findsOneWidget);
        expect(find.textContaining(RegExp(r'[$£€]')), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.tap(
          find.byKey(TestIds.dsTab(TestIds.shellBottomBar, 'progress')),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(TestIds.progressTab), findsOneWidget);
        expect(find.byKey(TestIds.progressTopic(key)), findsOneWidget);
        expect(find.textContaining('still to pass'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(
          find.byKey(TestIds.dsTab(TestIds.shellBottomBar, 'revise')),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(TestIds.reviseTab), findsOneWidget);
        expect(find.byKey(TestIds.reviseTopic(key)), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp('1 to revise')), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
