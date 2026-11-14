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

PoolItem _item(String id, int year, String topic) => PoolItem(
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
  packId: 'pk_$topic',
  subject: 'maths',
  year: year,
  topic: topic,
);

LoadedPack _pack(int year, String topic, String title) => LoadedPack(
  ContentPack({
    'id': 'maths_${year}_$topic',
    'version': 1,
    'lang': 'en',
    'subject': 'maths',
    'year': year,
    'topic': topic,
    'title': title,
    'items': <Object>[],
  }),
);

MiniGame _game(String id) => MiniGame(
  id: id,
  title: 'Game $id',
  itemTypes: const {ItemType.mcq},
  build: (_) => const SizedBox(),
);

Future<void> _pump(WidgetTester tester, String id, int year) async {
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 1.5;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final s = await buildFakeServices(contentEnabled: true);
  final kid = (await s.profile.addChild('Mia', year: year))!;
  // "zed" is taught first, "fractions" second, "shapes" has no open items.
  final zed = [for (var i = 0; i < 4; i++) _item('z$i', year, 'zed')];
  final fr = [for (var i = 0; i < 4; i++) _item('f$i', year, 'fractions')];
  var progress = const ChildProgress()
      .record(fr[0], correct: true)
      .record(fr[1], correct: false);
  progress = progress.record(zed[0], correct: true);
  await s.profile.setChildProgress(kid.id, progress);
  await s.profile.setChildMode(kid.id, LearnMode.study);
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
              openItems: (_) async => [...zed, ...fr],
              packs: () async => [
                _pack(year, 'fractions', 'Fractions'),
                _pack(year, 'shapes', 'Shapes'),
                _pack(year, 'zed', 'Zed'),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(TestIds.mapEntry));
  await tester.pumpAndSettle();
}

void main() {
  for (final id in appIds) {
    final design = loadDesign(id);
    if (design.app.modes.length < 2) continue;
    testWidgets('$id: Map page lists topics, states and the sheet', (
      tester,
    ) async {
      await _pump(tester, id, 3);
      expect(find.byKey(TestIds.mapTab), findsOneWidget);
      expect(find.byKey(TestIds.mapYear(3)), findsOneWidget);
      expect(find.byKey(TestIds.mapSubject('maths')), findsOneWidget);
      final fr = topicKey('maths', 3, 'fractions');
      final sh = topicKey('maths', 3, 'shapes');
      // No topics.yaml in the test bundle: the order falls back to the topic id.
      expect(
        find.bySemanticsLabel(
          RegExp(r'Topic 1 of 3: Fractions, .*1 to revise'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(TestIds.mapRevise(fr)), findsOneWidget);
      expect(find.byKey(TestIds.mapPips(fr)), findsOneWidget);
      expect(find.byKey(TestIds.mapPips(sh)), findsNothing);
      expect(find.text('Opens as you go'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // A topic that is not open yet only explains.
      await tester.tap(find.byKey(TestIds.mapNode(sh)));
      await tester.pumpAndSettle();
      expect(find.byKey(TestIds.mapSheetClosed), findsOneWidget);
      expect(find.byKey(TestIds.dsButton('map.practise')), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      // An open topic shows progress, accuracy (not in Scout) and both buttons.
      await tester.tap(find.byKey(TestIds.mapNode(fr)));
      await tester.pumpAndSettle();
      expect(find.byKey(TestIds.mapSheet), findsOneWidget);
      expect(find.text('1 of 4 passed'), findsOneWidget);
      expect(
        find.text('50% correct'),
        design.app.showsAccuracy ? findsOneWidget : findsNothing,
      );
      expect(find.byKey(TestIds.dsButton('map.practise')), findsOneWidget);
      expect(find.byKey(TestIds.dsButton('map.revise')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
