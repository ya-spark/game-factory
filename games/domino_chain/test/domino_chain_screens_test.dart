import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_domino_chain/domino_chain.dart';

const String _g = dominoChainId;

Map<String, dynamic> _series(int i, {bool long = false, int steps = 4}) => {
  'id': 's.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'series',
  'explanation': 'Because $i',
  'prompt': 'Put the steps $i in order',
  'steps': [
    for (var k = 1; k <= steps; k++)
      long && k == 2
          ? 'Step $k of chain $i with a very long label text'
          : 'S$i-$k',
  ],
};

QuizSession _session(List<Map<String, dynamic>> items, {int year = 1}) {
  final packs = [
    LoadedPack(
      ContentPack({
        'id': 'q',
        'version': 1,
        'lang': 'en-AU',
        'subject': 'english',
        'year': year,
        'topic': 't',
        'title': 'q',
        'items': items,
      }),
    ),
  ];
  return QuizSession(
    items: ReleaseEngine.ordered(packs, 'english', year),
    progress: const ChildProgress(),
    packs: packs,
    rewardsConfig: const RewardsConfig(),
    today: 100,
  );
}

Finder _tile(int i) => find.byKey(DominoChainIds.tile(_g, i));
Finder _slot(int i) => find.byKey(DominoChainIds.slot(_g, i));
Finder _go() => find.byKey(DominoChainIds.go(_g));

class _Reader implements GameReadAloud {
  final List<String> said = [];
  @override
  Future<void> read(String text, {String? audioRef}) async => said.add(text);
  @override
  Future<void> stop() async {}
}

void main() {
  final items = [for (var i = 1; i <= 4; i++) _series(i)];

  /// The text of the tray domino [i] (read before it is placed).
  String text(WidgetTester t, int i) => (t.widget<Text>(
    find.descendant(of: _tile(i), matching: find.byType(Text)),
  )).data!;

  List<String> trayTexts(WidgetTester t, int n) => [
    for (var i = 0; i < n; i++) text(t, i),
  ];

  Future<void> open(
    WidgetTester t, {
    SeriesLevel level = SeriesLevel.younger,
    MiniGameMode mode = MiniGameMode.game,
    List<Map<String, dynamic>>? data,
    List<AnswerResult>? log,
    void Function(int)? onScore,
    VoidCallback? onExit,
    int seed = 3,
    double scale = 1,
    Size size = const Size(400, 900),
    int year = 1,
    GameReadAloud? reader,
    bool reduce = false,
    bool start = true,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(scale),
            size: size,
            disableAnimations: reduce,
          ),
          child: DominoChainScreen(
            session: _session(data ?? items, year: year),
            level: level,
            mode: mode,
            onExit: onExit ?? () {},
            onAnswered: (r, _) => log?.add(r),
            onScore: onScore,
            random: Random(seed),
            reader: reader,
          ),
        ),
      ),
    );
    if (start) {
      await t.ensureVisible(find.byKey(GameIds.mgStart(_g)));
      await t.tap(find.byKey(GameIds.mgStart(_g)));
      await t.pump();
    }
  }

  /// Taps a tray domino, then a slot.
  Future<void> put(WidgetTester t, int tile, int slot) async {
    await t.ensureVisible(_tile(tile));
    await t.tap(_tile(tile));
    await t.pump();
    await t.tap(_slot(slot));
    await t.pump();
  }

  /// Fills the row of chain [chain] (1-based item number) in the right order, or with the
  /// first two slots swapped when [wrong].
  Future<void> fillRow(
    WidgetTester t,
    int chain, {
    bool wrong = false,
    int n = 4,
  }) async {
    final steps = [for (var k = 1; k <= n; k++) 'S$chain-$k'];
    final texts = trayTexts(t, n);
    final order = [...steps];
    if (wrong) {
      final x = order[0];
      order[0] = order[1];
      order[1] = x;
    }
    for (var s = 0; s < n; s++) {
      await put(t, texts.indexOf(order[s]), s);
    }
  }

  Future<void> settle(WidgetTester t) async {
    await t.pump(); // the ticker starts on the first frame
    await t.pump(const Duration(seconds: 4));
    await t.pump();
  }

  group('Domino chain (SPEC: Flow)', () {
    testWidgets('the child sees how to play and no title bar; registry entry', (
      t,
    ) async {
      await open(t, start: false);
      expect(find.byKey(GameIds.mgIntro(_g)), findsOneWidget);
      expect(find.text('Domino chain'), findsNothing);
      expect(find.byType(AppBar), findsNothing);
      expect(
        find.textContaining('Put the steps in the right order'),
        findsOneWidget,
      );
      expect(dominoChainGame.title, 'Domino chain');
      expect(dominoChainGame.id, 'domino_chain');
      expect(dominoChainGame.minPool, 1);
      expect(dominoChainGame.itemTypes, {ItemType.series});
      expect(find.textContaining('Start ('), findsOneWidget);
    });

    testWidgets(
      'a wrong Go shows the broken slot and message, fixing it and Go again topples all the way; two chains end in results',
      (t) async {
        final log = <AnswerResult>[];
        int? score;
        await open(
          t,
          data: [items[0], items[1]],
          log: log,
          onScore: (v) => score = v,
        );
        expect(find.textContaining('Chain 1 of 2'), findsOneWidget);
        final texts = trayTexts(t, 4);
        expect(find.byKey(GameIds.mgTimer(_g)), findsNothing);
        final goBtn = t.widget<FilledButton>(_go());
        expect(goBtn.onPressed, isNull); // not until every slot is full
        await fillRow(t, 1, wrong: true);
        expect(t.widget<FilledButton>(_go()).onPressed, isNotNull);
        await t.tap(_go());
        await t.pump(const Duration(milliseconds: 100));
        await settle(t);
        expect(log, isEmpty); // nothing is scored until it is solved
        expect(find.byKey(DominoChainIds.broken(_g)), findsOneWidget);
        expect(
          find.textContaining('Slot 1 was not the next step'),
          findsOneWidget,
        );
        expect(find.byKey(DominoChainIds.flag(_g)), findsOneWidget);
        // Fix it: take both back and place again, then Go.
        await t.tap(_slot(0));
        await t.pump();
        await t.tap(_slot(1));
        await t.pump();
        expect(find.byKey(DominoChainIds.broken(_g)), findsNothing);
        // tray tiles 0 and 1 were taken back: place in order S1-1, S1-2
        await put(t, texts.indexOf('S1-1'), 0);
        await put(t, texts.indexOf('S1-2'), 1);
        await t.tap(_go());
        await settle(t);
        expect(log, hasLength(1));
        // the sign keeps this chain's prompt after the session moved on
        expect(find.byKey(GameIds.mgPrompt(_g)), findsOneWidget);
        expect(
          (t.widget<Text>(find.byKey(GameIds.mgPrompt(_g)))).data,
          'Put the steps 1 in order',
        );
        expect(log.single.correct, isFalse); // second try: not a first pass
        expect(find.byKey(GameIds.mgFeedback(_g)), findsOneWidget);
        expect(find.textContaining('Flag up'), findsWidgets);
        expect(find.byKey(DominoChainIds.stageStars(_g)), findsNothing);
        await t.tap(find.byKey(GameIds.mgNext(_g)));
        await t.pump();
        expect(find.textContaining('Chain 2 of 2'), findsOneWidget);
        await fillRow(t, 2);
        await t.tap(_go());
        await settle(t);
        expect(log, hasLength(2));
        expect(log.last.correct, isTrue); // first try
        // chain 2 ends the stage: one first try of two = 2 stars
        expect(find.byKey(DominoChainIds.stageStars(_g)), findsOneWidget);
        expect(find.textContaining('2 of 3 stars'), findsOneWidget);
        await t.tap(find.byKey(GameIds.mgNext(_g)));
        await t.pump();
        expect(find.byKey(GameIds.mgResults(_g)), findsOneWidget);
        expect(score, 6 + 10);
      },
    );

    testWidgets('a pool of one is a single chain', (t) async {
      final log = <AnswerResult>[];
      await open(t, data: [items[0]], log: log);
      expect(find.textContaining('Chain 1 of 1'), findsOneWidget);
      await fillRow(t, 1);
      await t.tap(_go());
      await settle(t);
      expect(find.textContaining('See results'), findsOneWidget);
      expect(find.byKey(DominoChainIds.stageStars(_g)), findsOneWidget);
      expect(find.textContaining('3 of 3 stars'), findsWidgets);
      await t.tap(find.byKey(GameIds.mgNext(_g)));
      await t.pump();
      expect(find.byKey(GameIds.mgResults(_g)), findsOneWidget);
      expect(log.single.correct, isTrue);
    });

    testWidgets('no chain is played twice and a session stops at six', (
      t,
    ) async {
      final many = [for (var i = 1; i <= 8; i++) _series(i)];
      await open(t, data: many);
      expect(find.textContaining('Chain 1 of 6'), findsOneWidget);
    });
  });

  group('Domino chain (SPEC: Input)', () {
    testWidgets(
      'tap then slot, tap a placed domino to take it back, drag, swap',
      (t) async {
        await open(t);
        final texts = trayTexts(t, 4);
        await put(t, 0, 2);
        expect(
          find.descendant(of: _slot(2), matching: find.text(texts[0])),
          findsOneWidget,
        );
        // take back by tapping the slot
        await t.tap(_slot(2));
        await t.pump();
        expect(
          find.descendant(of: _slot(2), matching: find.text(texts[0])),
          findsNothing,
        );
        // drag a tray domino into slot 1
        final to = t.getCenter(_slot(1)) - t.getCenter(_tile(1));
        await t.drag(_tile(1), to);
        await t.pump();
        expect(
          find.descendant(of: _slot(1), matching: find.text(texts[1])),
          findsOneWidget,
        );
        // place another, then drag one placed domino onto the other: they swap
        await put(t, 2, 0);
        final swap = t.getCenter(_slot(1)) - t.getCenter(_slot(0));
        await t.drag(
          find.descendant(of: _slot(0), matching: find.text(texts[2])),
          swap,
        );
        await t.pump();
        expect(
          find.descendant(of: _slot(0), matching: find.text(texts[1])),
          findsOneWidget,
        );
        expect(
          find.descendant(of: _slot(1), matching: find.text(texts[2])),
          findsOneWidget,
        );
        // the selected caption shows the full text of a chosen domino
        await t.tap(_tile(3));
        await t.pump();
        expect(find.byKey(DominoChainIds.caption(_g)), findsOneWidget);
        expect(find.textContaining('Selected: ${texts[3]}'), findsOneWidget);
      },
    );

    testWidgets(
      'keyboard: arrows, Enter, 1 to 4, Backspace, Space is Go when full then Next, Esc pauses, Q reads',
      (t) async {
        final reader = _Reader();
        await open(t, reader: reader);
        final texts = trayTexts(t, 4);
        await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pump();
        expect(
          find.descendant(of: _slot(0), matching: find.text(texts[1])),
          findsOneWidget,
        );
        await t.sendKeyEvent(
          LogicalKeyboardKey.enter,
        ); // on a placed one: lift back
        await t.pump();
        expect(
          find.descendant(of: _slot(0), matching: find.text(texts[1])),
          findsNothing,
        );
        await t.sendKeyEvent(
          LogicalKeyboardKey.digit3,
        ); // choose and place domino 3
        await t.pump();
        expect(
          find.descendant(of: _slot(0), matching: find.text(texts[2])),
          findsOneWidget,
        );
        await t.sendKeyEvent(LogicalKeyboardKey.backspace);
        await t.pump();
        expect(
          find.descendant(of: _slot(0), matching: find.text(texts[2])),
          findsNothing,
        );
        await t.sendKeyEvent(LogicalKeyboardKey.keyQ);
        await t.pump();
        expect(reader.said.single, contains('Put the steps 1 in order'));
        // Space with a short row pauses; Space on the pause screen resumes
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.pump();
        expect(find.byKey(GameIds.mgPaused(_g)), findsOneWidget);
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.pump();
        expect(find.byKey(GameIds.mgPaused(_g)), findsNothing);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pump();
        expect(find.byKey(GameIds.mgPaused(_g)), findsOneWidget);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pump();
        // fill the row with the keyboard: right order by number keys, then Space is Go
        final steps = [for (var k = 1; k <= 4; k++) 'S1-$k'];
        for (var s = 0; s < 4; s++) {
          final n = texts.indexOf(steps[s]) + 1;
          await t.sendKeyEvent(
            [
              LogicalKeyboardKey.digit1,
              LogicalKeyboardKey.digit2,
              LogicalKeyboardKey.digit3,
              LogicalKeyboardKey.digit4,
            ][n - 1],
          );
          await t.pump();
        }
        await t.sendKeyEvent(LogicalKeyboardKey.space); // Go
        await settle(t);
        expect(find.byKey(GameIds.mgNext(_g)), findsOneWidget);
        await t.sendKeyEvent(LogicalKeyboardKey.space); // Next
        await t.pump();
        expect(find.textContaining('Chain 2 of'), findsOneWidget);
      },
    );

    testWidgets(
      'Enter is Next after a result, H is a hint, Esc leaves from the start',
      (t) async {
        var left = 0;
        await open(t, onExit: () => left++);
        await t.sendKeyEvent(LogicalKeyboardKey.keyH);
        await t.pump();
        expect(find.textContaining('Hint: slot 1 comes next'), findsOneWidget);
        await fillRow(t, 1);
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await settle(t);
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pump();
        expect(find.textContaining('Chain 2 of'), findsOneWidget);
        expect(left, 0);
      },
    );

    testWidgets('Esc leaves from the intro', (t) async {
      var left = 0;
      await open(t, start: false, onExit: () => left++);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(left, 1);
    });

    testWidgets('Space and Enter start from the intro', (t) async {
      for (final k in [LogicalKeyboardKey.space, LogicalKeyboardKey.enter]) {
        await open(t, start: false);
        await t.sendKeyEvent(k);
        await t.pump();
        expect(find.textContaining('Chain 1 of'), findsOneWidget);
      }
    });

    testWidgets('every button names its key', (t) async {
      await open(t, start: false);
      expect(find.textContaining('Start (Enter)'), findsOneWidget);
      await t.tap(find.byKey(GameIds.mgStart(_g)));
      await t.pump();
      expect(find.text('Go (Space)'), findsOneWidget);
      expect(find.textContaining('(H)'), findsOneWidget);
    });
  });

  group('Domino chain (SPEC: Levels)', () {
    testWidgets('younger: no timer, two hints that light the next slot', (
      t,
    ) async {
      await open(t);
      expect(find.byKey(GameIds.mgTimer(_g)), findsNothing);
      expect(find.text('Hint (H): 2'), findsOneWidget);
      await t.tap(find.byKey(DominoChainIds.hint(_g)));
      await t.pump();
      expect(find.text('Hint (H): 1'), findsOneWidget);
      expect(find.textContaining('Hint: slot 1 comes next'), findsOneWidget);
    });

    testWidgets('a hint makes the chain not a first try for the skill system', (
      t,
    ) async {
      final log = <AnswerResult>[];
      await open(t, log: log);
      await t.tap(find.byKey(DominoChainIds.hint(_g)));
      await t.pump();
      await fillRow(t, 1);
      await t.tap(_go());
      await settle(t);
      expect(log.single.correct, isFalse);
    });

    testWidgets(
      'older: a timer, 1 hint, five dominoes; time up topples the right order',
      (t) async {
        final log = <AnswerResult>[];
        await open(
          t,
          level: SeriesLevel.older,
          data: [_series(1, steps: 5), _series(2, steps: 5)],
          year: 4,
          log: log,
        );
        expect(find.byKey(GameIds.mgTimer(_g)), findsOneWidget);
        expect(find.text('0:40'), findsOneWidget); // 8 s per domino
        expect(find.text('Hint (H): 1'), findsOneWidget);
        expect(_slot(4), findsOneWidget);
        await t.pump(const Duration(seconds: 41));
        await settle(t);
        expect(log, hasLength(1));
        expect(log.single.correct, isFalse);
        expect(find.textContaining("Time's up"), findsWidgets);
        expect(find.byKey(GameIds.mgNext(_g)), findsOneWidget);
      },
    );

    testWidgets('study mode: no timer, two hints, always correct once solved', (
      t,
    ) async {
      final log = <AnswerResult>[];
      await open(
        t,
        level: SeriesLevel.older,
        mode: MiniGameMode.study,
        year: 4,
        log: log,
      );
      expect(find.byKey(GameIds.mgTimer(_g)), findsNothing);
      expect(find.text('Hint (H): 2'), findsOneWidget);
      final texts = trayTexts(t, 4);
      await fillRow(t, 1, wrong: true);
      await t.tap(_go());
      await settle(t);
      await t.tap(_slot(0));
      await t.pump();
      await t.tap(_slot(1));
      await t.pump();
      await put(t, texts.indexOf('S1-1'), 0);
      await put(t, texts.indexOf('S1-2'), 1);
      await t.tap(_go());
      await settle(t);
      expect(log.single.correct, isTrue);
    });

    testWidgets('pause stops the timer', (t) async {
      await open(t, level: SeriesLevel.older, year: 4);
      await t.pump(const Duration(seconds: 5));
      await t.tap(find.byKey(GameIds.mgPause(_g)));
      await t.pump();
      final before = find.byKey(GameIds.mgTimer(_g));
      final shown = (t.widget<Text>(before)).data;
      await t.pump(const Duration(seconds: 10));
      expect((t.widget<Text>(before)).data, shown);
    });
  });

  group('Domino chain (SPEC: Reduced motion)', () {
    testWidgets(
      'Go shows the end state at once and no animation keeps running',
      (t) async {
        await open(t, reduce: true);
        final texts = trayTexts(t, 4);
        await fillRow(t, 1, wrong: true);
        await t.tap(_go());
        await t.pump();
        expect(find.byKey(DominoChainIds.broken(_g)), findsOneWidget);
        expect(find.textContaining('not the next step'), findsOneWidget);
        await t.pump(const Duration(seconds: 1));
        expect(t.binding.transientCallbackCount, 0);
        await t.tap(_slot(0));
        await t.pump();
        await t.tap(_slot(1));
        await t.pump();
        await put(t, texts.indexOf('S1-1'), 0);
        await put(t, texts.indexOf('S1-2'), 1);
        await t.tap(_go());
        await t.pump();
        expect(find.byKey(GameIds.mgNext(_g)), findsOneWidget);
      },
    );
  });

  group('Domino chain (SPEC: Semantics)', () {
    testWidgets('dominoes, slots, Go and the live regions have labels', (
      t,
    ) async {
      final h = t.ensureSemantics();
      await open(t);
      final texts = trayTexts(t, 4);
      expect(
        find.bySemanticsLabel('${texts[0]}, domino, in the tray'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Slot 1 of 4, empty'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Go, fill all 4 slots first'),
        findsOneWidget,
      );
      await put(t, 0, 0);
      expect(
        find.bySemanticsLabel('${texts[0]}, domino, in slot 1'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Slot 1 of 4, ${texts[0]}'), findsOneWidget);
      expect(
        find.textContaining('Placed ${texts[0]} in slot 1'),
        findsOneWidget,
      );
      await t.tap(_tile(1));
      await t.pump();
      expect(
        find.bySemanticsLabel('${texts[1]}, domino, selected'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('^Sign: ')), findsOneWidget);
      h.dispose();
    });
  });

  group('Domino chain (SPEC: Layout)', () {
    final sizes = <Size>[
      const Size(360, 640),
      const Size(390, 844),
      const Size(844, 390),
      const Size(1024, 768),
      const Size(1280, 720),
      const Size(1440, 900),
      const Size(1920, 1080),
    ];
    for (final size in sizes) {
      for (final older in [false, true]) {
        for (final long in [false, true]) {
          for (final scale in [1.0, 1.5]) {
            testWidgets(
              '${size.width.toInt()}x${size.height.toInt()} ${older ? 'older' : 'younger'} ${long ? 'long' : 'short'} text $scale: no overflow, targets 44 dp, no page scroll',
              (t) async {
                final n = older ? 6 : 4;
                final data = [
                  _series(1, long: long, steps: n),
                  _series(2, long: long, steps: n),
                ];
                await open(
                  t,
                  level: older ? SeriesLevel.older : SeriesLevel.younger,
                  data: data,
                  year: older ? 4 : 1,
                  scale: scale,
                  size: Size(size.width, size.height - 44),
                );
                expect(find.text('Domino chain'), findsNothing);
                expect(find.byType(AppBar), findsNothing);
                expect(
                  t.getSize(find.byKey(GameIds.mgExit(_g))),
                  const Size(44, 44),
                );
                expect(
                  t.getSize(find.byKey(GameIds.mgPause(_g))),
                  const Size(44, 44),
                );
                for (var i = 0; i < n; i++) {
                  final s = t.getSize(_tile(i));
                  expect(s.width, greaterThanOrEqualTo(44));
                  expect(s.height, greaterThanOrEqualTo(64));
                  expect(_slot(i), findsOneWidget);
                }
                // Go is on screen
                final goRect = t.getRect(_go());
                expect(
                  goRect.bottom,
                  lessThanOrEqualTo(size.height - 44 + 0.5),
                );
                expect(goRect.top, greaterThanOrEqualTo(0));
                // Nothing but the tray scrolls; at text scale 1.0 not even the tray.
                final tray = find.byKey(DominoChainIds.tray(_g));
                final sc = t.state<ScrollableState>(
                  find.descendant(of: tray, matching: find.byType(Scrollable)),
                );
                // Six long dominoes on a 640 dp tall phone do not fit even at the smallest size: the
                // spec's last resort (the tray scrolls inside itself) applies there.
                final tight = long && older && size.height <= 640;
                if (scale == 1.0 && !tight) {
                  expect(sc.position.maxScrollExtent, 0);
                  final left = find.byKey(DominoChainIds.tableScroll(_g));
                  if (left.evaluate().isNotEmpty) {
                    final ls = t.state<ScrollableState>(
                      find.descendant(
                        of: left,
                        matching: find.byType(Scrollable),
                      ),
                    );
                    expect(ls.position.maxScrollExtent, 0);
                  }
                }
                expect(t.takeException(), isNull);
              },
            );
          }
        }
      }
    }
  });
}
