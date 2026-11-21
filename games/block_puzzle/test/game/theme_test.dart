import 'dart:math';
import 'dart:ui';

import 'package:game_block_puzzle/src/core/save/save_data.dart';
import 'package:game_block_puzzle/src/game/flame/block_puzzle_game.dart';
import 'package:game_block_puzzle/src/game/rules/board.dart';
import 'package:game_block_puzzle/src/game/rules/game_state.dart';
import 'package:game_block_puzzle/src/game/rules/piece.dart';
import 'package:game_block_puzzle/src/game/rules/piece_generator.dart';
import 'package:game_block_puzzle/src/game/rules/theme_rotation.dart';
import 'package:game_block_puzzle/src/game/themes/block_theme.dart';
import 'package:game_block_puzzle/src/ui/game_screen.dart';
import 'package:game_block_puzzle/src/ui/test_ids.dart';
import 'package:game_block_puzzle/src/host/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_host.dart';
import '../helpers/puzzle_bot.dart';

void main() {
  group('theme rotation', () {
    test('changes at 10, 20, 30 lines and wraps after the last', () {
      String at(int lines) => ThemeRotation.idFor(0, lines);
      expect(at(0), 'gems');
      expect(at(9), 'gems');
      expect(at(10), 'cakes');
      expect(at(19), 'cakes');
      expect(at(20), 'wood');
      expect(at(30), 'candy');
      expect(at(40), 'ocean');
      expect(at(50), 'space');
      expect(at(60), 'gems');
      expect(at(70), 'cakes');
    });

    test('a game continues from the saved index', () {
      expect(ThemeRotation.idFor(5, 0), 'space');
      expect(ThemeRotation.idFor(5, 10), 'gems');
      expect(ThemeRotation.idFor(2, 25), 'ocean');
    });

    test('themes are in table order and match the painters', () {
      expect([for (final t in BlockTheme.all) t.id], ThemeRotation.ids);
      expect(ThemeRotation.themeEveryLines, 10);
    });

    test('rotation index is saved in the profile data', () {
      final d = const SaveData().copyWith(themeIndex: 3);
      expect(SaveData.fromJson(d.toJson()).themeIndex, 3);
      expect(SaveData.fromJson(const {}).themeIndex, 0);
    });

    test('a new game continues the rotation', () {
      final game = BlockPuzzleGame(
        themeStart: 1,
        generator: PieceGenerator(Random(1)),
      );
      expect(game.theme.id, 'cakes');
      game.state.linesClearedTotal = 20;
      expect(game.theme.id, 'candy');
      game.view = PuzzleView();
      game.restart();
      expect(game.themeStart, 3);
      expect(game.theme.id, 'candy');
    });
  });

  group('colours', () {
    test('dealt pieces get seeded colours from all 8 indexes', () {
      final a = PieceGenerator(Random(5));
      final b = PieceGenerator(Random(5));
      final seen = <int>{};
      for (var i = 0; i < 60; i++) {
        final ta = a.dealTray(Board.empty());
        final tb = b.dealTray(Board.empty());
        expect(
          [for (final p in ta) p.colorIndex],
          [for (final p in tb) p.colorIndex],
        );
        seen.addAll(ta.map((p) => p.colorIndex));
      }
      expect(seen, {0, 1, 2, 3, 4, 5, 6, 7});
    });

    test('every theme has 8 distinct colours', () {
      for (final t in BlockTheme.all) {
        expect(t.palette.toSet().length, Piece.colorCount, reason: t.id);
      }
    });
  });

  group('hud text', () {
    double lum(Color c) {
      double ch(double v) =>
          v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
    }

    double contrast(Color a, Color b) {
      final la = lum(a), lb = lum(b);
      return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
    }

    // Candy (pale background) must reach WCAG AA. The dark themes keep today's white
    // (kept as-is by the owner's request) and only have a regression floor: white on
    // their bright top colours is below 4.5 today (see the issue #68 comment).
    test('candy hudText and hudSubtle reach 4.5 on the top colour', () {
      final t = BlockTheme.candy;
      expect(contrast(t.hudText, t.backgroundTop), greaterThanOrEqualTo(4.5));
      expect(contrast(t.hudSubtle, t.backgroundTop), greaterThanOrEqualTo(4.5));
    });

    for (final t in BlockTheme.all) {
      test('${t.id} hudText never gets harder to read than 2.0', () {
        expect(contrast(t.hudText, t.backgroundTop), greaterThanOrEqualTo(2.0));
      });
    }
  });

  testWidgets('candy: the SCORE label and score use the Candy HUD colours', (
    tester,
  ) async {
    final s = await buildFakeServices();
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = BlockPuzzleGame(
      themeStart: 3,
      generator: PieceGenerator(Random(1)),
    );
    await tester.pumpWidget(
      BlockPuzzleServicesScope(
        services: s,
        child: MaterialApp(home: GameScreen(game: game)),
      ),
    );
    await PuzzleBot(tester).waitForGame();
    expect(game.theme.id, 'candy');
    Color colorOf(Key k) => tester.widget<Text>(find.byKey(k)).style!.color!;
    expect(colorOf(TestIds.gameScoreLabel), BlockTheme.candy.hudSubtle);
    expect(colorOf(TestIds.gameScore), BlockTheme.candy.hudText);
    expect(colorOf(TestIds.gameBest), BlockTheme.candy.hudText);
  });

  group('skins', () {
    for (final t in BlockTheme.all) {
      test('${t.id} paints all 8 colour indexes and its background', () {
        final cache = ThemeTileCache();
        final rec = PictureRecorder();
        final canvas = Canvas(rec);
        for (var i = 0; i < Piece.colorCount; i++) {
          t.paintCell(canvas, Rect.fromLTWH(i * 40.0, 0, 40, 40), i);
          cache.draw(canvas, t, i, Rect.fromLTWH(i * 40.0, 50, 40, 40));
        }
        t.paintBackground(canvas, const Size(300, 600));
        rec.endRecording().dispose();
        cache.dispose();
      });
    }
  });

  testWidgets('game.theme changes after the 10th cleared line', (tester) async {
    final s = await buildFakeServices();
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Row 0 is full but one cell; the dot completes it.
    final rows = ['#######.', ...List.filled(7, '........')];
    final state = GameState(
      generator: PieceGenerator(Random(1)),
      board: Board.fromRows(rows),
      tray: [
        PieceCatalog.dot,
        PieceCatalog.byId('square2_0'),
        PieceCatalog.byId('bar2_0'),
      ],
    )..linesClearedTotal = 9;
    final game = BlockPuzzleGame(initialState: state);
    await tester.pumpWidget(
      BlockPuzzleServicesScope(
        services: s,
        child: MaterialApp(home: GameScreen(game: game)),
      ),
    );
    final bot = PuzzleBot(tester);
    await bot.waitForGame();

    String themeId() => tester
        .widget<Semantics>(find.byKey(TestIds.gameTheme))
        .properties
        .value!;
    expect(themeId(), 'gems');
    expect(await bot.drag(0, 0, 7), isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.linesClearedTotal, 10);
    expect(themeId(), 'cakes');
    expect(s.profile.data.themeIndex, 1);
    // The cross-fade runs and finishes without blocking anything.
    await tester.pump(const Duration(milliseconds: 1600));
  });
}
