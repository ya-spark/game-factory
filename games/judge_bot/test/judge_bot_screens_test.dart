import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_judge_bot/judge_bot.dart';

const String _g = judgeBotId;

Map<String, dynamic> _item(int i, {String explanation = ''}) => {
  'id': 'q.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'mcq',
  'explanation': explanation,
  'prompt': 'Question number $i',
  'options': ['Alpha', 'Beta', 'Gamma', 'Delta'],
  'correct': 1,
};

QuizSession _session({int year = 3, int n = 4, bool explain = true}) {
  final packs = [
    LoadedPack(
      ContentPack({
        'id': 'q',
        'version': 1,
        'lang': 'en-AU',
        'subject': 'maths',
        'year': year,
        'topic': 'times_tables',
        'title': 'q',
        'items': [
          for (var i = 1; i <= n; i++)
            _item(i, explanation: explain ? 'Explained $i' : ''),
        ],
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

Finder _lampT = find.byKey(JudgeBotIds.lampTrue(_g));
Finder _lampF = find.byKey(JudgeBotIds.lampFalse(_g));
Finder _next = find.byKey(GameIds.mgNext(_g));

String _ticket(WidgetTester t) => (t.widget<Text>(
  find.descendant(
    of: find.byKey(GameIds.mgPrompt(_g)),
    matching: find.byType(Text),
  ),
)).data!;

String _feedback(WidgetTester t) => t
    .widgetList<Text>(
      find.descendant(
        of: find.byKey(GameIds.mgFeedback(_g)),
        matching: find.byType(Text),
      ),
    )
    .map((x) => x.data ?? '')
    .join(' | ');

bool _claimTrue(WidgetTester t) => _ticket(t).endsWith('Beta');

void main() {
  Future<List<AnswerResult>> open(
    WidgetTester t, {
    MiniGameLevel level = const MiniGameLevel.older(),
    Size size = const Size(390, 800),
    double scale = 1,
    int year = 3,
    bool explain = true,
    bool study = false,
    VoidCallback? onExit,
    void Function(int)? onScore,
    int seed = 4,
    bool start = true,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final log = <AnswerResult>[];
    await t.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
          child: JudgeBotScreen(
            session: _session(year: year, explain: explain),
            level: level,
            study: study,
            onExit: onExit ?? () {},
            onAnswered: (r, _) => log.add(r),
            onScore: onScore,
            random: Random(seed),
          ),
        ),
      ),
    );
    if (start) {
      await t.ensureVisible(find.byKey(GameIds.mgStart(_g)));
      await t.tap(find.byKey(GameIds.mgStart(_g)));
      await t.pump(const Duration(milliseconds: 300));
    }
    return log;
  }

  Future<void> end(WidgetTester t) => t.pumpWidget(const SizedBox());

  group('Judge bot (SPEC: Flow)', () {
    testWidgets(
      'the first screen says what to do, one big Start, no title bar',
      (t) async {
        await open(t, start: false);
        expect(find.text(judgeBotHowTo), findsOneWidget);
        expect(find.text('Start (Enter / Space)'), findsOneWidget);
        expect(find.byType(AppBar), findsNothing);
        expect(find.text('Judge bot'), findsNothing);
        expect(find.text('How to play (H)'), findsOneWidget);
        expect(find.textContaining('Times tables'), findsOneWidget);
        await end(t);
      },
    );

    testWidgets(
      '4 tickets to the results: score, best streak, stars, judged right',
      (t) async {
        int? score;
        final log = await open(
          t,
          level: const MiniGameLevel.younger(),
          year: 1,
          onScore: (v) => score = v,
        );
        for (var q = 0; q < 4; q++) {
          expect(find.text('Ticket ${q + 1} of 4'), findsOneWidget);
          await t.tap(_claimTrue(t) ? _lampT : _lampF);
          await t.pump();
          expect(log.last.correct, isTrue);
          await t.tap(_next);
          await t.pump(const Duration(milliseconds: 300));
        }
        expect(find.byKey(GameIds.mgResults(_g)), findsOneWidget);
        expect(score, 40);
        expect(find.text('Score 40'), findsOneWidget);
        expect(find.text('4 of 4 judged right'), findsOneWidget);
        expect(find.text('Best streak 4 in a row'), findsOneWidget);
        expect(find.byKey(GameIds.mgStars(_g)), findsOneWidget);
        expect(find.byKey(JudgeBotIds.reviewList(_g)), findsNothing);
        await end(t);
      },
    );

    testWidgets('missed tickets are listed for review on the results screen', (
      t,
    ) async {
      await open(t, level: const MiniGameLevel.younger(), year: 1);
      for (var q = 0; q < 4; q++) {
        await t.tap(_claimTrue(t) ? _lampF : _lampT);
        await t.pump();
        await t.tap(_next);
        await t.pump(const Duration(milliseconds: 300));
      }
      expect(find.byKey(JudgeBotIds.reviewList(_g)), findsOneWidget);
      expect(find.byKey(JudgeBotIds.review(_g, 2)), findsOneWidget);
      expect(find.byKey(JudgeBotIds.review(_g, 3)), findsNothing);
      expect(find.text('0 of 4 judged right'), findsOneWidget);
      await end(t);
    });
  });

  group('Judge bot (B-15: feedback matches the question shown)', () {
    for (final mode in ['right', 'wrong', 'time up']) {
      testWidgets(
        '$mode: ticket and feedback stay on the same question until Next',
        (t) async {
          await open(t);
          final shown = _ticket(t);
          final q1 = find.text('Question number 1');
          expect(q1, findsOneWidget);
          if (mode == 'time up') {
            await t.pump(const Duration(seconds: 11));
          } else {
            final right = mode == 'right';
            await t.tap(_claimTrue(t) == right ? _lampT : _lampF);
            await t.pump();
          }
          expect(_ticket(t), shown);
          expect(find.text('Question number 1'), findsOneWidget);
          expect(find.text('Ticket 1 of 4'), findsOneWidget);
          final fb = _feedback(t);
          expect(fb, contains('Question number 1'));
          expect(fb, contains('Beta'));
          expect(fb, contains('Explained 1'));
          expect(
            find.text(
              mode == 'right'
                  ? 'Right!'
                  : (mode == 'wrong' ? 'Not this time.' : 'Time is up.'),
            ),
            findsOneWidget,
          );
          await t.tap(_next);
          await t.pump(const Duration(milliseconds: 300));
          expect(find.text('Question number 2'), findsOneWidget);
          expect(find.text('Ticket 2 of 4'), findsOneWidget);
          await end(t);
        },
      );
    }
  });

  group('Judge bot (SPEC: Input)', () {
    testWidgets('T F 1 2 answer; the stamp shows the right verdict', (t) async {
      final log = await open(t);
      await t.sendKeyEvent(LogicalKeyboardKey.keyT);
      await t.pump();
      expect(log, hasLength(1));
      expect(log.last.correct, _claimTrue(t));
      final stamp = find.byKey(JudgeBotIds.stamp(_g));
      expect(
        find.descendant(
          of: stamp,
          matching: find.text(_claimTrue(t) ? 'TRUE' : 'FALSE'),
        ),
        findsOneWidget,
      );
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump(const Duration(milliseconds: 300));
      await t.sendKeyEvent(LogicalKeyboardKey.digit2);
      await t.pump();
      expect(log, hasLength(2));
      expect(log.last.correct, !_claimTrue(t));
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pump(const Duration(milliseconds: 300));
      await t.sendKeyEvent(LogicalKeyboardKey.keyF);
      await t.pump();
      expect(log, hasLength(3));
      await end(t);
    });

    testWidgets(
      'Left and Right move the cursor, Enter and Space confirm; a pick is final',
      (t) async {
        final log = await open(
          t,
          level: const MiniGameLevel.younger(),
          year: 1,
        );
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pump();
        expect(log, isEmpty, reason: 'nothing highlighted yet');
        await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await t.pump();
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pump();
        expect(log, hasLength(1));
        expect(log.last.correct, !_claimTrue(t));
        await t.sendKeyEvent(LogicalKeyboardKey.keyT);
        await t.pump();
        expect(log, hasLength(1), reason: 'no second pick, no retry');
        await end(t);
      },
    );

    testWidgets(
      'Space never pauses; P and Esc pause, Esc or P or Space resume; Esc after a pick leaves',
      (t) async {
        var left = 0;
        await open(t, onExit: () => left++);
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.pump();
        expect(find.byKey(GameIds.mgPaused(_g)), findsNothing);
        await t.sendKeyEvent(LogicalKeyboardKey.keyP);
        await t.pump();
        expect(find.byKey(GameIds.mgPaused(_g)), findsOneWidget);
        expect(find.text('Resume (P / Esc / Space)'), findsOneWidget);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pump();
        expect(find.byKey(GameIds.mgPaused(_g)), findsNothing);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pump();
        expect(find.byKey(GameIds.mgPaused(_g)), findsOneWidget);
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.pump();
        expect(find.byKey(GameIds.mgPaused(_g)), findsNothing);
        await t.sendKeyEvent(LogicalKeyboardKey.keyT);
        await t.pump();
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        expect(left, 1);
        await end(t);
      },
    );

    testWidgets(
      'the paused clock does not run and T and F do nothing while paused',
      (t) async {
        final log = await open(t);
        await t.sendKeyEvent(LogicalKeyboardKey.keyP);
        await t.pump(const Duration(seconds: 30));
        await t.sendKeyEvent(LogicalKeyboardKey.keyT);
        await t.pump();
        expect(log, isEmpty);
        await t.sendKeyEvent(LogicalKeyboardKey.keyP);
        await t.pump(const Duration(seconds: 2));
        expect(log, isEmpty);
        await end(t);
      },
    );

    testWidgets(
      'H opens how to play and Enter, Space or Esc close it; every button shows its key',
      (t) async {
        await open(t, start: false);
        expect(find.text('Start (Enter / Space)'), findsOneWidget);
        for (final k in [
          LogicalKeyboardKey.enter,
          LogicalKeyboardKey.space,
          LogicalKeyboardKey.escape,
        ]) {
          await t.sendKeyEvent(LogicalKeyboardKey.keyH);
          await t.pumpAndSettle();
          expect(find.byKey(JudgeBotIds.howTo(_g)), findsOneWidget);
          expect(find.textContaining('Is it true or false?'), findsOneWidget);
          await t.sendKeyEvent(k);
          await t.pumpAndSettle();
          expect(find.byKey(JudgeBotIds.howTo(_g)), findsNothing);
        }
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pump(const Duration(milliseconds: 300));
        // T and F are printed on the lamps; Pause and Exit print P and L.
        expect(
          find.descendant(of: _lampT, matching: find.text('T')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: _lampF, matching: find.text('F')),
          findsOneWidget,
        );
        expect(find.text('P'), findsWidgets);
        expect(find.text('L'), findsWidgets);
        await t.sendKeyEvent(LogicalKeyboardKey.keyT);
        await t.pump();
        expect(find.text('Next (Enter / Space)'), findsOneWidget);
        await end(t);
      },
    );
  });

  group('Judge bot (SPEC: Levels and pacing)', () {
    testWidgets(
      'younger: no timer; a wrong pick shows the right verdict, moves on, no retry',
      (t) async {
        final log = await open(
          t,
          level: const MiniGameLevel.younger(),
          year: 1,
        );
        expect(find.byKey(GameIds.mgTimer(_g)), findsNothing);
        await t.tap(_claimTrue(t) ? _lampF : _lampT);
        await t.pump();
        expect(log, hasLength(1));
        expect(log.single.correct, isFalse);
        expect(find.text('Not this time.'), findsOneWidget);
        expect(find.byKey(JudgeBotIds.stamp(_g)), findsOneWidget);
        await t.tap(_lampT);
        await t.pump();
        expect(log, hasLength(1));
        await end(t);
      },
    );

    testWidgets('older: a timer, and time up counts as wrong', (t) async {
      final log = await open(t);
      expect(find.byKey(GameIds.mgTimer(_g)), findsOneWidget);
      expect(find.text('0:10'), findsOneWidget);
      await t.pump(const Duration(seconds: 11));
      expect(log, hasLength(1));
      expect(log.single.correct, isFalse);
      expect(find.text('Time is up.'), findsOneWidget);
      await end(t);
    });

    testWidgets('study mode has no timer', (t) async {
      await open(t, study: true);
      expect(find.byKey(GameIds.mgTimer(_g)), findsNothing);
      await end(t);
    });

    testWidgets(
      'older: a right answer without an explanation moves on after 1.2 s, and gives the fast bonus',
      (t) async {
        int? score;
        await open(t, explain: false, onScore: (v) => score = v);
        await t.tap(_claimTrue(t) ? _lampT : _lampF);
        await t.pump();
        expect(find.byKey(JudgeBotIds.fast(_g)), findsOneWidget);
        await t.pump(const Duration(milliseconds: 1100));
        expect(find.text('Ticket 1 of 4'), findsOneWidget);
        await t.pump(const Duration(milliseconds: 400));
        await t.pump(const Duration(milliseconds: 300));
        expect(find.text('Ticket 2 of 4'), findsOneWidget);
        expect(score, isNull);
        await end(t);
      },
    );

    testWidgets(
      'no auto-move after a wrong answer, with an explanation, or at the younger level',
      (t) async {
        await open(t, explain: false);
        await t.tap(_claimTrue(t) ? _lampF : _lampT);
        await t.pump(const Duration(seconds: 3));
        expect(find.text('Ticket 1 of 4'), findsOneWidget);
        await end(t);
        await open(t);
        await t.tap(_claimTrue(t) ? _lampT : _lampF);
        await t.pump(const Duration(seconds: 3));
        expect(find.text('Ticket 1 of 4'), findsOneWidget);
        await end(t);
        await open(
          t,
          level: const MiniGameLevel.younger(),
          year: 1,
          explain: false,
        );
        await t.tap(_claimTrue(t) ? _lampT : _lampF);
        await t.pump(const Duration(seconds: 3));
        expect(find.text('Ticket 1 of 4'), findsOneWidget);
        await end(t);
      },
    );

    testWidgets('older score: 10 + 2 per streak step + 2 fast', (t) async {
      int? score;
      await open(t, onScore: (v) => score = v);
      for (var q = 0; q < 4; q++) {
        await t.tap(_claimTrue(t) ? _lampT : _lampF);
        await t.pump();
        await t.tap(_next);
        await t.pump(const Duration(milliseconds: 300));
      }
      expect(score, 12 + 14 + 16 + 18);
      expect(find.text('Streak 4'), findsNothing);
      await end(t);
    });

    testWidgets(
      'light evidence: the skill sees a right answer only from the second in a row',
      (t) async {
        final s = _session();
        final withSkill = QuizSession(
          items: [
            for (final p in s.items)
              PoolItem(
                item: p.item,
                packId: p.packId,
                subject: p.subject,
                year: p.year,
                topic: p.topic,
                skillKey: 'maths/3/a',
              ),
          ],
          progress: const ChildProgress(),
          packs: const [],
          rewardsConfig: const RewardsConfig(),
          today: 100,
        );
        t.view.physicalSize = const Size(390, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(
          MaterialApp(
            home: JudgeBotScreen(
              session: withSkill,
              level: const MiniGameLevel.younger(),
              onExit: () {},
              random: Random(4),
            ),
          ),
        );
        await t.tap(find.byKey(GameIds.mgStart(_g)));
        await t.pump(const Duration(milliseconds: 300));
        await t.tap(_claimTrue(t) ? _lampT : _lampF);
        await t.pump();
        expect(
          withSkill.progress.skills,
          isEmpty,
          reason: 'first right answer: no evidence',
        );
        await t.tap(_next);
        await t.pump(const Duration(milliseconds: 300));
        await t.tap(_claimTrue(t) ? _lampT : _lampF);
        await t.pump();
        expect(withSkill.progress.skills['maths/3/a']!.evidence, hasLength(1));
        await end(t);
      },
    );
  });

  group('Judge bot (SPEC: Reduced motion and Semantics)', () {
    testWidgets('reduced motion: no auto-move, states change at once', (
      t,
    ) async {
      t.view.physicalSize = const Size(390, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 800),
              disableAnimations: true,
            ),
            child: JudgeBotScreen(
              session: _session(explain: false),
              level: const MiniGameLevel.older(),
              onExit: () {},
              random: Random(4),
            ),
          ),
        ),
      );
      await t.tap(find.byKey(GameIds.mgStart(_g)));
      await t.pump();
      await t.tap(_claimTrue(t) ? _lampT : _lampF);
      await t.pump();
      expect(find.byKey(JudgeBotIds.stamp(_g)), findsOneWidget);
      await t.pump(const Duration(seconds: 3));
      expect(find.text('Ticket 1 of 4'), findsOneWidget);
      await end(t);
    });

    testWidgets('semantics: ticket, lamps and the verdict live region', (
      t,
    ) async {
      final h = t.ensureSemantics();
      await open(t, level: const MiniGameLevel.younger(), year: 1);
      expect(
        find.bySemanticsLabel(
          RegExp(
            'Question: Question number 1\\. Claim: The answer is: .* True or false\\?',
          ),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('True, key T'), findsOneWidget);
      expect(find.bySemanticsLabel('False, key F'), findsOneWidget);
      expect(find.bySemanticsLabel('Judge bot, waiting'), findsOneWidget);
      await t.tap(_claimTrue(t) ? _lampT : _lampF);
      await t.pump();
      expect(
        find.bySemanticsLabel(
          RegExp(
            'Right! True\\. The answer to "Question number 1" is Beta\\. Explained 1',
          ),
        ),
        findsNothing,
      );
      expect(
        find.bySemanticsLabel(RegExp('^Right! (True|False)\\. .*Streak 1\\.')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('(True|False), the right answer')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('(True|False), not this one')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Judge bot, happy'), findsOneWidget);
      await end(t);
      h.dispose();
    });
  });

  group('Judge bot (SPEC: Layout)', () {
    for (final size in const [
      Size(360, 640),
      Size(390, 844),
      Size(844, 390),
      Size(1024, 768),
      Size(1280, 720),
      Size(1440, 900),
      Size(1920, 1080),
    ]) {
      for (final scale in const [1.0, 1.5]) {
        for (final older in [false, true]) {
          testWidgets(
            'plays at ${size.width.toInt()}x${size.height.toInt()}, text $scale, ${older ? 'older' : 'younger'}: no title, no overflow, lamps 72 dp, no page scroll',
            (t) async {
              // The web bar takes about 44 px of the window height.
              final game = Size(size.width, size.height - 44);
              await open(
                t,
                level: older
                    ? const MiniGameLevel.older()
                    : const MiniGameLevel.younger(),
                size: game,
                scale: scale,
                year: older ? 4 : 1,
              );
              expect(t.takeException(), isNull);
              expect(find.text('Judge bot'), findsNothing);
              expect(find.byType(AppBar), findsNothing);
              expect(t.getSize(find.byKey(GameIds.mgPause(_g))).width, 44);
              expect(t.getSize(find.byKey(GameIds.mgExit(_g))).width, 44);
              for (final l in [_lampT, _lampF]) {
                final r = t.getRect(l);
                expect(r.height, greaterThanOrEqualTo(72));
                expect(r.bottom, lessThanOrEqualTo(game.height));
                expect(r.right, lessThanOrEqualTo(game.width));
                expect(r.left, greaterThanOrEqualTo(0));
              }
              final ticket = t.getRect(find.byKey(JudgeBotIds.ticket(_g)));
              expect(ticket.top, greaterThanOrEqualTo(0));
              expect(ticket.bottom, lessThanOrEqualTo(game.height));
              await t.tap(_claimTrue(t) ? _lampT : _lampF);
              await t.pump();
              expect(t.takeException(), isNull);
              final next = t.getRect(_next);
              expect(next.bottom, lessThanOrEqualTo(game.height));
              expect(next.right, lessThanOrEqualTo(game.width));
              await end(t);
            },
          );
        }
      }
    }

    testWidgets('a long claim shrinks, then scrolls inside the ticket only', (
      t,
    ) async {
      final long = 'The answer is: ${'a very long answer ' * 8}';
      final item = {
        ..._item(1),
        'options': [long, 'Beta', 'Gamma', 'Delta'],
        'correct': 0,
      };
      final packs = [
        LoadedPack(
          ContentPack({
            'id': 'q',
            'version': 1,
            'lang': 'en-AU',
            'subject': 'maths',
            'year': 1,
            'topic': 't',
            'title': 'q',
            'items': [item, _item(2), _item(3), _item(4)],
          }),
        ),
      ];
      t.view.physicalSize = const Size(360, 596);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          home: JudgeBotScreen(
            session: QuizSession(
              items: ReleaseEngine.ordered(packs, 'maths', 1),
              progress: const ChildProgress(),
              packs: packs,
              rewardsConfig: const RewardsConfig(),
              today: 100,
            ),
            level: const MiniGameLevel.younger(),
            onExit: () {},
            random: Random(1),
          ),
        ),
      );
      await t.tap(find.byKey(GameIds.mgStart(_g)));
      await t.pump(const Duration(milliseconds: 300));
      expect(t.takeException(), isNull);
      expect(
        t.getRect(find.byKey(JudgeBotIds.ticket(_g))).bottom,
        lessThanOrEqualTo(596),
      );
      await end(t);
    });
  });
}
