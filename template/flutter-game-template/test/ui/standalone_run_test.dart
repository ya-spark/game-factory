import 'package:flutter/material.dart';
import 'package:flutter_game_template/core/config/app_config.dart';
import 'package:flutter_game_template/core/profile/profile_store.dart';
import 'package:flutter_game_template/core/save/save_service.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_game_template/ui/run_report_scope.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ProfileStore> _store() async {
  final p = ProfileStore(
    saves: MemorySaveService(),
    retention: const RetentionConfig(),
    gameStatsEnabled: true,
  );
  await p.init();
  return p;
}

void main() {
  test('a game without the hook is recorded from its score call', () async {
    final p = await _store();
    final run = StandaloneRun(profile: p, gameId: 'g', title: 'G');
    await run.onScore(40);
    await run.onScore(60);
    expect(p.data.gameStats.entry('g').plays, 2);
    expect(p.data.gameStats.entry('g').winRatePercent, isNull);
  });

  test('a game that reports once per run is not counted twice', () async {
    final p = await _store();
    final run = StandaloneRun(
      profile: p,
      gameId: 'g',
      title: 'G',
      reportsRuns: true,
    );
    await run.wrapForTest(
      (sink) => sink(30, const RunExtras(won: true, variant: 'Hard')),
    );
    await run.onScore(30);
    await run.onScore(31);
    final e = p.data.gameStats.entry('g');
    expect(e.plays, 1);
    expect(e.wins, 1);
  });

  testWidgets('the new-best line shows once, after the screen closed', (
    tester,
  ) async {
    final p = await _store();
    final run = StandaloneRun(profile: p, gameId: 'g', title: 'Merge');
    await run.onScore(10);
    await run.onScore(20);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () => run.announce(ScaffoldMessenger.of(c)),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(TestIds.newBestMessage), findsNothing);
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.byKey(TestIds.newBestMessage), findsOneWidget);
    expect(
      find.textContaining('New personal best in Merge: 20'),
      findsOneWidget,
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(p.takeNewBestMessage(), isNull);
  });
}
