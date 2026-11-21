import 'dart:math';

import 'package:game_blockfall/src/ui/test_ids.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plays Blockfall through the real UI, using only test IDs.
///
/// Readouts come from the Semantics `value` of the HUD nodes (needs
/// `tester.ensureSemantics()`), exactly what the integration bot will see.
/// The Flame loop never settles, so every action pumps fixed durations.
class BlockfallBot {
  BlockfallBot(
    this.tester, {
    int seed = 1,
    this.step = const Duration(milliseconds: 50),
  }) : _rng = Random(seed);

  final WidgetTester tester;
  final Duration step;
  final Random _rng;

  Future<void> pumpFor(Duration d) async {
    var left = d;
    while (left > Duration.zero) {
      final s = left < step ? left : step;
      await tester.pump(s);
      left -= s;
    }
  }

  /// Semantics value of the node with test ID [k].
  String value(Key k) => tester.getSemantics(find.byKey(k)).value;

  int get score => int.parse(value(TestIds.gameScore));
  int get level => int.parse(value(TestIds.gameLevel));
  int get goal => int.parse(value(TestIds.gameGoal));
  int get combo => int.parse(value(TestIds.gameCombo));
  String get holdPiece => value(TestIds.gameHoldPiece);
  String nextPiece(int i) => value(TestIds.gameNext(i));
  int powerUpCount(Key countKey) => int.parse(value(countKey));
  bool get isGameOver =>
      find.byKey(TestIds.gameOverDialog).evaluate().isNotEmpty;

  Future<void> tap(Key k) async {
    await tester.tap(find.byKey(k), warnIfMissed: false);
    await pumpFor(step);
  }

  // ---- button scheme --------------------------------------------------------
  Future<void> left([int n = 1]) async {
    for (var i = 0; i < n; i++) {
      await tap(TestIds.gameCtlLeft);
    }
  }

  Future<void> right([int n = 1]) async {
    for (var i = 0; i < n; i++) {
      await tap(TestIds.gameCtlRight);
    }
  }

  Future<void> rotate([int n = 1]) async {
    for (var i = 0; i < n; i++) {
      await tap(TestIds.gameCtlRotate);
    }
  }

  Future<void> softDrop() => tap(TestIds.gameCtlSoftDrop);
  Future<void> hardDrop() => tap(TestIds.gameCtlHardDrop);
  Future<void> hold() => tap(TestIds.gameHold);

  // ---- touch scheme (real gestures on game.well) ----------------------------
  double get cellWidth =>
      (tester.getSize(find.byKey(TestIds.gameWell)).width - 12) / 10;

  Future<void> tapWell() async {
    await tester.tap(find.byKey(TestIds.gameWell));
    await pumpFor(step);
  }

  /// Positive [columns] moves right.
  Future<void> dragColumns(int columns) async {
    await tester.drag(
      find.byKey(TestIds.gameWell),
      Offset(columns * cellWidth, 0),
    );
    await pumpFor(step);
  }

  Future<void> flingDown() async {
    await tester.fling(
      find.byKey(TestIds.gameWell),
      const Offset(0, 400),
      2000,
    );
    await pumpFor(step);
  }

  /// Plays [pieces] random drops with the Buttons scheme; stops early at game over.
  /// Returns how many pieces were dropped.
  Future<int> playRandom(int pieces) async {
    var n = 0;
    while (n < pieces && !isGameOver) {
      final turns = _rng.nextInt(4);
      final shift = _rng.nextInt(9) - 4;
      await rotate(turns);
      if (shift < 0) {
        await left(-shift);
      } else {
        await right(shift);
      }
      if (_rng.nextInt(8) == 0) await hold();
      await hardDrop();
      n++;
    }
    return n;
  }
}
