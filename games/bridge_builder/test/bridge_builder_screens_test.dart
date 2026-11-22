import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_bridge_builder/bridge_builder.dart';

Map<String, dynamic> _numeric(int i, int answer) => {
  'id': 'n.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'numeric',
  'explanation': 'Because $i',
  'prompt': 'Question $i',
  'answer': answer,
};

List<LoadedPack> _packs(List<Map<String, dynamic>> items, int year) => [
  LoadedPack(
    ContentPack({
      'id': 'q',
      'version': 1,
      'lang': 'en-AU',
      'subject': 'maths',
      'year': year,
      'topic': 't',
      'title': 'q',
      'items': items,
    }),
  ),
];

QuizSession _session(List<Map<String, dynamic>> items, {int year = 4}) {
  final packs = _packs(items, year);
  return QuizSession(
    items: ReleaseEngine.ordered(packs, 'maths', year),
    progress: const ChildProgress(),
    packs: packs,
    rewardsConfig: const RewardsConfig(),
    today: 100,
  );
}

const String _g = bridgeBuilderId;
Finder _tile(int i) => find.byKey(BridgeBuilderIds.mgTile(_g, i));
Finder _slot(int i) => find.byKey(BridgeBuilderIds.mgSlot(_g, i));

void main() {
  final items = [for (var i = 1; i <= 4; i++) _numeric(i, 5 + i)];

  List<String> tileTexts(WidgetTester t, int n) => [
    for (var i = 0; i < n; i++)
      (t.widget<Text>(
        find.descendant(of: _tile(i), matching: find.byType(Text)),
      )).data!,
  ];

  /// Tile indexes (in slot order) of a sum of [len] distinct tiles that does or does not hit [target].
  List<int> sum(
    List<String> texts,
    int target, {
    required bool hit,
    int len = 3,
  }) {
    final n = texts.length;
    for (var a = 0; a < n; a++) {
      for (var b = 0; b < n; b++) {
        for (var c = 0; c < n; c++) {
          if ({a, b, c}.length < 3) continue;
          final ok = sumHitsTarget([texts[a], texts[b], texts[c]], target);
          final shaped =
              !isOperator(texts[a]) &&
              isOperator(texts[b]) &&
              !isOperator(texts[c]);
          if (shaped && ok == hit) return [a, b, c];
        }
      }
    }
    fail('no ${hit ? 'right' : 'wrong'} sum in $texts for $target');
  }

  /// Tap a tile, then a slot.
  Future<void> put(WidgetTester t, int tile, int slot) async {
    await t.ensureVisible(_tile(tile));
    await t.tap(_tile(tile));
    await t.pump();
    await t.tap(_slot(slot));
    await t.pump();
  }

  Future<void> fill(WidgetTester t, List<int> tiles) async {
    for (var s = 0; s < tiles.length; s++) {
      await put(t, tiles[s], s);
    }
  }

  Future<void> open(
    WidgetTester t, {
    required MiniGameLevel level,
    List<AnswerResult>? log,
    void Function(int)? onScore,
    VoidCallback? onExit,
    int seed = 3,
    double scale = 1,
    bool study = false,
    Size size = const Size(400, 900),
    int year = 1,
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
          ),
          child: BridgeBuilderScreen(
            session: _session(items, year: year),
            level: level,
            study: study,
            onExit: onExit ?? () {},
            onAnswered: (r, _) => log?.add(r),
            onScore: onScore,
            random: Random(seed),
          ),
        ),
      ),
    );
    await t.ensureVisible(find.byKey(GameIds.mgStart(_g)));
    await t.tap(find.byKey(GameIds.mgStart(_g)));
    await t.pump();
  }

  Future<void> solve(WidgetTester t, int target, {int slots = 3}) async {
    await fill(t, sum(tileTexts(t, 4), target, hit: true));
  }

  group('Bridge builder (SPEC: Flow)', () {
    testWidgets(
      'the child sees the title Bridge builder, how to play and no title bar',
      (t) async {
        t.view.physicalSize = const Size(400, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          MaterialApp(
            home: BridgeBuilderScreen(
              session: _session(items, year: 1),
              level: const MiniGameLevel.younger(),
              onExit: () {},
            ),
          ),
        );
        expect(find.byKey(GameIds.mgIntro(_g)), findsOneWidget);
        // The host shows the name; the game draws no title strip of its own.
        expect(find.text('Bridge builder'), findsNothing);
        expect(find.byKey(GameIds.mgExit(_g)), findsOneWidget);
        expect(find.text('Bridge builder'), findsNothing);
        expect(find.byType(AppBar), findsNothing);
        expect(find.textContaining('stuck at a gap'), findsOneWidget);
        expect(bridgeBuilderGame.title, 'Bridge builder');
        expect(bridgeBuilderGame.id, 'bridge_builder');
      },
    );

    testWidgets(
      'younger: tap tile then slot, a right sum lays a plank and the robot crosses; four bridges end in results with a score',
      (t) async {
        final log = <AnswerResult>[];
        int? score;
        await open(
          t,
          level: const MiniGameLevel.younger(),
          log: log,
          onScore: (v) => score = v,
        );
        expect(find.byKey(GameIds.mgTimer(_g)), findsNothing);
        expect(find.byKey(GameIds.mgBanner(_g)), findsNothing);
        expect(find.byKey(BridgeBuilderIds.mgSign(_g)), findsOneWidget);
        expect(find.text('6'), findsWidgets); // the sign
        for (var i = 0; i < 3; i++) {
          expect(_slot(i), findsOneWidget);
        }
        expect(_slot(3), findsNothing);
        // A wrong full sum wobbles and the planks fall back; no penalty.
        await fill(t, sum(tileTexts(t, 4), 6, hit: false));
        expect(log, isEmpty);
        expect(find.byKey(BridgeBuilderIds.mgGhost(_g)), findsOneWidget);
        expect(find.textContaining('Not yet'), findsOneWidget);
        for (var i = 0; i < 3; i++) {
          expect(
            find
                .descendant(
                  of: _slot(i),
                  matching: find.textContaining(RegExp(r'[0-9+−×÷]')),
                )
                .evaluate()
                .map((e) => (e.widget as Text).data)
                .where((d) => d != '${i + 1}'),
            isEmpty,
          );
        }
        await t.pump(const Duration(seconds: 1));
        expect(find.byKey(BridgeBuilderIds.mgGhost(_g)), findsNothing);
        await solve(t, 6);
        expect(log, hasLength(1));
        expect(
          log.single.correct,
          isFalse,
        ); // a miss first, so not a first pass
        expect(find.byKey(BridgeBuilderIds.mgPlank(_g)), findsOneWidget);
        expect(find.textContaining('Plank laid'), findsOneWidget);
        for (var q = 2; q <= 4; q++) {
          await t.tap(find.byKey(GameIds.mgNext(_g)));
          await t.pump();
          await solve(t, 5 + q);
        }
        expect(log.skip(1).every((r) => r.correct), isTrue);
        // The first stage (3 bridges) ended at the flag with stars.
        await t.tap(find.byKey(GameIds.mgNext(_g)));
        await t.pump();
        expect(find.byKey(GameIds.mgResults(_g)), findsOneWidget);
        expect(score, 40);
      },
    );

    testWidgets(
      'a stage ends at the flag with stars, and the next stage changes the scenery',
      (t) async {
        await open(t, level: const MiniGameLevel.younger());
        for (var q = 1; q <= 3; q++) {
          expect(
            find.byKey(BridgeBuilderIds.mgFlag(_g)),
            q == 3 ? findsOneWidget : findsNothing,
          );
          await solve(t, 5 + q);
          if (q < 3) {
            await t.tap(find.byKey(GameIds.mgNext(_g)));
            await t.pump();
          }
        }
        expect(find.byKey(BridgeBuilderIds.mgStageStars(_g)), findsOneWidget);
        expect(find.textContaining('3 of 3 stars'), findsOneWidget);
        expect(find.text('Next stage'), findsOneWidget);
        await t.tap(find.byKey(GameIds.mgNext(_g)));
        await t.pump();
        expect(find.textContaining('Stage 2'), findsOneWidget);
      },
    );

    testWidgets('a single number that equals the target is not a sum', (
      t,
    ) async {
      final log = <AnswerResult>[];
      await open(t, level: const MiniGameLevel.older(), log: log);
      final texts = tileTexts(t, 6);
      final i = texts.indexOf('6');
      if (i >= 0) {
        await put(t, i, 0);
        expect(log, isEmpty);
      }
      expect(
        t
            .widget<FilledButton>(find.byKey(BridgeBuilderIds.mgCheck(_g)))
            .onPressed,
        isNull,
      );
    });
  });

  group('Bridge builder (SPEC: Input)', () {
    testWidgets(
      'drag a tile into a slot; tap a filled slot to take it back; Clear empties the slots',
      (t) async {
        await open(t, level: const MiniGameLevel.younger());
        final texts = tileTexts(t, 4);
        final from = t.getCenter(_tile(0));
        final to = t.getCenter(_slot(1));
        await t.dragFrom(from, to - from);
        await t.pumpAndSettle();
        expect(
          find.descendant(of: _slot(1), matching: find.text(texts[0])),
          findsOneWidget,
        );
        await t.tap(_slot(1));
        await t.pump();
        expect(
          find.descendant(of: _slot(1), matching: find.text(texts[0])),
          findsNothing,
        );
        await put(t, 0, 0);
        await t.tap(find.byKey(BridgeBuilderIds.mgClear(_g)));
        await t.pump();
        expect(
          find.descendant(of: _slot(0), matching: find.text(texts[0])),
          findsNothing,
        );
      },
    );

    testWidgets(
      'keyboard: arrows choose, Enter places, Backspace takes back, 1 to 4 pick tiles',
      (t) async {
        final log = <AnswerResult>[];
        await open(t, level: const MiniGameLevel.younger(), log: log);
        final texts = tileTexts(t, 4);
        Finder inSlot(int s, String x) =>
            find.descendant(of: _slot(s), matching: find.text(x));
        await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await t.pump();
        await t.sendKeyEvent(LogicalKeyboardKey.enter); // tile 1 into slot 0
        await t.pump();
        expect(inSlot(0, texts[1]), findsOneWidget);
        await t.sendKeyEvent(LogicalKeyboardKey.digit4); // tile 4 into slot 1
        await t.pump();
        expect(inSlot(1, texts[3]), findsOneWidget);
        await t.sendKeyEvent(LogicalKeyboardKey.backspace);
        await t.pump();
        expect(inSlot(1, texts[3]), findsNothing);
        expect(inSlot(0, texts[1]), findsOneWidget);
        // Finish a right sum by the keys alone.
        await t.sendKeyEvent(LogicalKeyboardKey.backspace);
        await t.pump();
        final right = sum(texts, 6, hit: true);
        for (final i in right) {
          await t.sendKeyEvent(
            [
              LogicalKeyboardKey.digit1,
              LogicalKeyboardKey.digit2,
              LogicalKeyboardKey.digit3,
              LogicalKeyboardKey.digit4,
            ][i],
          );
          await t.pump();
        }
        expect(log, hasLength(1));
        expect(log.single.correct, isTrue);
      },
    );

    testWidgets(
      'Space is Next after a result and pauses in play; Esc pauses and then leaves',
      (t) async {
        var left = 0;
        await open(
          t,
          level: const MiniGameLevel.younger(),
          onExit: () => left++,
        );
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.pump();
        expect(find.byKey(GameIds.mgPaused(_g)), findsOneWidget);
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.pump();
        expect(find.byKey(GameIds.mgPaused(_g)), findsNothing);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pump();
        expect(find.byKey(GameIds.mgPaused(_g)), findsOneWidget);
        await t.tap(find.byKey(GameIds.mgLeave(_g)));
        expect(left, 1);
        await t.sendKeyEvent(LogicalKeyboardKey.escape); // resumes
        await t.pump();
        expect(find.byKey(GameIds.mgPaused(_g)), findsNothing);
        await solve(t, 6);
        expect(find.byKey(GameIds.mgNext(_g)), findsOneWidget);
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.pump();
        expect(find.textContaining('Bridge 2 of'), findsOneWidget);
      },
    );

    testWidgets(
      'key hints show on a wide window; every tile, slot and plank has a screen-reader label',
      (t) async {
        final h = t.ensureSemantics();
        await open(
          t,
          level: const MiniGameLevel.younger(),
          size: const Size(1000, 800),
        );
        expect(find.byKey(KeyIds.hints), findsOneWidget);
        expect(find.text('Backspace'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(r'^Sign: make 6')), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp(r'^Slot [123] of 3, empty$')),
          findsNWidgets(3),
        );
        expect(find.bySemanticsLabel(RegExp(r' tile$')), findsNWidgets(4));
        await solve(t, 6);
        expect(
          find.bySemanticsLabel(RegExp(r'^Slot [123] of 3, [^e]')),
          findsNWidgets(3),
        );
        h.dispose();
      },
    );
  });

  group('Bridge builder (SPEC: Levels)', () {
    testWidgets(
      'older: five slots, a gentle timer, a wrong sum by Lay plank wobbles; time running out lays a working sum',
      (t) async {
        final log = <AnswerResult>[];
        await open(
          t,
          level: const MiniGameLevel.older(),
          log: log,
          scale: 1.5,
          year: 4,
        );
        expect(find.byKey(GameIds.mgTimer(_g)), findsOneWidget);
        for (var i = 0; i < 5; i++) {
          expect(_slot(i), findsOneWidget);
        }
        final bad = sum(tileTexts(t, 6), 6, hit: false);
        await fill(t, bad);
        await t.tap(find.byKey(BridgeBuilderIds.mgCheck(_g)));
        await t.pump();
        expect(log, isEmpty);
        expect(find.textContaining('Not yet'), findsOneWidget);
        await t.pump(const Duration(seconds: 61));
        expect(log, hasLength(1));
        expect(log.single.correct, isFalse);
        expect(find.textContaining("Time's up"), findsOneWidget);
        expect(find.textContaining('= 6'), findsWidgets);
        await t.pumpWidget(const SizedBox());
      },
    );

    testWidgets('study mode has no timer even for older years', (t) async {
      await open(t, level: const MiniGameLevel.older(), study: true, year: 4);
      expect(find.byKey(GameIds.mgTimer(_g)), findsNothing);
    });

    testWidgets('paused: the timer stops and no tile can be placed', (t) async {
      final log = <AnswerResult>[];
      await open(t, level: const MiniGameLevel.older(), log: log, year: 4);
      await t.tap(find.byKey(GameIds.mgPause(_g)));
      await t.pump();
      await t.pump(const Duration(seconds: 70));
      expect(log, isEmpty);
      await t.tap(find.byKey(GameIds.mgResume(_g)));
      await t.pump();
      expect(find.byKey(GameIds.mgPaused(_g)), findsNothing);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('Bridge builder (SPEC: Layout)', () {
    for (final size in const [
      Size(360, 640),
      Size(390, 844),
      Size(844, 390),
      Size(1280, 720),
      Size(1440, 900),
      Size(1920, 1080),
    ]) {
      for (final scale in const [1.0, 1.5]) {
        for (final older in [false, true]) {
          testWidgets(
            'plays at ${size.width.toInt()}x${size.height.toInt()}, text ${scale}x, ${older ? 'older' : 'younger'}: no title, exit and pause, no overflow, stage fits',
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
              expect(find.text('Bridge builder'), findsNothing);
              expect(find.byType(AppBar), findsNothing);
              expect(find.byKey(GameIds.mgExit(_g)), findsOneWidget);
              expect(find.byKey(GameIds.mgPause(_g)), findsOneWidget);
              expect(t.getSize(find.byKey(GameIds.mgPause(_g))).width, 44);
              final scene = t.getRect(find.byKey(BridgeBuilderIds.mgScene(_g)));
              expect(scene.top, greaterThanOrEqualTo(0));
              expect(scene.bottom, lessThanOrEqualTo(game.height));
              expect(scene.right, lessThanOrEqualTo(game.width));
              // The tray (controls and tiles) is on screen without scrolling the page; the first tile and
              // the Lay plank button are inside the window.
              final tile = t.getRect(_tile(0));
              expect(tile.bottom, lessThanOrEqualTo(game.height));
              expect(
                (scene.center.dx - game.width / 2).abs(),
                lessThan(game.width * 0.3),
              );
              // At normal text size nothing scrolls inside the game at all.
              if (scale == 1.0) {
                final st = t.state<ScrollableState>(
                  find.descendant(
                    of: find.byKey(BridgeBuilderIds.mgTray(_g)),
                    matching: find.byType(Scrollable),
                  ),
                );
                expect(st.position.maxScrollExtent, 0);
              }
              // Pause covers the game and resumes.
              await t.tap(find.byKey(GameIds.mgPause(_g)));
              await t.pump();
              expect(find.byKey(GameIds.mgPaused(_g)), findsOneWidget);
              expect(t.takeException(), isNull);
              await t.pumpWidget(const SizedBox());
            },
          );
        }
      }
    }
  });
}
