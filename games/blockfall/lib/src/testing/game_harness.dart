import 'dart:math';

import '../core/save/save_data.dart';
import '../host/services.dart';
import '../game/rules/bag.dart';
import '../game/rules/blockfall_game.dart';
import '../game/rules/piece_type.dart';
import '../game/rules/powerups.dart';
import '../game/rules/well.dart';
import '../ui/game_screen.dart';
import '../ui/test_ids.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_host.dart';

/// Game with a repeating piece sequence and no prisms.
BlockfallGame mk({
  List<PieceType> seq = const [PieceType.prong],
  List<String> rows = const [],
  Map<PowerUpType, int>? stock,
}) => BlockfallGame(
  random: Random(1),
  bag: PieceBag.sequence(seq),
  well: Well.fromRows(rows),
  prismInterval: 0,
  stock: stock,
);

/// Pumps fixed durations (the Flame loop never settles).
Future<void> settle(WidgetTester tester, [int frames = 4]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Lets the game over panel finish its ease-in (1 s) when it is showing.
Future<void> settleGameOver(WidgetTester tester) async {
  if (find.byKey(TestIds.gameOverDialog).evaluate().isEmpty) return;
  await tester.pump(const Duration(milliseconds: 1100));
}

Future<BlockfallServices> openGame(
  WidgetTester tester,
  BlockfallGame game, {
  bool buttons = false,
  FakeBlockfallAds? ads,
  BlockfallServices? services,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = services ?? await buildFakeBlockfallServices(ads: ads);
  if (buttons) {
    await s.profile.setControls(ControlScheme.buttons);
  }
  await tester.pumpWidget(
    BlockfallServicesScope(
      services: s,
      child: MaterialApp(home: GameScreen(game: game)),
    ),
  );
  await settle(tester);
  await settleGameOver(tester);
  return s;
}

String semValue(WidgetTester tester, Key k) =>
    tester.getSemantics(find.byKey(k)).value;

double wellCell(WidgetTester tester) =>
    (tester.getSize(find.byKey(TestIds.gameWell)).width - 12) / 10;

Future<void> tapKey(WidgetTester tester, Key k) async {
  await tester.tap(find.byKey(k));
  await settle(tester, 4);
  await settleGameOver(tester);
}
