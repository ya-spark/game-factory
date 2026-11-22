import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_parcel_train/parcel_train.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Host extends NoGameHost {
  _Host({this.reduce = false});
  final bool reduce;
  final List<int> coins = [];
  @override
  Future<void> addCoins(BuildContext context, int n) async => coins.add(n);
  @override
  bool reduceMotion(BuildContext context) => reduce;
}

class _H {
  _H(this.tester, this.host, this.scores, this.sounds);
  final WidgetTester tester;
  final _Host host;
  final List<int> scores;
  final List<String> sounds;
}

Future<_H> _open(
  WidgetTester t, {
  Size size = const Size(390, 844),
  double text = 1.0,
  Map<String, Object> prefs = const {},
  TrainGame Function(TrainCourse?, int)? builder,
  bool reduce = false,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final host = _Host(reduce: reduce);
  final scores = <int>[];
  final sounds = <String>[];
  await t.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(text)),
        child: GameHostScope(
          host: host,
          child: ParcelTrainScreen(
            onScore: scores.add,
            random: Random(3),
            onSound: sounds.add,
            gameBuilder: builder,
          ),
        ),
      ),
    ),
  );
  await t.pump(const Duration(milliseconds: 100));
  return _H(t, host, scores, sounds);
}

Future<void> _run(WidgetTester t, double seconds) async {
  for (var i = 0; i < (seconds * 20).round(); i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _key(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyEvent(k);
  await t.pump(const Duration(milliseconds: 20));
}

Finder _id(Key k) => find.byKey(k);

String _liveText(WidgetTester t) =>
    t.widget<Semantics>(_id(ParcelTrainIds.live)).properties.label ?? '';

/// A course game with the engine on the cell before the open gate, parcels done.
TrainGame _almostThere(TrainCourse? c, int derails) {
  final cr = c ?? trainCourses[0];
  final g = TrainGame(course: cr, derailsBefore: derails, random: Random(1));
  g.eaten = cr.goal;
  g.gateOpen = true;
  g.goldenTaken = true;
  g.golden = null;
  g.body
    ..clear()
    ..addAll([
      TrainCell(cr.gate.x - 1, cr.gate.y),
      TrainCell(cr.gate.x - 2, cr.gate.y),
      TrainCell(cr.gate.x - 3, cr.gate.y),
    ]);
  g.prevBody = List.of(g.body);
  return g;
}

void main() {
  group('Flow', () {
    testWidgets('menu shows Play, Free ride, How to play, five chips, best', (
      t,
    ) async {
      await _open(t);
      for (final k in [
        ParcelTrainIds.play,
        ParcelTrainIds.free,
        ParcelTrainIds.howTo,
        ParcelTrainIds.best,
        ParcelTrainIds.wrap,
        for (var i = 0; i < 5; i++) ParcelTrainIds.course(i),
      ]) {
        expect(_id(k), findsOneWidget, reason: '$k');
      }
      expect(find.byType(AppBar), findsNothing, reason: 'no title bar');
      expect(find.textContaining('Continue'), findsNothing);
      expect(find.textContaining('Remove ads'), findsNothing);
    });

    testWidgets(
      'Enter plays: ready beat, then the train runs and a parcel is picked',
      (t) async {
        final h = await _open(t);
        await _key(t, LogicalKeyboardKey.enter);
        expect(_id(ParcelTrainIds.ready), findsOneWidget);
        expect(_id(ParcelTrainIds.parcels), findsOneWidget);
        await _run(t, 1.1);
        expect(_id(ParcelTrainIds.ready), findsNothing);
        // the first parcel is 4 cells straight ahead: 4 moves of 0.26 s
        await _run(t, 1.4);
        expect(find.text('1 / 5'), findsOneWidget);
        expect(find.text('10'), findsOneWidget);
        expect(h.sounds, containsAll(['toot', 'parcel', 'couple']));
      },
    );

    testWidgets('Space also plays from the menu; F starts Free ride', (
      t,
    ) async {
      await _open(t);
      await _key(t, LogicalKeyboardKey.space);
      expect(_id(ParcelTrainIds.ready), findsOneWidget);
      expect(_id(ParcelTrainIds.bumpers), findsOneWidget);
      await _key(t, LogicalKeyboardKey.escape); // pause
      await t.tap(_id(ParcelTrainIds.leave));
      await t.pump();
      expect(_id(ParcelTrainIds.menu), findsOneWidget);
      await _key(t, LogicalKeyboardKey.keyF);
      expect(_id(ParcelTrainIds.ready), findsOneWidget);
      expect(
        _id(ParcelTrainIds.bumpers),
        findsNothing,
        reason: 'Free ride has no bumpers',
      );
      expect(_id(ParcelTrainIds.score), findsOneWidget);
    });

    testWidgets(
      'bumps use a bumper, the 4th hit derails and the course restarts',
      (t) async {
        final h = await _open(t);
        await _key(t, LogicalKeyboardKey.enter);
        await _run(t, 1.1);
        await _key(t, LogicalKeyboardKey.arrowUp);
        await _run(t, 2.0); // top wall: bump 1
        expect(h.sounds, contains('bump'));
        await _key(t, LogicalKeyboardKey.arrowRight);
        await _run(t, 2.6); // right wall: bump 2
        await _key(t, LogicalKeyboardKey.arrowDown);
        await _run(t, 1.8); // the closed gate: bump 3
        await _key(t, LogicalKeyboardKey.arrowLeft);
        await _run(t, 3.8); // left wall: derail
        expect(h.sounds, contains('derail'));
        expect(_id(ParcelTrainIds.derail), findsOneWidget);
        await _key(t, LogicalKeyboardKey.enter); // skips the beat
        expect(_id(ParcelTrainIds.ready), findsOneWidget);
        expect(_id(ParcelTrainIds.derail), findsNothing);
        expect(find.text('0 / 5'), findsOneWidget);
      },
    );

    testWidgets(
      'arrival: results with stars, coins, Next course; saved and unlocks',
      (t) async {
        final h = await _open(t, builder: _almostThere);
        await _key(t, LogicalKeyboardKey.enter);
        await _run(t, 1.1);
        await _run(t, 2.0);
        expect(_id(ParcelTrainIds.results), findsOneWidget);
        expect(find.text('Station reached!'), findsOneWidget);
        expect(find.text('Score 95'), findsOneWidget);
        expect(h.host.coins, [4]);
        await _run(t, 1.5);
        final stars = t.widget<Semantics>(
          find.descendant(
            of: _id(ParcelTrainIds.results),
            matching: find.bySemanticsLabel('3 of 3 stars'),
          ),
        );
        expect(stars, isNotNull);
        expect(h.scores, isEmpty, reason: 'courses do not feed the Games tab');
        final p = await SharedPreferences.getInstance();
        expect(p.getStringList(TrainProgress.coursesKey), [
          '3',
          '0',
          '0',
          '0',
          '0',
        ]);
        // Enter goes to the next course
        await _key(t, LogicalKeyboardKey.enter);
        expect(_id(ParcelTrainIds.ready), findsOneWidget);
        expect(_liveText(t), contains('Course 2'));
      },
    );

    testWidgets('Left and Right pick Replay or Next on the results', (t) async {
      await _open(t, builder: _almostThere);
      await _key(t, LogicalKeyboardKey.enter);
      await _run(t, 5);
      await _key(t, LogicalKeyboardKey.arrowRight);
      await _key(t, LogicalKeyboardKey.enter);
      expect(_liveText(t), contains('Course 1'));
      await _run(t, 6);
      await _key(t, LogicalKeyboardKey.keyR);
      expect(_liveText(t), contains('Course 1'));
    });

    testWidgets(
      'Free ride ends at the first hit: results, coins, onScore, best',
      (t) async {
        final h = await _open(t);
        await _key(t, LogicalKeyboardKey.keyF);
        await _run(t, 1.1);
        await _run(t, 2.3); // picks the parcel 4 ahead, then runs on
        await _run(t, 3); // the right wall
        expect(_id(ParcelTrainIds.results), findsOneWidget);
        expect(h.scores, hasLength(1));
        expect(h.scores.single, greaterThanOrEqualTo(10));
        expect(find.text('Play again'), findsNothing);
        expect(find.textContaining('Play again'), findsOneWidget);
        expect(find.text('Score ${h.scores.single}'), findsOneWidget);
        final p = await SharedPreferences.getInstance();
        expect(p.getInt('arcade.parcel_train.best'), h.scores.single);
        await _key(t, LogicalKeyboardKey.enter);
        expect(_id(ParcelTrainIds.ready), findsOneWidget);
      },
    );
  });

  group('Input', () {
    testWidgets('arrows and W A S D steer; pad buttons and swipe too', (
      t,
    ) async {
      await _open(t, builder: (c, d) => TrainGame(random: Random(1)));
      await _key(t, LogicalKeyboardKey.keyF);
      await _run(t, 1.1);
      await _key(t, LogicalKeyboardKey.keyW);
      await _run(t, 0.5);
      await t.tap(_id(ParcelTrainIds.padKey('left')));
      await _run(t, 0.3);
      await t.drag(_id(ParcelTrainIds.field), const Offset(0, 80));
      await _run(t, 0.3);
      expect(t.takeException(), isNull);
    });

    testWidgets('Space, P and Esc pause; any of them resumes', (t) async {
      await _open(t);
      await _key(t, LogicalKeyboardKey.enter);
      await _run(t, 1.2);
      for (final k in [
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.keyP,
        LogicalKeyboardKey.escape,
      ]) {
        await _key(t, k);
        expect(_id(ParcelTrainIds.paused), findsOneWidget, reason: '$k pauses');
        await _key(t, k);
        expect(_id(ParcelTrainIds.paused), findsNothing, reason: '$k resumes');
      }
      await t.tap(_id(ParcelTrainIds.pause));
      await t.pump();
      expect(_id(ParcelTrainIds.paused), findsOneWidget);
      await _key(t, LogicalKeyboardKey.enter);
      expect(_id(ParcelTrainIds.paused), findsNothing);
    });

    testWidgets(
      'digits open courses; locked ones say why; H opens the how-to; Enter closes it',
      (t) async {
        await _open(t);
        await _key(t, LogicalKeyboardKey.digit3);
        expect(find.text('Finish course 2 first'), findsOneWidget);
        expect(_id(ParcelTrainIds.menu), findsOneWidget);
        await _key(t, LogicalKeyboardKey.keyH);
        await _run(t, 0.5);
        expect(_id(ParcelTrainIds.howToDialog), findsOneWidget);
        await _key(t, LogicalKeyboardKey.enter);
        await _run(t, 0.5);
        expect(_id(ParcelTrainIds.howToDialog), findsNothing);
        await _key(t, LogicalKeyboardKey.digit1);
        expect(_id(ParcelTrainIds.ready), findsOneWidget);
      },
    );

    testWidgets('the tunnel edges switch is kept (T and the switch)', (
      t,
    ) async {
      await _open(t);
      await _key(t, LogicalKeyboardKey.keyT);
      expect(t.widget<Switch>(_id(ParcelTrainIds.wrap)).value, isTrue);
      final p = await SharedPreferences.getInstance();
      expect(p.getBool(TrainProgress.wrapKey), isTrue);
    });

    testWidgets('Q reads where the parcel is', (t) async {
      await _open(t);
      await _key(t, LogicalKeyboardKey.keyF);
      await _key(t, LogicalKeyboardKey.keyQ);
      expect(_liveText(t), 'Parcel: 4 cells right');
    });
  });

  group('Progression and saved data', () {
    testWidgets('locked chips unlock with one star; saved stars show', (
      t,
    ) async {
      await _open(
        t,
        prefs: {
          TrainProgress.coursesKey: ['2', '1', '0', '0', '0'],
        },
      );
      await t.pump(const Duration(milliseconds: 100));
      await _key(t, LogicalKeyboardKey.digit3);
      expect(_id(ParcelTrainIds.ready), findsOneWidget);
    });

    testWidgets('the old Snake keys move to the new ones', (t) async {
      await _open(
        t,
        prefs: {'arcade.snake.best': 120, 'arcade.snake.wrap': true},
      );
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('Best 120'), findsOneWidget);
      final p = await SharedPreferences.getInstance();
      expect(p.getInt('arcade.snake.best'), isNull);
      expect(p.getInt('arcade.parcel_train.best'), 120);
      expect(p.getBool('arcade.parcel_train.wrap'), isTrue);
    });

    test(
      'migrate keeps the higher best and does not overwrite the wrap',
      () async {
        SharedPreferences.setMockInitialValues({
          'arcade.snake.best': 50,
          'arcade.parcel_train.best': 80,
          'arcade.snake.wrap': true,
          'arcade.parcel_train.wrap': false,
        });
        final p = await SharedPreferences.getInstance();
        await TrainProgress.migrate(p);
        expect(p.getInt('arcade.parcel_train.best'), 80);
        expect(p.getBool('arcade.parcel_train.wrap'), isFalse);
        expect(p.containsKey('arcade.snake.best'), isFalse);
      },
    );

    test('a course replay keeps the higher stars and score', () async {
      SharedPreferences.setMockInitialValues({});
      final prog = TrainProgress(await SharedPreferences.getInstance());
      await prog.recordCourse(1, 2, 90);
      await prog.recordCourse(1, 1, 120);
      expect(prog.stars, [0, 2, 0, 0, 0]);
      expect(prog.courseBest, [0, 90 > 120 ? 90 : 120, 0, 0, 0]);
    });
  });

  group('Juice, sound hooks and reduced motion', () {
    testWidgets(
      'a bump fires its hook; with reduced motion the round still plays',
      (t) async {
        for (final reduce in [false, true]) {
          final h = await _open(t, reduce: reduce);
          await _key(t, LogicalKeyboardKey.enter);
          await _run(t, 1.1);
          await _key(t, LogicalKeyboardKey.arrowUp);
          await _run(t, 2.0);
          expect(h.sounds, contains('bump'));
          expect(_liveText(t), startsWith('Bumped'));
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        }
      },
    );
  });

  group('Semantics', () {
    testWidgets('field label, chips and buttons are labelled', (t) async {
      final sem = t.ensureSemantics();
      await _open(t);
      expect(find.bySemanticsLabel(RegExp(r'^Play, key')), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'^Course 2, Block yard, locked')),
        findsOneWidget,
      );
      await _key(t, LogicalKeyboardKey.enter);
      await _run(t, 1.2);
      expect(
        find.bySemanticsLabel(
          RegExp(
            r'Parcel train, Course 1, Playmat, 0 of 5 parcels, 3 bumpers left',
          ),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp(r'^Turn left, key')), findsOneWidget);
      sem.dispose();
    });
  });

  group('Keys shown on every button', () {
    testWidgets('menu, play, pause and results buttons carry their key', (
      t,
    ) async {
      await _open(t, builder: _almostThere);
      String label(Key k) => (t.widget(_id(k)) as dynamic).child is Semantics
          ? (((t.widget(_id(k)) as dynamic).child as Semantics)
                    .properties
                    .label ??
                '')
          : '';
      expect(label(ParcelTrainIds.play), contains('Enter'));
      expect(label(ParcelTrainIds.free), contains('F'));
      expect(label(ParcelTrainIds.howTo), contains('H'));
      expect(find.textContaining('Tunnel edges  T'), findsOneWidget);
      await _key(t, LogicalKeyboardKey.enter);
      await _run(t, 1.2);
      expect(
        find.descendant(
          of: _id(ParcelTrainIds.pause),
          matching: find.text('P'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _id(ParcelTrainIds.exit),
          matching: find.text('Esc'),
        ),
        findsOneWidget,
      );
      for (final d in ['left', 'up', 'down', 'right']) {
        expect(
          find.descendant(
            of: _id(ParcelTrainIds.padKey(d)),
            matching: find.byType(Text),
          ),
          findsOneWidget,
        );
      }
      await _run(t, 5);
      expect(label(ParcelTrainIds.next), contains('Enter'));
      expect(label(ParcelTrainIds.replay), contains('R'));
      expect(label(ParcelTrainIds.done), contains('Esc'));
    });
  });

  group('Layout', () {
    const sizes = [
      Size(360, 640),
      Size(390, 844),
      Size(844, 390),
      Size(1024, 768),
      Size(1280, 720),
      Size(1440, 900),
      Size(1920, 1036),
    ];
    for (final size in sizes) {
      for (final text in [1.0, 1.5]) {
        testWidgets(
          '${size.width.toInt()}x${size.height.toInt()} text $text: no overflow, cells at least 24, buttons 44',
          (t) async {
            await _open(t, size: size, text: text);
            expect(t.takeException(), isNull, reason: 'menu');
            expect(find.byType(AppBar), findsNothing);
            expect(_id(ParcelTrainIds.play), findsOneWidget);
            await _key(t, LogicalKeyboardKey.digit1);
            await _run(t, 1.5);
            expect(t.takeException(), isNull, reason: 'play');
            final fieldBox = t.getSize(_id(ParcelTrainIds.field));
            final cell = fieldBox.width / 13;
            expect(cell, greaterThanOrEqualTo(24 - 0.01), reason: 'cell $cell');
            expect(fieldBox.height, lessThanOrEqualTo(size.height));
            for (final k in [ParcelTrainIds.pause, ParcelTrainIds.exit]) {
              final s = t.getSize(_id(k));
              expect(s.height, greaterThanOrEqualTo(44));
              expect(s.width, greaterThanOrEqualTo(44));
            }
            final shown = size.width < 600 || size.height < 460;
            expect(
              _id(ParcelTrainIds.pad),
              shown ? findsOneWidget : findsNothing,
            );
            expect(
              _id(ParcelTrainIds.keys),
              (size.width >= 600 && size.height >= 460)
                  ? findsOneWidget
                  : findsNothing,
            );
            if (shown) {
              for (final d in ['left', 'up', 'down', 'right']) {
                final s = t.getSize(_id(ParcelTrainIds.padKey(d)));
                expect(s.width, greaterThanOrEqualTo(44));
                expect(s.height, greaterThanOrEqualTo(44));
              }
            }
            // everything fits the screen (the page never scrolls)
            final all = t.getRect(_id(ParcelTrainIds.field));
            expect(all.bottom, lessThanOrEqualTo(size.height + 0.5));
            expect(all.right, lessThanOrEqualTo(size.width + 0.5));
          },
        );
      }
    }
  });

  testWidgets('every course opens and is playable (a tick or two)', (t) async {
    final digits = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
    ];
    await _open(
      t,
      prefs: {
        TrainProgress.coursesKey: ['1', '1', '1', '1', '0'],
      },
    );
    for (var i = 1; i <= 5; i++) {
      await _key(t, digits[i - 1]);
      await _run(t, 1.5);
      expect(t.takeException(), isNull, reason: 'course $i');
      expect(find.text('0 / ${trainCourses[i - 1].goal}'), findsOneWidget);
      await _key(t, LogicalKeyboardKey.escape);
      await t.tap(_id(ParcelTrainIds.leave));
      await t.pump();
    }
  });
}
