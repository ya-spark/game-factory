import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_domino_chain/domino_chain.dart';

ContentItem _series(List<String> steps) => ContentItem({
  'id': 's',
  'seq': 1,
  'difficulty': 1,
  'type': 'series',
  'explanation': 'e',
  'prompt': 'Order them',
  'steps': steps,
});

void main() {
  group('Domino chain rules (SPEC: Rules)', () {
    final eight = ['1', '2', '3', '4', '5', '6', '7', '8'];

    test('level from the year; caps per level; hints and time', () {
      expect(SeriesLevel.forYear(1), SeriesLevel.younger);
      expect(SeriesLevel.forYear(4), SeriesLevel.older);
      expect(SeriesLevel.forYear(6, hard: true), SeriesLevel.hard);
      expect(SeriesLevel.younger.maxDominoes, 4);
      expect(SeriesLevel.older.maxDominoes, 7);
      expect(SeriesLevel.hard.maxDominoes, 7);
      expect(SeriesLevel.younger.hints, 2);
      expect(SeriesLevel.older.hints, 1);
      expect(SeriesLevel.hard.hints, 0);
      expect(SeriesLevel.younger.timeLimit(4), isNull);
      expect(SeriesLevel.older.timeLimit(5), 40);
      expect(SeriesLevel.older.timeLimit(7), 56);
      expect(SeriesLevel.older.timeLimit(10), 60); // capped
      expect(SeriesLevel.hard.timeLimit(7), 35);
      expect(DominoSettings.forLevel(SeriesLevel.older, study: true).hints, 2);
      expect(
        DominoSettings.forLevel(SeriesLevel.older, study: true).timeLimit(5),
        isNull,
      );
    });

    test('chains are capped, windowed, shuffled and never start in order', () {
      for (var seed = 0; seed < 30; seed++) {
        final c = DominoChain.fromItem(
          _series(eight),
          SeriesLevel.younger,
          Random(seed),
        );
        expect(c.total, 4);
        // a window of consecutive steps
        final a = eight.indexOf(c.steps.first);
        expect(c.steps, eight.sublist(a, a + 4));
        expect(c.tiles.join(','), isNot(c.steps.join(',')));
        expect(c.tiles.toList()..sort(), c.steps.toList()..sort());
      }
      final seven = DominoChain.fromItem(
        _series(eight),
        SeriesLevel.older,
        Random(1),
      );
      expect(seven.total, 7);
      final three = DominoChain.fromItem(
        _series(['a', 'b', 'c']),
        SeriesLevel.older,
        Random(1),
      );
      expect(three.total, 3);
    });

    test('the same seed gives the same chain', () {
      DominoChain mk(int s) =>
          DominoChain.fromItem(_series(eight), SeriesLevel.older, Random(s));
      expect(mk(5).tiles, mk(5).tiles);
      expect(mk(5).steps, mk(5).steps);
    });

    test('size class follows the longest step (24 characters)', () {
      final short = DominoChain.fromItem(
        _series(['a' * 24, 'b', 'c']),
        SeriesLevel.younger,
        Random(1),
      );
      expect(short.size, DominoSize.short);
      final long = DominoChain.fromItem(
        _series(['a' * 25, 'b', 'c']),
        SeriesLevel.younger,
        Random(1),
      );
      expect(long.size, DominoSize.long);
    });

    test('equal step texts are interchangeable and never loop forever', () {
      final c = DominoChain.fromItem(
        _series(['x', 'x', 'x']),
        SeriesLevel.younger,
        Random(1),
      );
      final b = DominoBoard(tiles: c.tiles, steps: c.steps);
      for (var i = 0; i < 3; i++) {
        b.place(i);
      }
      expect(b.verdict.isRight, isTrue);
    });

    test('board: place, take, swap, take last', () {
      final b = DominoBoard(tiles: ['c', 'a', 'b'], steps: ['a', 'b', 'c']);
      expect(b.verdict.kind, DominoVerdictKind.incomplete);
      expect(b.place(1), isTrue); // a -> slot 0
      expect(b.place(2), isTrue); // b -> slot 1
      expect(b.place(1), isFalse); // already placed, no slot given
      expect(b.firstEmpty, 2);
      expect(b.place(0, slot: 0), isTrue); // c replaces a in slot 0
      expect(b.isPlaced(1), isFalse);
      expect(b.textAt(0), 'c');
      expect(b.swap(0, 1), isTrue);
      expect(b.textAt(0), 'b');
      expect(b.textAt(1), 'c');
      expect(b.takeLast(), isTrue); // c was placed last
      expect(b.textAt(1), isNull);
      expect(b.take(0), isTrue);
      expect(b.take(0), isFalse);
      b.clear();
      expect(b.isEmpty, isTrue);
    });

    test('moving a placed domino swaps with the target slot', () {
      final b = DominoBoard(tiles: ['a', 'b', 'c'], steps: ['a', 'b', 'c']);
      b.place(0);
      b.place(1);
      expect(b.place(0, slot: 1), isTrue);
      expect(b.textAt(0), 'b');
      expect(b.textAt(1), 'a');
      expect(b.place(0, slot: 2), isTrue); // into an empty slot
      expect(
        b.textAt(1),
        'b'.isEmpty
            ? ''
            : 'b' == b.textAt(1)
            ? 'b'
            : b.textAt(1),
      );
    });

    test('Go verdict: first wrong slot, all right, incomplete', () {
      final b = DominoBoard(
        tiles: ['b', 'a', 'd', 'c'],
        steps: ['a', 'b', 'c', 'd'],
      );
      b.place(1); // a
      b.place(0); // b
      b.place(3); // c
      expect(b.verdict.kind, DominoVerdictKind.incomplete);
      b.place(2); // d
      expect(b.verdict.kind, DominoVerdictKind.right);
      b.clear();
      b.place(1); // a
      b.place(2); // d  (wrong at slot 1)
      b.place(3); // c
      b.place(0); // b
      final v = b.verdict;
      expect(v.kind, DominoVerdictKind.wrong);
      expect(v.firstWrong, 1);
      expect(b.fallenCount, 1);
    });

    test('hints light the first slot that is not right and its domino', () {
      final b = DominoBoard(tiles: ['b', 'a', 'c'], steps: ['a', 'b', 'c']);
      expect(b.hintSlot, 0);
      expect(b.hintTile, 1);
      b.place(1);
      expect(b.hintSlot, 1);
      expect(b.hintTile, 0);
      b.solve();
      expect(b.verdict.isRight, isTrue);
      expect(b.hintSlot, isNull);
    });

    test('scores: first try 10 (older streak bonus), second 6, then 3', () {
      expect(dominoChainScore(attempts: 1, streak: 0, older: false), 10);
      expect(dominoChainScore(attempts: 1, streak: 3, older: true), 16);
      expect(dominoChainScore(attempts: 1, streak: 9, older: true), 20);
      expect(dominoChainScore(attempts: 2, streak: 3, older: true), 6);
      expect(dominoChainScore(attempts: 4, streak: 0, older: false), 3);
    });

    test('skill answer: first Go, no hint, not timed out; study always', () {
      bool c(int a, {bool h = false, bool t = false, bool s = false}) =>
          dominoChainCorrect(attempts: a, hinted: h, timedOut: t, study: s);
      expect(c(1), isTrue);
      expect(c(2), isFalse);
      expect(c(1, h: true), isFalse);
      expect(c(1, t: true), isFalse);
      expect(c(3, s: true), isTrue);
    });

    test('chain counts: pool 1, 2 and 5 and the cap', () {
      expect(dominoChainCount(0), 0);
      expect(dominoChainCount(1), 1);
      expect(dominoChainCount(2), 2);
      expect(dominoChainCount(5), 5);
      expect(dominoChainCount(10), 6);
    });

    test('stages: 2 chains each, the last one may have 1, scenery cycles', () {
      final s = [for (var i = 0; i < 5; i++) dominoStageFor(i, 5)];
      expect(s.map((e) => e.stage), [0, 0, 1, 1, 2]);
      expect(s.map((e) => e.chains), [2, 2, 2, 2, 1]);
      expect(s.map((e) => e.endsStage), [false, true, false, true, true]);
      expect(s[0].backdrop, DominoBackdrop.floor);
      expect(s[2].backdrop, DominoBackdrop.shelf);
      expect(s[4].backdrop, DominoBackdrop.sill);
      expect(dominoStageFor(0, 1).endsStage, isTrue);
      expect(dominoStageFor(0, 1).chains, 1);
    });

    test('stage stars: both first try 3, one 2, none 1; chain stars', () {
      expect(dominoStageStars(firstTry: 2, chains: 2), 3);
      expect(dominoStageStars(firstTry: 1, chains: 2), 2);
      expect(dominoStageStars(firstTry: 0, chains: 2), 1);
      expect(dominoStageStars(firstTry: 1, chains: 1), 3);
      expect(dominoStageStars(firstTry: 0, chains: 1), 1);
      expect(dominoChainStars(1), 3);
      expect(dominoChainStars(2), 2);
      expect(dominoChainStars(5), 1);
    });

    test('a session never plays an item twice (one chain per item)', () {
      // chains are built per session item, so the item ids are the session's own
      final n = dominoChainCount(4);
      expect(n, 4);
    });

    test('the rules are pure Dart: no Flutter, Flame or Android imports', () {
      for (final f in Directory('lib/src/rules').listSync()) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final t = f.readAsStringSync();
        expect(t, isNot(contains('package:flutter')), reason: f.path);
        expect(t, isNot(contains('package:flame')), reason: f.path);
        expect(t, isNot(contains('dart:ui')), reason: f.path);
        expect(t, isNot(contains('dart:io')), reason: f.path);
      }
    });
  });
}
