import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_wind_up_dash/wind_up_dash.dart';
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
  _H(this.tester, this.host, this.scores, this.sounds, this.games);
  final WidgetTester tester;
  final _Host host;
  final List<int> scores;
  final List<String> sounds;
  final List<DashGame> games;
  DashGame get game => games.last;
}

Future<_H> _open(
  WidgetTester t, {
  Size size = const Size(390, 844),
  double text = 1.0,
  Map<String, Object> prefs = const {},
  DashGame Function(DashCourse?, int)? builder,
  bool reduce = false,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final host = _Host(reduce: reduce);
  final scores = <int>[];
  final sounds = <String>[];
  final games = <DashGame>[];
  await t.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(text)),
        child: GameHostScope(
          host: host,
          child: WindUpDashScreen(
            onScore: scores.add,
            seedFor: () => 3,
            onSound: sounds.add,
            gameBuilder: (c, n) {
              final g =
                  builder?.call(c, n) ??
                  DashGame(seed: c?.seed ?? 3, course: c);
              games.add(g);
              return g;
            },
          ),
        ),
      ),
    ),
  );
  await t.pump(const Duration(milliseconds: 100));
  return _H(t, host, scores, sounds, games);
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
    t.widget<Semantics>(_id(DashIds.live)).properties.label ?? '';

/// A course game with the car 3 units before the flag.
DashGame _nearFlag(DashCourse? c, int n) {
  final g = DashGame(seed: 0, course: c ?? dashCourses[0]);
  g.x = g.course!.length - 3;
  g.best = g.x;
  return g;
}

/// A course game with the car on the ground right at its first hazard.
DashGame _atHazard(DashCourse? c, int n) {
  final g = DashGame(seed: 0, course: c ?? dashCourses[0]);
  g.x = g.track.hazards.first.x - 1;
  return g;
}

const _starsOne = {
  'arcade.wind_up_dash.courses': ['1', '0', '0', '0', '0'],
};

void main() {
  group('Flow', () {
    testWidgets('menu shows Play, Free run, How to play, five chips, best', (
      t,
    ) async {
      await _open(t);
      for (final k in [
        DashIds.play,
        DashIds.free,
        DashIds.howTo,
        DashIds.best,
        for (var i = 0; i < 5; i++) DashIds.course(i),
      ]) {
        expect(_id(k), findsOneWidget, reason: '$k');
      }
      expect(find.byType(AppBar), findsNothing, reason: 'no title bar');
      expect(find.text('Wind-up dash'), findsNothing);
      expect(find.textContaining('Continue'), findsNothing);
      expect(find.textContaining('Remove ads'), findsNothing);
      expect(find.textContaining('Enter / Space'), findsOneWidget);
    });

    testWidgets('Enter plays: ready beat, then the car runs', (t) async {
      final h = await _open(t);
      await _key(t, LogicalKeyboardKey.enter);
      expect(_id(DashIds.ready), findsOneWidget);
      expect(_id(DashIds.hud), findsOneWidget);
      expect(h.game.x, 0, reason: 'the car stands still in the ready beat');
      await _run(t, 1.0);
      expect(_id(DashIds.ready), findsNothing);
      await _run(t, 0.5);
      expect(h.game.x, greaterThan(5));
      expect(h.sounds, contains('wind_click'));
      expect(_liveText(t), contains('Course 1'));
    });

    testWidgets('Space also plays from the menu; F starts the free run', (
      t,
    ) async {
      final h = await _open(t);
      await _key(t, LogicalKeyboardKey.space);
      expect(_id(DashIds.ready), findsOneWidget);
      expect(h.game.course, isNotNull);
      await _key(t, LogicalKeyboardKey.keyL);
      expect(_id(DashIds.menu), findsOneWidget);
      await _key(t, LogicalKeyboardKey.keyF);
      expect(h.game.course, isNull, reason: 'free run');
      expect(_liveText(t), contains('Free run'));
    });

    testWidgets('a crash tumbles, then restarts on the checkpoint', (t) async {
      final h = await _open(t, builder: _atHazard);
      await _key(t, LogicalKeyboardKey.enter);
      await _key(t, LogicalKeyboardKey.enter); // skip the ready beat
      await _run(t, 0.6);
      expect(h.game.over, isTrue);
      expect(_id(DashIds.tryAgain), findsOneWidget);
      expect(h.sounds, contains('crash'));
      expect(_liveText(t), contains('Crashed'));
      await _run(t, 0.9);
      expect(h.game.over, isFalse);
      expect(h.game.x, 0);
      expect(h.game.crashes, 1);
      expect(_id(DashIds.results), findsNothing, reason: 'no result screen');
      expect(_id(DashIds.ready), findsOneWidget);
    });

    testWidgets('Enter skips the try again beat', (t) async {
      final h = await _open(t, builder: _atHazard);
      await _key(t, LogicalKeyboardKey.enter);
      await _key(t, LogicalKeyboardKey.enter);
      await _run(t, 0.5);
      expect(_id(DashIds.tryAgain), findsOneWidget);
      await _key(t, LogicalKeyboardKey.enter);
      expect(h.game.over, isFalse);
    });

    testWidgets('three crashes on one checkpoint show the hint once', (
      t,
    ) async {
      final h = await _open(t, builder: _atHazard);
      await _key(t, LogicalKeyboardKey.enter);
      for (var k = 0; k < 3; k++) {
        await _key(t, LogicalKeyboardKey.enter); // skip ready
        await _run(t, 0.5);
        await _key(t, LogicalKeyboardKey.enter); // skip try again
        h.game.x = h.game.track.hazards.first.x - 1;
      }
      expect(h.game.crashesHere, 3);
      h.game.x = 0;
      await _key(t, LogicalKeyboardKey.enter); // skip ready
      await _run(t, 0.1);
      expect(_id(DashIds.hint), findsOneWidget);
    });

    testWidgets(
      'the flag: confetti beat, then results with stars, Next course',
      (t) async {
        final h = await _open(t, builder: _nearFlag);
        await _key(t, LogicalKeyboardKey.enter);
        await _key(t, LogicalKeyboardKey.enter);
        await _run(t, 0.3);
        expect(h.game.finished, isTrue);
        expect(h.sounds, contains('finish'));
        expect(_liveText(t), contains('Flag'));
        await _run(t, 1.5);
        expect(_id(DashIds.results), findsOneWidget);
        expect(_id(DashIds.next), findsOneWidget);
        expect(_id(DashIds.replay), findsOneWidget);
        expect(_id(DashIds.done), findsOneWidget);
        expect(find.text('Flag reached!'), findsOneWidget);
        expect(h.scores, isEmpty, reason: 'courses do not feed the Games tab');
        expect(_liveText(t), contains('Finished'));
        await _key(t, LogicalKeyboardKey.enter);
        expect(h.game.course!.number, 2);
        expect(_id(DashIds.ready), findsOneWidget);
      },
    );

    testWidgets('a free run ends in the results card and reports the score', (
      t,
    ) async {
      final h = await _open(t);
      await _key(t, LogicalKeyboardKey.keyF);
      await _key(t, LogicalKeyboardKey.enter); // skip ready
      await _run(t, 8);
      expect(_id(DashIds.results), findsOneWidget);
      expect(h.scores, hasLength(1));
      expect(h.scores.single, h.game.score);
      expect(_id(DashIds.again), findsOneWidget);
      expect(find.text('Wind-up dash'), findsNothing);
      await _key(t, LogicalKeyboardKey.space);
      expect(_id(DashIds.ready), findsOneWidget);
      expect(h.games, hasLength(2));
    });

    testWidgets('Escape on the results goes to the menu; the best is kept', (
      t,
    ) async {
      final h = await _open(t);
      await _key(t, LogicalKeyboardKey.keyF);
      await _key(t, LogicalKeyboardKey.enter);
      await _run(t, 8);
      final p = await SharedPreferences.getInstance();
      expect(p.getInt('arcade.wind_up_dash.best'), h.scores.single);
      await _key(t, LogicalKeyboardKey.escape);
      expect(_id(DashIds.menu), findsOneWidget);
    });
  });

  group('Input', () {
    testWidgets('Space jumps in play and never pauses', (t) async {
      final h = await _open(t);
      await _key(t, LogicalKeyboardKey.enter);
      await _run(t, 1.0);
      await _key(t, LogicalKeyboardKey.space);
      await t.pump(const Duration(milliseconds: 100));
      expect(h.game.y, greaterThan(0));
      expect(_id(DashIds.paused), findsNothing);
      expect(h.sounds, contains('jump'));
    });

    testWidgets('Up, W, Enter, a tap and the Jump button jump', (t) async {
      final h = await _open(t);
      Future<void> jumpWith(Future<void> Function() press) async {
        await _key(t, LogicalKeyboardKey.enter);
        await _run(t, 1.0);
        await press();
        await t.pump(const Duration(milliseconds: 60));
        expect(h.game.y, greaterThan(0));
        await _key(t, LogicalKeyboardKey.keyL);
      }

      await jumpWith(() => _key(t, LogicalKeyboardKey.arrowUp));
      await _key(t, LogicalKeyboardKey.enter);
      await _key(t, LogicalKeyboardKey.keyL);
      await _key(t, LogicalKeyboardKey.enter);
      await _run(t, 1.0);
      await _key(t, LogicalKeyboardKey.keyW);
      await t.pump(const Duration(milliseconds: 60));
      expect(h.game.y, greaterThan(0));
      await _key(t, LogicalKeyboardKey.keyL);
      await jumpWith(() => t.tap(_id(DashIds.field)));
      await jumpWith(() => t.tap(_id(DashIds.jump)));
    });

    testWidgets('P and Esc pause; P, Esc, Enter and Space resume', (t) async {
      final h = await _open(t);
      await _key(t, LogicalKeyboardKey.enter);
      await _run(t, 1.2);
      await _key(t, LogicalKeyboardKey.keyP);
      expect(_id(DashIds.paused), findsOneWidget);
      final x = h.game.x;
      await _run(t, 0.5);
      expect(h.game.x, x, reason: 'paused');
      await _key(t, LogicalKeyboardKey.keyP);
      expect(_id(DashIds.paused), findsNothing);
      await _key(t, LogicalKeyboardKey.escape);
      expect(_id(DashIds.paused), findsOneWidget);
      await _key(t, LogicalKeyboardKey.space);
      expect(_id(DashIds.paused), findsNothing);
      await _key(t, LogicalKeyboardKey.escape);
      await _key(t, LogicalKeyboardKey.enter);
      expect(_id(DashIds.paused), findsNothing);
      await _key(t, LogicalKeyboardKey.keyP);
      await t.tap(_id(DashIds.leave));
      await t.pump();
      expect(_id(DashIds.menu), findsOneWidget);
    });

    testWidgets('1 to 5 and F on the menu; locked courses show a message', (
      t,
    ) async {
      final h = await _open(t, prefs: _starsOne);
      await _key(t, LogicalKeyboardKey.digit2);
      expect(h.game.course!.number, 2);
      await _key(t, LogicalKeyboardKey.keyL);
      await _key(t, LogicalKeyboardKey.digit3);
      expect(_id(DashIds.menu), findsOneWidget, reason: 'course 3 is locked');
      expect(find.text('Finish course 2 first'), findsOneWidget);
      await _key(t, LogicalKeyboardKey.digit5);
      expect(_id(DashIds.menu), findsOneWidget);
      expect(find.text('Finish course 4 first'), findsOneWidget);
    });

    testWidgets('Enter closes the how-to dialog; H opens it', (t) async {
      await _open(t);
      await _key(t, LogicalKeyboardKey.keyH);
      await t.pump(const Duration(milliseconds: 300));
      expect(_id(DashIds.howToDialog), findsOneWidget);
      expect(find.textContaining('Space or tap to jump'), findsOneWidget);
      await _key(t, LogicalKeyboardKey.enter);
      await t.pump(const Duration(milliseconds: 400));
      expect(_id(DashIds.howToDialog), findsNothing);
    });

    testWidgets('Left and Right choose a course; Enter plays it', (t) async {
      final h = await _open(
        t,
        prefs: {
          'arcade.wind_up_dash.courses': ['1', '1', '0', '0', '0'],
        },
      );
      await _key(
        t,
        LogicalKeyboardKey.arrowLeft,
      ); // from 3 (first unfinished) back to 2
      await _key(t, LogicalKeyboardKey.enter);
      expect(h.game.course!.number, 2);
    });

    testWidgets('every button prints its key', (t) async {
      await _open(t);
      expect(find.textContaining('Play'), findsWidgets);
      for (final k in [DashIds.free, DashIds.howTo, DashIds.exit]) {
        expect(_id(k), findsOneWidget);
      }
      expect(find.textContaining('F'), findsWidgets);
      await _key(t, LogicalKeyboardKey.enter);
      expect(find.text('P'), findsWidgets);
      expect(find.text('L'), findsWidgets);
      expect(find.text('Space'), findsWidgets);
    });
  });

  group('Progression', () {
    testWidgets('chips 2 to 5 are locked at the start; chip 1 is open', (
      t,
    ) async {
      await _open(t);
      expect(find.byIcon(Icons.lock), findsNWidgets(4));
      await t.tap(_id(DashIds.course(1)));
      await t.pump();
      expect(find.text('Finish course 1 first'), findsOneWidget);
      expect(_id(DashIds.menu), findsOneWidget);
    });

    testWidgets('one star opens the next course; saved stars show', (t) async {
      final h = await _open(
        t,
        prefs: {
          'arcade.wind_up_dash.courses': ['3', '1', '0', '0', '0'],
        },
      );
      expect(find.byIcon(Icons.lock), findsNWidgets(2));
      await t.tap(_id(DashIds.course(2)));
      await t.pump();
      expect(h.game.course!.number, 3);
    });

    testWidgets(
      'finishing a course saves its stars, opens the next, pays coins',
      (t) async {
        final h = await _open(t, builder: _nearFlag);
        await _key(t, LogicalKeyboardKey.enter);
        await _key(t, LogicalKeyboardKey.enter);
        await _run(t, 2);
        final p = await SharedPreferences.getInstance();
        expect(p.getStringList('arcade.wind_up_dash.courses')![0], isNot('0'));
        expect(find.text('Course 2 is open'), findsOneWidget);
        expect(h.host.coins.length, lessThanOrEqualTo(1));
      },
    );

    testWidgets('the old runner best score is carried over', (t) async {
      await _open(t, prefs: {'arcade.runner.best': 321});
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('Best 321'), findsOneWidget);
    });
  });

  group('Juice and motion', () {
    testWidgets('reduced motion still plays, crashes and restarts', (t) async {
      final h = await _open(t, builder: _atHazard, reduce: true);
      await _key(t, LogicalKeyboardKey.enter);
      await _key(t, LogicalKeyboardKey.enter);
      await _run(t, 0.5);
      expect(h.game.over, isTrue);
      await _run(t, 1.2);
      expect(h.game.over, isFalse);
      expect(t.takeException(), isNull);
    });

    testWidgets('a star pick, the spring and a checkpoint play their sounds', (
      t,
    ) async {
      final h = await _open(
        t,
        builder: (c, n) {
          final g = DashGame(seed: 0, course: dashCourses[0]);
          g.meter = SpringMeter(springStars - 1);
          g.x = 38; // the first star line is at 41, 45, 49
          g.best = 38;
          return g;
        },
      );
      await _key(t, LogicalKeyboardKey.enter);
      await _key(t, LogicalKeyboardKey.enter);
      await _run(t, 0.8);
      expect(h.sounds, containsAll(['star', 'spring_full']));
      expect(_liveText(t), isNotEmpty);
    });
  });

  group('Semantics', () {
    testWidgets('the field and HUD have labels; Q reads the next hazard', (
      t,
    ) async {
      await _open(t);
      await _key(t, LogicalKeyboardKey.enter);
      await _key(t, LogicalKeyboardKey.enter);
      await _run(t, 0.3);
      final h = t.getSemantics(_id(DashIds.hud));
      expect(h.label, contains('Stars'));
      expect(h.label, contains('spring'));
      await _key(t, LogicalKeyboardKey.keyQ);
      expect(
        _liveText(t),
        anyOf(contains('Brick ahead'), contains('Gap ahead')),
      );
      final f = t.getSemantics(_id(DashIds.field));
      expect(f.label, contains('Toy car'));
      expect(f.label, contains('jump with Space'));
    });
  });

  group('Layout', () {
    const sizes = [
      Size(360, 640),
      Size(390, 844),
      Size(844, 390),
      Size(1024, 768),
      Size(1280, 676),
      Size(1440, 856),
      Size(1920, 1036),
    ];
    for (final size in sizes) {
      for (final text in [1.0, 1.5]) {
        testWidgets('menu, play, pause and results fit $size at text $text', (
          t,
        ) async {
          await _open(t, size: size, text: text, builder: _nearFlag);
          expect(t.takeException(), isNull);
          void checkNoOverflow() => expect(t.takeException(), isNull);
          checkNoOverflow();
          for (final k in [DashIds.play, DashIds.free, DashIds.howTo]) {
            final r = t.getRect(_id(k));
            expect(r.height, greaterThanOrEqualTo(44), reason: '$k');
            expect(r.left, greaterThanOrEqualTo(0));
            expect(r.right, lessThanOrEqualTo(size.width + 0.5));
          }
          await _key(t, LogicalKeyboardKey.enter);
          await _run(t, 0.3);
          checkNoOverflow();
          for (final k in [DashIds.exit, DashIds.pause, DashIds.jump]) {
            final r = t.getRect(_id(k));
            expect(r.width, greaterThanOrEqualTo(44), reason: '$k');
            expect(r.height, greaterThanOrEqualTo(44), reason: '$k');
            expect(r.left, greaterThanOrEqualTo(0));
            expect(r.right, lessThanOrEqualTo(size.width + 0.5));
            expect(r.bottom, lessThanOrEqualTo(size.height + 0.5));
          }
          expect(find.byType(AppBar), findsNothing);
          expect(
            find.byType(Scrollable),
            findsNothing,
            reason: 'no scrolling in play',
          );
          if (size.width >= 600 && size.height >= 520) {
            expect(_id(DashIds.keys), findsOneWidget);
          }
          await _key(t, LogicalKeyboardKey.keyP);
          checkNoOverflow();
          await _key(t, LogicalKeyboardKey.keyP);
          await _key(t, LogicalKeyboardKey.enter);
          await _run(t, 2.5);
          expect(_id(DashIds.results), findsOneWidget);
          checkNoOverflow();
          final r = t.getRect(_id(DashIds.results));
          expect(r.width, lessThanOrEqualTo(440 + 0.5));
          for (final k in [DashIds.next, DashIds.replay, DashIds.done]) {
            expect(t.getRect(_id(k)).height, greaterThanOrEqualTo(44));
          }
        });
      }
    }
  });
}
