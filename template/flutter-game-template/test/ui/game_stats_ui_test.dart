import 'package:flutter/material.dart';
import 'package:flutter_game_template/app.dart';
import 'package:flutter_game_template/ui/app_shell.dart';
import 'package:flutter_game_template/ui/tabs/tab_data.dart';
import 'package:flutter_game_template/ui/theme/app_theme.dart';
import 'package:flutter_game_template/ui/theme/design_scope.dart';
import 'package:flutter_game_template/core/services.dart';
import 'package:game_core/engine/engine.dart';
import 'package:flutter_game_template/ui/stats_screen.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';
import 'kit/kit_test.dart' show FileDesignBundle, loadDesign;

Future<Services> _open(
  WidgetTester tester, {
  required bool stats,
  bool settings = false,
}) async {
  tester.view.physicalSize = const Size(600, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = await buildFakeServices(contentEnabled: true, gameStats: stats);
  final kid = (await s.profile.addChild('Mia', year: 3))!;
  s.profile.selectChild(kid.id);
  for (final score in [10, 20, 30]) {
    await s.profile.recordRun(
      RunReport(
        gameId: 'sudoku',
        score: score,
        won: true,
        seconds: 75,
        variant: 'Hard',
      ),
      gameTitle: 'Sudoku',
    );
  }
  await tester.pumpWidget(GameApp(services: s));
  await tester.pump();
  if (settings) {
    await tester.tap(find.byKey(TestIds.homeSettings));
    await tester.pumpAndSettle();
  }
  return s;
}

/// The hub shell on the Challenges tab (a design bundle, as in the apps).
Future<Services> _challenges(WidgetTester tester, {required bool stats}) async {
  tester.view.physicalSize = const Size(600, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = await buildFakeServices(contentEnabled: true, gameStats: stats);
  final kid = (await s.profile.addChild('Mia', year: 3))!;
  s.profile.selectChild(kid.id);
  for (final score in [10, 20, 30]) {
    await s.profile.recordRun(
      RunReport(
        gameId: 'sudoku',
        score: score,
        won: true,
        seconds: 75,
        variant: 'Hard',
      ),
      gameTitle: 'Sudoku',
    );
  }
  final design = loadDesign('mind_1');
  final mode = design.app.modes.keys.first;
  final level = design.app.levelForYear(3);
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
            level: level,
          ),
          builder: (context, child) => DesignScope(
            design: design,
            mode: mode,
            level: level,
            child: child!,
          ),
          home: AppShell(
            registry: const MiniGameRegistry([]),
            loaders: TabLoaders(
              openItems: (_) async => const [],
              packs: () async => const [],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(TestIds.dsTab(TestIds.shellBottomBar, 'challenges')),
  );
  await tester.pumpAndSettle();
  return s;
}

void main() {
  testWidgets('Stats page: overview, a game card and the trend text', (
    tester,
  ) async {
    final sem = tester.ensureSemantics();
    await _challenges(tester, stats: true);
    await tester.tap(find.byKey(TestIds.statsEntry));
    await tester.pumpAndSettle();
    expect(find.byKey(TestIds.statsScreen), findsOneWidget);
    expect(find.byKey(TestIds.statsOverview), findsOneWidget);
    expect(find.text('Days played: 1'), findsOneWidget);
    expect(find.byKey(TestIds.statsCard('sudoku')), findsOneWidget);
    expect(find.text('Wins: 3 (100% win rate)'), findsOneWidget);
    expect(find.text('Fastest Hard: 1m 15s'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(TestIds.statsTrend('sudoku'))).label,
      contains('Scores trending up, last 3: 10, 20, 30'),
    );
    sem.dispose();
  });

  testWidgets('the Craft profile (flag off) has no Stats entry', (
    tester,
  ) async {
    await _challenges(tester, stats: false);
    expect(find.byKey(TestIds.statsEntry), findsNothing);
  });

  testWidgets('Settings reset asks first and clears history only', (
    tester,
  ) async {
    final s = await _open(tester, stats: true, settings: true);
    await tester.scrollUntilVisible(
      find.byKey(TestIds.settingsResetStats),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(TestIds.settingsResetStats));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.settingsResetStatsCancel));
    await tester.pumpAndSettle();
    expect(s.profile.data.gameStats.entry('sudoku').plays, 3);
    await tester.tap(find.byKey(TestIds.settingsResetStats));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.settingsResetStatsConfirm));
    await tester.pumpAndSettle();
    expect(s.profile.data.gameStats.entry('sudoku').plays, 0);
    expect(s.profile.data.gameStats.entry('sudoku').bestScore, 30);
  });

  testWidgets('Settings has no reset row with the flag off', (tester) async {
    await _open(tester, stats: false, settings: true);
    expect(find.byKey(TestIds.settingsResetStats), findsNothing);
  });

  test('formatDuration', () {
    expect(formatDuration(45), '45s');
    expect(formatDuration(125), '2m 5s');
    expect(formatDuration(3900), '1h 5m');
    expect(formatDuration(-3), '0s');
  });
}
