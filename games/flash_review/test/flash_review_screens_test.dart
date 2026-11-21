import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_flash_review/flash_review.dart';

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

QuizSession _session({int year = 3, int n = 4}) {
  final packs = [
    LoadedPack(
      ContentPack({
        'id': 'q',
        'version': 1,
        'lang': 'en-AU',
        'subject': 'maths',
        'year': year,
        'topic': 't',
        'title': 'q',
        'items': [for (var i = 1; i <= n; i++) _item(i)],
      }),
    ),
  ];
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

void main() {
  testWidgets('Flash review: flip, "Not yet" keeps it, "I knew it" passes', (
    t,
  ) async {
    final s = _session();
    final log = <AnswerResult>[];
    var exited = false;
    await t.pumpWidget(
      _app(
        FlashReviewScreen(
          session: s,
          onExit: () => exited = true,
          onAnswered: (r, _) => log.add(r),
        ),
        scale: 1.5,
      ),
    );
    expect(find.byKey(GameIds.mgTimer('flash_review')), findsNothing);
    await t.tap(find.byKey(GameIds.mgStart('flash_review')));
    await t.pump();
    expect(find.text('Question number 1'), findsOneWidget);
    expect(find.byKey(GameIds.mgKnew('flash_review')), findsNothing);
    await t.tap(find.byKey(GameIds.mgFlip('flash_review')));
    await t.pump();
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Explained 1'), findsOneWidget);
    await t.tap(find.byKey(GameIds.mgNotYet('flash_review')));
    await t.pump();
    expect(s.progress.mistakeIds, ['q.1']);
    for (var i = 1; i < 4; i++) {
      await t.tap(find.byKey(GameIds.mgFlip('flash_review')));
      await t.pump();
      await t.tap(find.byKey(GameIds.mgKnew('flash_review')));
      await t.pump();
    }
    expect(log, hasLength(4));
    expect(log.every((r) => r.coins == 0), isTrue);
    expect(find.byKey(GameIds.mgResults('flash_review')), findsOneWidget);
    expect(find.text('You knew 3 of 4'), findsOneWidget);
    await t.tap(find.byKey(GameIds.mgDone('flash_review')));
    expect(exited, isTrue);
  });
}
