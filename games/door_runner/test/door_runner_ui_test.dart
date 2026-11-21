import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_door_runner/src/ui/door_runner_extras.dart';
import 'package:game_door_runner/src/ui/door_runner_field.dart';
import 'package:game_door_runner/src/ui/door_runner_frame.dart';
import 'package:game_door_runner/src/ui/door_runner_hud.dart';
import 'package:game_door_runner/src/ui/door_runner_keyboard.dart';
import 'package:game_door_runner/src/ui/door_runner_question.dart';
import 'package:game_door_runner/src/ui/door_runner_view.dart';
import 'package:game_door_runner/door_runner.dart';

/// A throw-away demo screen: static data, no rules. The real screen is wired by the tech lead.
class _Demo extends StatefulWidget {
  const _Demo({this.older = true, this.reduceMotion = true, this.log});
  final bool older;
  final bool reduceMotion;
  final List<String>? log;
  @override
  State<_Demo> createState() => _DemoState();
}

class _DemoState extends State<_Demo> {
  late DoorRunnerView v = DoorRunnerView(
    question: 'What is 6 times 7?',
    doors: const [DoorView('36'), DoorView('42'), DoorView('48')],
    lane: 1,
    approach: 0.45,
    hearts: widget.older ? 2 : null,
    score: 120,
    streak: widget.older ? 3 : null,
  );

  void _log(String s) => widget.log?.add(s);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DoorRunnerKeyboard(
        onLeft: () =>
            setState(() => v = v.copyWith(lane: (v.lane - 1).clamp(0, 2))),
        onRight: () =>
            setState(() => v = v.copyWith(lane: (v.lane + 1).clamp(0, 2))),
        onZap: () => _log('zap ${v.lane}'),
        onSlow: (h) => _log('slow $h'),
        onPause: () => setState(() => v = v.copyWith(paused: !v.paused)),
        onQuestion: () => _log('question'),
        onDoor: (i) => _log('door $i'),
        child: DoorRunnerFrame(
          hud: DoorRunnerHud(
            view: v,
            onExit: () => _log('exit'),
            onPause: () => setState(() => v = v.copyWith(paused: !v.paused)),
          ),
          question: DoorRunnerQuestionChip(
            question: v.question,
            onOpen: () async {
              final i = await showDoorRunnerQuestionDialog(
                context,
                question: v.question,
                answers: [for (final d in v.doors) d.label],
                onSpeak: () => _log('speak'),
              );
              _log('dialog ${i ?? 'back'}');
            },
          ),
          field: DoorRunnerField(
            view: v,
            reduceMotion: widget.reduceMotion,
            onZap: (i) => _log('tap $i'),
          ),
          slowZone: DoorRunnerSlowZone(onSlow: (h) => _log('slow $h')),
          overlay: v.paused
              ? DoorRunnerPauseOverlay(
                  onResume: () => setState(() => v = v.copyWith(paused: false)),
                  onQuit: () => _log('quit'),
                )
              : null,
        ),
      ),
    );
  }
}

Widget _app(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(useMaterial3: true),
  home: child,
);

Future<void> _size(WidgetTester t, double w, double h) async {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('wide window: play column centred, key hints, no slow zone', (
    t,
  ) async {
    await _size(t, 1280, 800);
    await t.pumpWidget(_app(const _Demo()));
    final stage = t.getRect(find.byKey(FrameIds.stage));
    expect(stage.width, lessThanOrEqualTo(DoorRunnerFrame.playMaxWidth));
    expect(stage.center.dx, closeTo(640, 1));
    expect(find.byKey(DoorRunnerIds.keys), findsOneWidget);
    expect(find.byKey(DoorRunnerIds.slow), findsNothing);
  });

  testWidgets('compact window: slow zone, no key hints, play fills the width', (
    t,
  ) async {
    await _size(t, 390, 780);
    await t.pumpWidget(_app(const _Demo()));
    expect(find.byKey(DoorRunnerIds.slow), findsOneWidget);
    expect(find.byKey(DoorRunnerIds.keys), findsNothing);
    expect(t.getRect(find.byKey(FrameIds.stage)).width, 390);
  });

  testWidgets('younger level shows no hearts and no streak', (t) async {
    await _size(t, 390, 780);
    await t.pumpWidget(_app(const _Demo(older: false)));
    expect(find.byKey(DoorRunnerIds.hearts), findsNothing);
    expect(find.byKey(DoorRunnerIds.streak), findsNothing);
    expect(find.byKey(DoorRunnerIds.score), findsOneWidget);
  });

  testWidgets('no ad is shown or kept free while a run is played', (t) async {
    await _size(t, 1280, 800);
    await t.pumpWidget(
      _app(GameHostScope(host: _AdsHost(), child: const _Demo())),
    );
    expect(find.byKey(FrameIds.rail), findsNothing);
    expect(find.byKey(FrameIds.strip), findsNothing);
    expect(find.byKey(const Key('ad.test')), findsNothing);
  });

  testWidgets(
    'keys: arrows move, up zaps, down slows while held, 1 to 4 pick, Enter asks',
    (t) async {
      await _size(t, 1280, 800);
      final log = <String>[];
      await t.pumpWidget(_app(_Demo(log: log)));
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await t.sendKeyEvent(LogicalKeyboardKey.digit3);
      await t.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      await t.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
      expect(log, ['zap 0', 'door 2', 'slow true', 'slow false']);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.pumpAndSettle();
      final runner = t.getCenter(find.byKey(DoorRunnerIds.runner));
      final lane0 = t.getRect(find.byKey(DoorRunnerIds.lane(0)));
      expect(
        lane0.contains(Offset(runner.dx, lane0.center.dy)),
        isTrue,
        reason: 'stops at the left edge',
      );
    },
  );

  testWidgets('space and the pause button pause and resume', (t) async {
    await _size(t, 1280, 800);
    await t.pumpWidget(_app(const _Demo()));
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.pump();
    expect(find.byKey(DoorRunnerIds.resume), findsOneWidget);
    await t.tap(find.byKey(DoorRunnerIds.resume));
    await t.pump();
    expect(find.byKey(DoorRunnerIds.resume), findsNothing);
    await t.tap(find.byKey(DoorRunnerIds.pause));
    await t.pump();
    expect(find.byKey(DoorRunnerIds.resume), findsOneWidget);
  });

  testWidgets(
    'question chip opens the dialog with the answers; choosing returns the index',
    (t) async {
      await _size(t, 1280, 800);
      final log = <String>[];
      await t.pumpWidget(_app(_Demo(log: log)));
      await t.tap(find.byKey(DoorRunnerIds.question));
      await t.pumpAndSettle();
      expect(find.byKey(DoorRunnerIds.questionDialog), findsOneWidget);
      expect(find.byKey(DoorRunnerIds.answer(2)), findsOneWidget);
      await t.tap(find.byKey(DoorRunnerIds.answer(1)));
      await t.pumpAndSettle();
      expect(log, ['dialog 1']);
      await t.tap(find.byKey(DoorRunnerIds.question));
      await t.pumpAndSettle();
      await t.tap(find.byKey(DoorRunnerIds.questionBack));
      await t.pumpAndSettle();
      expect(log.last, 'dialog back');
    },
  );

  testWidgets('reduce motion: doors sit at the runner line', (t) async {
    await _size(t, 390, 780);
    await t.pumpWidget(_app(const _Demo(reduceMotion: true)));
    final door = t.getRect(find.byKey(DoorRunnerIds.door(0)));
    final runner = t.getRect(find.byKey(DoorRunnerIds.runner));
    expect(door.bottom, lessThanOrEqualTo(runner.top));
    expect(runner.top - door.bottom, lessThan(40));
  });

  testWidgets(
    'moving scene: doors are still coming down, then reach the line',
    (t) async {
      await _size(t, 390, 780);
      await t.pumpWidget(_app(const _Demo(reduceMotion: false)));
      await t.pump(const Duration(milliseconds: 100));
      final door = t.getRect(find.byKey(DoorRunnerIds.door(0)));
      final runner = t.getRect(find.byKey(DoorRunnerIds.runner));
      expect(
        runner.top - door.bottom,
        greaterThan(40),
        reason: 'approach 0.45: not at the line yet',
      );
      await t.pumpWidget(const SizedBox());
    },
  );

  // Look-and-feel previews: only with DOOR_PREVIEW=1 (needs the Roboto font from the Flutter SDK).
  // flutter test --update-goldens test/ui/minigames/door_runner_ui_test.dart  (env DOOR_PREVIEW=1)
  final preview = Platform.environment['DOOR_PREVIEW'] != null;
  ByteData bytes(String path) {
    final b = File(path).readAsBytesSync();
    return ByteData.view(b.buffer, b.offsetInBytes, b.lengthInBytes);
  }

  Future<void> loadFonts() async {
    final root = Platform.environment['FLUTTER_ROOT'] ?? '/home/track/flutter';
    final dir = '$root/bin/cache/artifacts/material_fonts';
    final roboto = FontLoader('Roboto');
    for (final f in ['Regular', 'Medium', 'Bold', 'Black']) {
      roboto.addFont(Future.value(bytes('$dir/Roboto-$f.ttf')));
    }
    await roboto.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(Future.value(bytes('$dir/MaterialIcons-Regular.otf')));
    await icons.load();
  }

  group('previews', skip: !preview, () {
    for (final (name, w, h) in [
      ('wide', 1280.0, 800.0),
      ('compact', 390.0, 780.0),
    ]) {
      testWidgets('preview $name', (t) async {
        await loadFonts();
        await _size(t, w, h);
        await t.pumpWidget(_app(const _Demo(reduceMotion: false)));
        await t.pump(const Duration(milliseconds: 600));
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('previews/door_runner_$name.png'),
        );
        await t.pumpWidget(const SizedBox());
      });
    }
    testWidgets('preview dialog', (t) async {
      await loadFonts();
      await _size(t, 1280, 800);
      await t.pumpWidget(_app(const _Demo()));
      await t.tap(find.byKey(DoorRunnerIds.question));
      await t.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('previews/door_runner_dialog.png'),
      );
    });
    testWidgets('preview paused phone', (t) async {
      await loadFonts();
      await _size(t, 390, 780);
      await t.pumpWidget(_app(const _Demo()));
      await t.tap(find.byKey(DoorRunnerIds.pause));
      await t.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('previews/door_runner_paused.png'),
      );
    });
  });

  group('keys go through the shared key map', () {
    Future<List<String>> pumpKeys(WidgetTester t, {GameKeyMap? keys}) async {
      final log = <String>[];
      Widget app = _app(_Demo(log: log));
      if (keys != null) app = GameKeysScope(keys: keys, child: app);
      await _size(t, 390, 780);
      await t.pumpWidget(app);
      return log;
    }

    testWidgets('the second hand works too: A D W S', (t) async {
      final log = await pumpKeys(t);
      await t.sendKeyEvent(LogicalKeyboardKey.keyW);
      await t.sendKeyDownEvent(LogicalKeyboardKey.keyS);
      await t.sendKeyUpEvent(LogicalKeyboardKey.keyS);
      expect(log, ['zap 1', 'slow true', 'slow false']);
    });

    testWidgets('Esc pauses, Q asks, the numpad picks a door', (t) async {
      final log = await pumpKeys(t);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      expect(find.byType(DoorRunnerPauseOverlay), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.keyQ);
      await t.sendKeyEvent(LogicalKeyboardKey.numpad4);
      expect(log, ['question', 'door 3']);
    });

    testWidgets('a remapped key steers and the old one does not', (t) async {
      final keys = GameKeyMap()
        ..assign(const KeySlot(GameAction.up, 1), LogicalKeyboardKey.keyJ);
      final log = await pumpKeys(t, keys: keys);
      await t.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      expect(log, ['zap 1']);
    });

    testWidgets('the hints show the remapped key', (t) async {
      final keys = GameKeyMap()
        ..assign(const KeySlot(GameAction.up, 1), LogicalKeyboardKey.keyJ);
      await pumpKeys(t, keys: keys);
      await _size(t, 1280, 800);
      await t.pumpWidget(GameKeysScope(keys: keys, child: _app(const _Demo())));
      expect(
        find.descendant(
          of: find.byKey(DoorRunnerIds.keys),
          matching: find.text('J'),
        ),
        findsOneWidget,
      );
    });
  });
}

/// A container that offers every ad format.
class _AdsHost extends NoGameHost {
  @override
  GameAdUnit? adUnit(BuildContext context, GameAdFormat format) => GameAdUnit(
    widget: const SizedBox(key: Key('ad.test')),
    size: format.size,
  );
}
