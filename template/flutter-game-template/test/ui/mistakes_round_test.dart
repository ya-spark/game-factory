import 'package:flutter/material.dart';
import 'package:flutter_game_template/core/profile/child_profile.dart';
import 'package:flutter_game_template/core/services.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_game_template/ui/app_shell.dart';
import 'package:flutter_game_template/ui/quick_quiz_screen.dart';
import 'package:flutter_game_template/ui/tabs/tab_data.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_game_template/ui/theme/app_theme.dart';
import 'package:flutter_game_template/ui/theme/design_scope.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';
import 'kit/kit_test.dart' show FileDesignBundle, loadDesign;

PoolItem _item(String id, int year) => PoolItem(
  item: ContentItem({
    'id': id,
    'type': 'mcq',
    'seq': 1,
    'difficulty': 1,
    'explanation': 'e',
    'prompt': 'Prompt $id',
    'options': ['a', 'b'],
    'correct': 0,
  }),
  packId: 'pk',
  subject: 'maths',
  year: year,
  topic: 'Fractions',
);

/// Pumps the shell with [wrong] items answered wrongly; [study] opens the Revise page, else
/// Game mode stays on Play.
Future<ServicesFake> _pump(
  WidgetTester tester,
  String id, {
  required int wrong,
  bool study = false,
}) async {
  const year = 3;
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = await buildFakeServices(contentEnabled: true);
  final kid = (await s.profile.addChild('Mia', year: year))!;
  final items = [for (var i = 0; i < 6; i++) _item('i$i', year)];
  var progress = const ChildProgress();
  for (var i = 0; i < wrong; i++) {
    progress = progress.record(items[i], correct: false);
  }
  await s.profile.setChildProgress(kid.id, progress);
  if (study) await s.profile.setChildMode(kid.id, LearnMode.study);
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
            registry: MiniGameRegistry([RegistryEntry(quickQuizGame)]),
            loaders: TabLoaders(
              openItems: (_) async => items,
              packs: () async => const [],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (study) {
    await tester.tap(
      find.byKey(TestIds.dsTab(TestIds.shellBottomBar, 'revise')),
    );
    await tester.pumpAndSettle();
  }
  return s;
}

typedef ServicesFake = Services;

void main() {
  for (final id in ['craft_lowteen', 'craft_preteen', 'craft_highteen']) {
    final design = loadDesign(id);
    if (design.app.modes.length < 2) continue;
    final flash = design.app.practisesWithFlashCards;

    testWidgets('$id: Game mode entry is hidden at 0 mistakes', (tester) async {
      await _pump(tester, id, wrong: 0);
      expect(find.byKey(TestIds.mistakesEntry), findsNothing);
    });

    testWidgets('$id: Game mode entry shows the count and no price', (
      tester,
    ) async {
      await _pump(tester, id, wrong: 3);
      expect(find.byKey(TestIds.mistakesEntry), findsOneWidget);
      expect(find.text('3 to practise'), findsOneWidget);
      expect(find.textContaining('coin'), findsNothing);
    });

    testWidgets('$id: Study Revise shows the empty state at 0', (tester) async {
      await _pump(tester, id, wrong: 0, study: true);
      expect(find.byKey(TestIds.mistakesEmpty), findsOneWidget);
      expect(find.text('Nothing to practise. Great work!'), findsOneWidget);
      expect(find.byKey(TestIds.mistakesEntry), findsNothing);
    });

    testWidgets('$id: the round runs and records answers', (tester) async {
      final s = await _pump(tester, id, wrong: 2, study: true);
      expect(find.byKey(TestIds.mistakesEntry), findsOneWidget);
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(find.byKey(TestIds.mistakesRound), findsOneWidget);
      final kid = s.profile.children.first;
      if (flash) {
        expect(find.byKey(TestIds.mgScreen(flashReviewId)), findsOneWidget);
        await tester.tap(find.byKey(TestIds.mgStart(flashReviewId)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(TestIds.mgFlip(flashReviewId)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(TestIds.mgKnew(flashReviewId)));
      } else {
        expect(find.byKey(TestIds.quizScreen), findsOneWidget);
        await tester.tap(find.byKey(TestIds.quizOption(0)));
      }
      await tester.pumpAndSettle();
      final after = s.profile.children.firstWhere((c) => c.id == kid.id);
      // One right answer is not enough to clear an item.
      expect(after.progress.mistakeIds, hasLength(2));
      expect(
        after.progress.items.values.where((r) => r.streak == 1),
        hasLength(1),
      );
    });
  }
}
