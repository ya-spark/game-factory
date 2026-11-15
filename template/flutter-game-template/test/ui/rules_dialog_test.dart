import 'package:flutter/material.dart';
import 'package:flutter_game_template/core/services.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_game_template/ui/game_registry.dart';
import 'package:flutter_game_template/ui/rules_dialog.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';

Future<Services> _pump(
  WidgetTester tester,
  String gameId,
  String? Function(Services) childOf, {
  List<String> Function(Services)? also,
  Services? reuse,
}) async {
  tester.platformDispatcher.textScaleFactorTestValue = 2.0;
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final s = reuse ?? await buildFakeServices(contentEnabled: true);
  await tester.pumpWidget(
    ServicesScope(
      services: s,
      child: MaterialApp(
        home: Scaffold(
          body: RulesGate(
            key: UniqueKey(),
            gameId: gameId,
            childId: childOf(s),
            alsoMark: also?.call(s) ?? const [],
            child: const SizedBox(key: Key('game.body')),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return s;
}

void main() {
  testWidgets('opens by itself once per child, Rules button reopens it', (
    tester,
  ) async {
    final s = await buildFakeServices(contentEnabled: true);
    final mia = (await s.profile.addChild('Mia', year: 3))!;
    final leo = (await s.profile.addChild('Leo', year: 3))!;
    await _pump(tester, 'memory_match', (_) => mia.id, reuse: s);
    expect(find.byKey(TestIds.rulesDialog), findsOneWidget);
    expect(find.byKey(TestIds.rulesFor('memory_match')), findsOneWidget);
    expect(tester.takeException(), isNull); // scrolls at 200 percent text
    await tester.tap(find.byKey(TestIds.rulesGotIt));
    await tester.pumpAndSettle();
    expect(find.byKey(TestIds.rulesDialog), findsNothing);
    final cur = s.profile.children.firstWhere((c) => c.id == mia.id);
    expect(cur.rulesSeen, {'memory_match'});
    // The Rules button reopens it and never changes the flag.
    await tester.tap(find.byKey(TestIds.rulesButton));
    await tester.pumpAndSettle();
    expect(find.byKey(TestIds.rulesDialog), findsOneWidget);
    await tester.tap(find.byKey(TestIds.rulesGotIt));
    await tester.pumpAndSettle();
    // Opening the game again for the same child: no dialog.
    await _pump(tester, 'memory_match', (_) => mia.id, reuse: s);
    expect(find.byKey(TestIds.rulesDialog), findsNothing);
    expect(find.byKey(TestIds.rulesButton), findsOneWidget);
    // A second child sees it again; another game is unseen for the first child.
    await _pump(tester, 'memory_match', (_) => leo.id, reuse: s);
    expect(find.byKey(TestIds.rulesDialog), findsOneWidget);
    await tester.tap(find.byKey(TestIds.rulesGotIt));
    await tester.pumpAndSettle();
    await _pump(tester, 'sort_bins', (_) => mia.id, reuse: s);
    expect(find.byKey(TestIds.rulesDialog), findsOneWidget);
    await tester.tap(find.byKey(TestIds.rulesGotIt));
    await tester.pumpAndSettle();
  });

  testWidgets('no child: opens, stores nothing', (tester) async {
    final s = await buildFakeServices(contentEnabled: true);
    await _pump(tester, 'tug_of_war', (_) => null, reuse: s);
    expect(find.byKey(TestIds.rulesDialog), findsOneWidget);
    await tester.tap(find.byKey(TestIds.rulesGotIt));
    await tester.pumpAndSettle();
    expect(s.profile.children, isEmpty);
  });

  testWidgets('two-player Tug of war marks both players seen', (tester) async {
    final s = await buildFakeServices(contentEnabled: true);
    final a = (await s.profile.addChild('Mia', year: 3))!;
    final b = (await s.profile.addChild('Leo', year: 3))!;
    await _pump(
      tester,
      'tug_of_war',
      (_) => a.id,
      also: (_) => [b.id],
      reuse: s,
    );
    expect(find.byKey(TestIds.rulesDialog), findsOneWidget);
    await tester.tap(find.byKey(TestIds.rulesGotIt));
    await tester.pumpAndSettle();
    for (final c in s.profile.children) {
      expect(c.rulesSeen, {'tug_of_war'});
    }
  });

  testWidgets('every catalogue game gets a Rules button', (tester) async {
    for (final g in HowToPlayCatalogue.all) {
      await _pump(tester, g.id, (_) => null);
      expect(find.byKey(TestIds.rulesButton), findsOneWidget, reason: g.id);
      await tester.tap(find.byKey(TestIds.rulesGotIt));
      await tester.pumpAndSettle();
    }
  });

  test('every game registered in this app has a catalogue entry', () {
    for (final e in appGames.entries) {
      final r = HowToPlayCatalogue.forGame(e.game.id);
      expect(r, isNotNull, reason: e.game.id);
      expect(r!.rules, isNotEmpty);
      expect(r.tips.length, inInclusiveRange(2, 3));
    }
  });
}
