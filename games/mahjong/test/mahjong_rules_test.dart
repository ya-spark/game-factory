import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_mahjong/mahjong.dart';

/// Plays a game to the end by always taking the first free pair; true when it clears the table.
bool playOut(MahjongGame g) {
  while (!g.won) {
    final m = g.moves();
    if (m.isEmpty) return false;
    g.take(m.first.$1, m.first.$2);
  }
  return true;
}

void main() {
  test(
    'at least 8 layouts, even, with no overlapping tiles and supported layers',
    () {
      expect(mahjongLayouts.length, greaterThanOrEqualTo(8));
      for (final l in mahjongLayouts) {
        expect(l.positions.length.isEven, isTrue, reason: l.name);
        final p = l.positions;
        for (var i = 0; i < p.length; i++) {
          for (var j = i + 1; j < p.length; j++) {
            final a = p[i], b = p[j];
            final clash =
                a.z == b.z && (a.x - b.x).abs() < 2 && (a.y - b.y).abs() < 2;
            expect(clash, isFalse, reason: '${l.name} $i $j');
          }
          if (p[i].z > 0) {
            final supported = p.any(
              (q) =>
                  q.z == p[i].z - 1 &&
                  (q.x - p[i].x).abs() < 2 &&
                  (q.y - p[i].y).abs() < 2,
            );
            expect(supported, isTrue, reason: '${l.name} tile $i');
          }
        }
      }
    },
  );

  test(
    'every layout deals solvable games for many seeds (proved by replay)',
    () {
      for (final l in mahjongLayouts) {
        for (var seed = 0; seed < 25; seed++) {
          final faces = dealLayout(l, Random(seed));
          // every face appears an even number of times
          final counts = <int, int>{};
          for (final f in faces) {
            counts[f] = (counts[f] ?? 0) + 1;
          }
          expect(counts.values.every((c) => c.isEven), isTrue, reason: l.name);
          // The construction order is a solution; a greedy replay with a retry on dead ends
          // is not guaranteed, so prove it with a search.
          final g = MahjongGame(l, Random(seed), faces: faces);
          expect(solvable(g), isTrue, reason: '${l.name} seed $seed');
        }
      }
    },
  );

  test('free tiles: nothing on top and one open side', () {
    final g = MahjongGame(mahjongLayouts[0], Random(1));
    // Rows: only the two ends of each row are free.
    final free = [
      for (var i = 0; i < g.faces.length; i++)
        if (g.isFree(i)) i,
    ];
    expect(free.length, 8);
    final pyr = MahjongGame(mahjongLayouts[1], Random(1));
    final top = pyr.positions.indexWhere((p) => p.z == 2);
    expect(pyr.isFree(top), isTrue);
    final below = pyr.positions.indexWhere(
      (p) => p.z == 1 && (p.x - pyr.positions[top].x).abs() < 2,
    );
    expect(pyr.isFree(below), isFalse);
  });

  test('take needs a free matching pair; undo puts it back', () {
    final g = MahjongGame(mahjongLayouts[0], Random(2));
    final m = g.moves();
    expect(m, isNotEmpty);
    final (a, b) = m.first;
    expect(g.take(a, a), isFalse);
    final other = List.generate(
      g.faces.length,
      (i) => i,
    ).firstWhere((i) => g.faces[i] != g.faces[a] && g.isFree(i));
    expect(g.take(a, other), isFalse);
    expect(g.take(a, b), isTrue);
    expect(g.removed(a) && g.removed(b), isTrue);
    expect(g.remaining, g.faces.length - 2);
    expect(g.canUndo, isTrue);
    expect(g.undo(), isTrue);
    expect(g.remaining, g.faces.length);
    expect(g.undo(), isFalse);
  });

  test('a cleared table scores; hints and shuffles cost points', () {
    final l = mahjongLayouts[0];
    final g = MahjongGame(l, Random(3));
    expect(g.score, l.pairs * 50 + 100);
    g.hint();
    expect(g.hints, 1);
    expect(g.score, l.pairs * 50 + 100 - 40);
    g.shuffle();
    expect(g.score, l.pairs * 50 + 100 - 40 - 80);
  });

  test('hint returns a playable pair', () {
    final g = MahjongGame(mahjongLayouts[2], Random(4));
    final h = g.hint()!;
    expect(g.canMatch(h.$1, h.$2), isTrue);
  });

  test('shuffle keeps the tiles and leaves a move when stuck', () {
    final g = MahjongGame(mahjongLayouts[2], Random(5));
    // Make it stuck by hand: give every tile a unique-ish face pattern.
    for (var i = 0; i < g.faces.length; i++) {
      g.faces[i] = i % faceCount;
    }
    final before = g.remaining;
    expect(g.shuffle(), isTrue);
    expect(g.remaining, before);
    expect(g.moves(), isNotEmpty);
    expect(solvable(g), isTrue);
  });

  test('the same seed gives the same deal', () {
    final a = dealLayout(mahjongLayouts[3], Random(9));
    final b = dealLayout(mahjongLayouts[3], Random(9));
    expect(a, b);
  });

  test('faces: 24 different suit and rank pairs', () {
    expect(
      {for (var f = 0; f < faceCount; f++) (suitOf(f), rankOf(f))}.length,
      24,
    );
  });
  group('tiers (M3)', () {
    test(
      'Easy and Medium use the first nine layouts, Hard and Expert new ones',
      () {
        expect(MahjongTier.easy.layouts, same(mahjongLayouts));
        expect(MahjongTier.medium.layouts, same(mahjongLayouts));
        for (final l in mahjongHardLayouts) {
          expect(l.positions.length, inInclusiveRange(48, 64), reason: l.name);
        }
        for (final l in mahjongExpertLayouts) {
          expect(l.positions.length, inInclusiveRange(60, 72), reason: l.name);
        }
        final names = {for (final l in mahjongLayouts) l.name};
        for (final l in [...mahjongHardLayouts, ...mahjongExpertLayouts]) {
          expect(names.contains(l.name), isFalse);
          expect(l.positions.length.isEven, isTrue);
          final spots = {for (final p in l.positions) (p.x, p.y, p.z)};
          expect(spots.length, l.positions.length, reason: l.name);
        }
      },
    );

    test('hint and shuffle limits by tier', () {
      expect(
        [for (final t in MahjongTier.values) (t.hintLimit, t.shuffleLimit)],
        [(null, null), (3, 2), (3, 1), (1, 1)],
      );
      final easy = MahjongGame(mahjongLayouts[0], Random(3));
      for (var i = 0; i < 6; i++) {
        expect(easy.hint(), isNotNull);
      }
      expect(easy.hintsLeft, isNull);
      final hard = MahjongGame(
        mahjongHardLayouts[0],
        Random(3),
        tier: MahjongTier.hard,
      );
      for (var i = 0; i < 3; i++) {
        expect(hard.hint(), isNotNull);
      }
      expect(hard.canHint, isFalse);
      expect(hard.hint(), isNull);
      expect(hard.hints, 3);
      expect(hard.shuffle(), isTrue);
      expect(hard.canShuffle, isFalse);
      expect(hard.shuffle(), isFalse);
      expect(hard.shuffles, 1);
      final expert = MahjongGame(
        mahjongExpertLayouts[0],
        Random(3),
        tier: MahjongTier.expert,
      );
      expect(expert.hint(), isNotNull);
      expect(expert.hint(), isNull);
    });

    test('every new layout is solvable for 25 seeds (proved by search)', () {
      for (final l in [...mahjongHardLayouts, ...mahjongExpertLayouts]) {
        for (var seed = 0; seed < 25; seed++) {
          final faces = dealLayout(l, Random(seed));
          final g = MahjongGame(l, Random(seed), faces: faces);
          expect(solvable(g), isTrue, reason: '${l.name} seed $seed');
        }
      }
    });
  });
}

/// Depth-first search for a full clear from the game's position (small layouts only).
bool solvable(MahjongGame g) {
  final seen = <String>{};
  bool go() {
    if (g.won) return true;
    final key = [for (var i = 0; i < g.faces.length; i++) g.removed(i) ? 1 : 0]
        .join();
    if (!seen.add(key)) return false;
    // Prefer pairs in the order given; symmetric moves of equal faces are pruned by `seen`.
    for (final (a, b) in g.moves()) {
      g.take(a, b);
      if (go()) {
        g.undo();
        return true;
      }
      g.undo();
    }
    return false;
  }

  return go();
}
