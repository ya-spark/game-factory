import 'package:flutter/material.dart';
import 'package:game_core/engine/engine.dart';
import 'package:flutter_game_template/ui/tabs/topic_map_view.dart';
import 'package:flutter_game_template/ui/theme/app_theme.dart';
import 'package:flutter_game_template/ui/theme/design_scope.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kit/kit_test.dart' show FileDesignBundle, appIds, loadDesign;

PoolItem item(String id, String type) => PoolItem(
  item: ContentItem({
    'id': id,
    'type': type,
    'seq': 1,
    'difficulty': 1,
    'explanation': 'e',
  }),
  packId: 'p',
  subject: 'maths',
  year: 3,
  topic: 't',
);

MapNode node() => MapNode(
  subject: 'maths',
  year: 3,
  topic: 't',
  name: 'Patterns',
  state: MapNodeState.learning,
  passed: 1,
  total: 8,
  toRevise: 0,
  accuracyPercent: 50,
  reviseItems: const [],
  openItems: [
    for (var i = 0; i < 8; i++) item('i$i', i < 4 ? 'mcq' : 'series'),
  ],
);

Future<void> pumpSheet(
  WidgetTester tester,
  String id, {
  VoidCallback? onOther,
}) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final design = loadDesign(id);
  final mode = design.app.modes.keys.first;
  final level = design.app.levelForYear(3);
  await tester.pumpWidget(
    DefaultAssetBundle(
      bundle: FileDesignBundle(),
      child: MaterialApp(
        theme: buildDesignTheme(
          app: design.app,
          shared: design.shared,
          mode: mode,
          level: level,
        ),
        builder: (context, child) => DesignScope(
          design: design,
          mode: mode,
          level: level,
          child: child!,
        ),
        home: Scaffold(
          body: TopicMapSheet(
            node: node(),
            showAccuracy: true,
            onPractise: () {},
            onRevise: () {},
            onOther: onOther,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final id in appIds) {
    final design = loadDesign(id);
    if (design.app.modes.length < 2) continue;
    testWidgets(
      '$id: Other question types shows when the topic has some and runs',
      (tester) async {
        var tapped = 0;
        await pumpSheet(tester, id, onOther: () => tapped++);
        expect(find.text('Other question types'), findsOneWidget);
        await tester.tap(find.text('Other question types'));
        expect(tapped, 1);
      },
    );

    testWidgets('$id: no Other question types button without a callback', (
      tester,
    ) async {
      await pumpSheet(tester, id);
      expect(find.text('Other question types'), findsNothing);
      expect(find.text('Practise'), findsOneWidget);
    });
  }
}
