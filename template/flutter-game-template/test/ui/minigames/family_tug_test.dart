import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_game_template/core/services.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_game_template/ui/minigames/family_tug_screen.dart';
import 'package:flutter_game_template/ui/minigames/tug_of_war_screen.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_services.dart';

Map<String, dynamic> _item(int i) => {
  'id': 'q.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'mcq',
  'explanation': 'Explained $i',
  'prompt': 'Question number $i',
  'options': ['Alpha', 'Beta', 'Gamma', 'Delta'],
  'correct': 1,
};

List<LoadedPack> _packs(int year, {int n = 12}) => [
  LoadedPack(
    ContentPack({
      'id': 'q$year',
      'version': 1,
      'lang': 'en-AU',
      'subject': 'maths',
      'year': year,
      'topic': 't',
      'title': 'q',
      'items': [
        for (var i = 1; i <= n; i++) {..._item(i), 'id': 'q$year.$i'},
      ],
    }),
  ),
];

QuizSession _session(int year) {
  final packs = _packs(year);
  return QuizSession(
    items: ReleaseEngine.ordered(packs, 'maths', year),
    progress: const ChildProgress(),
    packs: packs,
    rewardsConfig: const RewardsConfig(),
    today: 100,
  );
}

Widget _app(Widget child, {double scale = 1}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(scale),
      size: const Size(400, 900),
    ),
    child: child,
  ),
);

Future<void> _choose(WidgetTester t, {required bool right}) async {
  for (var i = 0; i < 4; i++) {
    final f = find.byKey(TestIds.familyChoice(i));
    if (f.evaluate().isEmpty) continue;
    final isBeta = find
        .descendant(of: f, matching: find.text('Beta'))
        .evaluate()
        .isNotEmpty;
    if (isBeta == right) {
      await t.tap(f);
      await t.pump();
      return;
    }
  }
  fail('no matching choice');
}

const _players = [
  FamilyPlayer('a', 'Mia', 'fox'),
  FamilyPlayer('b', 'Sam', 'fox'),
];

void main() {
  testWidgets('a full game: pass screens, own sessions, kind wording', (
    t,
  ) async {
    final log = <(int, bool)>[];
    final played = <int, int>{};
    var now = DateTime(2026, 1, 1);
    final s0 = _session(3);
    final s1 = _session(4);
    var exited = false;
    await t.pumpWidget(
      _app(
        FamilyTugScreen(
          players: _players,
          sessions: [s0, s1],
          level: const MiniGameLevel.older(),
          random: Random(3),
          clock: () => now,
          onAnswered: (i, r, s) async => log.add((i, r.correct)),
          onPlayed: (i, sec) => played[i] = (played[i] ?? 0) + sec,
          onExit: () => exited = true,
        ),
        scale: 1.5,
      ),
    );
    // The first turn is Mia's, with no pass screen.
    expect(find.text("Mia's turn"), findsOneWidget);
    expect(find.byKey(TestIds.mgTimer('family_tug')), findsOneWidget);
    var turns = 0;
    while (find.byKey(TestIds.familyResult).evaluate().isEmpty) {
      final mia = find.text("Mia's turn").evaluate().isNotEmpty;
      now = now.add(Duration(seconds: mia ? 3 : 5));
      await _choose(t, right: mia); // Mia right, Sam wrong
      final said = (t.widget<Text>(find.byKey(TestIds.familyFeedback))).data!;
      expect(
        said == (mia ? 'Nice pull, Mia!' : 'Good try, Sam!') ||
            said.endsWith('took that round!') ||
            said == 'That was the last pull!',
        isTrue,
        reason: said,
      );
      await t.tap(find.byKey(TestIds.familyNext));
      await t.pump();
      turns++;
      if (find.byKey(TestIds.familyPass).evaluate().isNotEmpty) {
        // The question is hidden until "I'm ready".
        expect(find.byKey(TestIds.mgPrompt('family_tug')), findsNothing);
        expect(find.byKey(TestIds.familyChoice(0)), findsNothing);
        expect(
          find.textContaining(mia ? 'Pass to Sam' : 'Pass to Mia'),
          findsOneWidget,
        );
        await t.tap(find.byKey(TestIds.familyReady));
        await t.pump();
      }
      expect(turns, lessThan(40));
    }
    expect(find.text('Great game, both of you!'), findsOneWidget);
    expect(find.textContaining('Mia pulled it home'), findsOneWidget);
    expect(find.textContaining('lost'), findsNothing);
    // Each answer went to its own player and session.
    expect(log.where((e) => e.$1 == 0).every((e) => e.$2), isTrue);
    expect(log.where((e) => e.$1 == 1).every((e) => !e.$2), isTrue);
    expect(s0.report.answered, log.where((e) => e.$1 == 0).length);
    expect(s1.report.answered, log.where((e) => e.$1 == 1).length);
    expect(s0.report.answered, greaterThan(0));
    expect(s1.report.answered, greaterThan(0));
    expect(played[0], s0.report.answered * 3);
    expect(played[1], s1.report.answered * 5);
    await t.tap(find.byKey(TestIds.familyDone));
    expect(exited, isTrue);
  });

  testWidgets(
    'gentler rules: no timer, a wrong pick is greyed out and retried',
    (t) async {
      final log = <bool>[];
      await t.pumpWidget(
        _app(
          FamilyTugScreen(
            players: _players,
            sessions: [_session(1), _session(3)],
            level: const MiniGameLevel.younger(),
            random: Random(5),
            onAnswered: (i, r, s) async => log.add(r.correct),
            onExit: () {},
          ),
        ),
      );
      expect(find.byKey(TestIds.mgTimer('family_tug')), findsNothing);
      expect(find.byKey(TestIds.familyChoice(2)), findsNothing); // two options
      await _choose(t, right: false);
      expect(log, isEmpty);
      expect(find.byKey(TestIds.familyFeedback), findsNothing);
      await _choose(t, right: true);
      expect(log, [false]); // recorded as not first try
      expect(find.textContaining('Nice pull, Mia!'), findsOneWidget);
      // The rope moved toward Mia only.
      expect(
        find.bySemanticsLabel(RegExp('1 of 3 steps toward Mia')),
        findsOneWidget,
      );
    },
  );

  testWidgets('older level: running out of time pulls back', (t) async {
    await t.pumpWidget(
      _app(
        FamilyTugScreen(
          players: _players,
          sessions: [_session(3), _session(3)],
          level: const MiniGameLevel.older(),
          random: Random(2),
          onExit: () {},
        ),
      ),
    );
    await t.pump(const Duration(seconds: 21));
    expect(find.textContaining('Time is up, Mia'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  Future<Services> setup({
    required bool flag,
    required List<int?> years,
  }) async {
    final s = await buildFakeServices(familyMode: flag, contentEnabled: true);
    for (var i = 0; i < years.length; i++) {
      await s.profile.addChild('Kid$i', year: years[i]);
    }
    s.profile.selectChild(s.profile.children.first.id);
    return s;
  }

  Future<void> openTug(WidgetTester t, Services s) async {
    await t.pumpWidget(
      ServicesScope(
        services: s,
        child: _app(
          TugOfWarScreen(
            session: _session(3),
            level: const MiniGameLevel.older(),
            onExit: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('Play with a sibling shows only with the flag and two eligible', (
    t,
  ) async {
    await openTug(t, await setup(flag: true, years: [3, 4]));
    expect(find.byKey(TestIds.familyStart), findsOneWidget);
    await openTug(t, await setup(flag: false, years: [3, 4]));
    expect(find.byKey(TestIds.familyStart), findsNothing);
    await openTug(t, await setup(flag: true, years: [3]));
    expect(find.byKey(TestIds.familyStart), findsNothing);
  });

  testWidgets('the start button opens the partner picker', (t) async {
    final s = await setup(flag: true, years: [3, 4, 5]);
    await openTug(t, s);
    await t.tap(find.byKey(TestIds.familyStart));
    await t.pumpAndSettle();
    expect(find.byKey(TestIds.familySetup), findsOneWidget);
    final others = s.profile.children.skip(1);
    for (final c in others) {
      expect(find.byKey(TestIds.familyPartner(c.id)), findsOneWidget);
    }
    expect(
      find.byKey(TestIds.familyPartner(s.profile.children.first.id)),
      findsNothing,
    );
  });

  test('family mode is off in the template config', () async {
    final s = await buildFakeServices();
    expect(s.config.familyMode.enabled, isFalse);
  });
}
