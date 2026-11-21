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

/// Pumps [game] in a game screen under [services] (any container's implementation), at a phone
/// size, and lets the screen settle. Containers wrap this in their own `openFakeGame` that builds their
/// own services.
Future<void> pumpGame(
  WidgetTester tester,
  BlockfallGame game,
  BlockfallServices services,
) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    BlockfallServicesScope(
      services: services,
      child: MaterialApp(home: GameScreen(game: game)),
    ),
  );
  await settle(tester);
  await settleGameOver(tester);
}

/// The package's own tests: the same with the in-memory fake host.
Future<BlockfallServices> openFakeGame(
  WidgetTester tester,
  BlockfallGame game, {
  bool buttons = false,
  FakeBlockfallAds? ads,
}) async {
  final s = await buildFakeBlockfallServices(ads: ads);
  if (buttons) {
    await s.profile.setControls(ControlScheme.buttons);
  }
  await pumpGame(tester, game, s);
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
