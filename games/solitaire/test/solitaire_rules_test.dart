import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_solitaire/solitaire.dart';

KlondikeState empty({int draw = 1}) => KlondikeState(
  drawCount: draw,
  stock: [],
  waste: [],
  tableau: List.generate(7, (_) => <int>[]),
  down: List.filled(7, 0),
  foundation: [0, 0, 0, 0],
);

// Card ids: spades 0-12, hearts 13-25, diamonds 26-38, clubs 39-51; rank = id % 13 + 1.
int card(int suit, int rank) => suit * 13 + rank - 1;

void main() {
  test(
    'the deal: 28 cards in 7 columns, the rest in the stock, top cards up',
    () {
      final s = KlondikeState.deal(shuffledDeck(Random(1)), drawCount: 3);
      expect([for (final t in s.tableau) t.length], [1, 2, 3, 4, 5, 6, 7]);
      expect(s.stock.length, 24);
      expect(s.down, [0, 1, 2, 3, 4, 5, 6]);
      final all = [...s.stock, for (final t in s.tableau) ...t];
      expect(all.toSet().length, 52);
    },
  );

  test('draw one and draw three, then the waste is recycled', () {
    final one = KlondikeState.deal(shuffledDeck(Random(2)), drawCount: 1);
    one.apply(const KlondikeMove(MoveKind.draw));
    expect(one.waste.length, 1);
    final three = KlondikeState.deal(shuffledDeck(Random(2)), drawCount: 3);
    final top = three.stock.last;
    three.apply(const KlondikeMove(MoveKind.draw));
    expect(three.waste.length, 3);
    expect(three.waste.first, top);
    while (three.stock.isNotEmpty) {
      three.apply(const KlondikeMove(MoveKind.draw));
    }
    three.score = 50;
    three.apply(const KlondikeMove(MoveKind.draw));
    expect(three.stock.length, 24);
    expect(three.waste, isEmpty);
    expect(three.recycles, 1);
    expect(three.score, 30);
  });

  test(
    'stacking needs the opposite colour and one rank lower; kings go to gaps',
    () {
      final s = empty();
      s.tableau[0].add(card(0, 8)); // 8 of spades
      s.tableau[1].add(card(1, 7)); // 7 of hearts: fits on the 8 of spades
      s.tableau[2].add(card(3, 7)); // 7 of clubs: same colour, does not fit
      s.tableau[3].add(card(1, 13)); // king, no gap yet to move to
      final moves = s.legalMoves();
      expect(
        moves.any(
          (m) =>
              m.kind == MoveKind.tableauToTableau && m.from == 1 && m.to == 0,
        ),
        isTrue,
      );
      expect(
        moves.any(
          (m) =>
              m.kind == MoveKind.tableauToTableau && m.from == 2 && m.to == 0,
        ),
        isFalse,
      );
      // The king (alone in its column) has no use for an empty column.
      expect(
        moves.any((m) => m.kind == MoveKind.tableauToTableau && m.from == 3),
        isFalse,
      );
      // A king on top of a face-down card can go to an empty column and reveals it.
      s.tableau[4].addAll([card(2, 3), card(1, 13)]);
      s.down[4] = 1;
      final k = s.legalMoves().firstWhere(
        (m) => m.kind == MoveKind.tableauToTableau && m.from == 4,
      );
      s.apply(k);
      expect(s.down[4], 0);
      expect(s.score, 5);
    },
  );

  test('foundation builds ace up by suit; waste to foundation scores', () {
    final s = empty();
    s.waste.add(card(2, 1));
    s.apply(const KlondikeMove(MoveKind.wasteToFoundation));
    expect(s.foundation[2], 1);
    expect(s.score, 10);
    s.tableau[0].add(card(2, 2));
    expect(
      s.legalMoves().any((m) => m.kind == MoveKind.tableauToFoundation),
      isTrue,
    );
    s.tableau[1].add(card(2, 3));
    expect(
      s
          .legalMoves()
          .where((m) => m.kind == MoveKind.tableauToFoundation)
          .length,
      1,
    );
  });

  test('moving a run, and a card back from a foundation costs points', () {
    final s = empty();
    s.tableau[0].addAll([card(0, 9), card(1, 8), card(0, 7)]);
    s.tableau[1].add(card(1, 10));
    s.apply(
      const KlondikeMove(MoveKind.tableauToTableau, from: 0, to: 1, count: 3),
    );
    expect(s.tableau[1].length, 4);
    expect(s.tableau[0], isEmpty);
    s.foundation[1] = 3;
    s.score = 100;
    s.tableau[2].add(card(0, 4));
    s.apply(const KlondikeMove(MoveKind.foundationToTableau, from: 1, to: 2));
    expect(s.foundation[1], 2);
    expect(s.score, 85);
  });

  test('tap move prefers the foundation, then a column', () {
    final s = empty();
    s.tableau[0].add(card(0, 1));
    s.tableau[1].add(card(1, 2));
    s.waste.add(card(0, 2)); // 2 of spades: not on foundation yet, fits on no 3
    expect(s.tapMove(MoveKind.wasteToTableau), isNull);
    final m = s.tapMove(MoveKind.tableauToFoundation, index: 0, col: 0)!;
    expect(m.kind, MoveKind.tableauToFoundation);
  });

  test('auto-complete: only with everything face up, and it wins', () {
    final s = empty();
    for (var suit = 0; suit < 4; suit++) {
      for (var r = 13; r >= 1; r--) {
        s.tableau[suit].add(card(suit, r));
      }
    }
    expect(s.canAutoComplete, isTrue);
    var guard = 0;
    while (!s.won && guard++ < 100) {
      final m = s.nextAutoMove()!;
      s.apply(m);
    }
    expect(s.won, isTrue);
    expect(s.canAutoComplete, isFalse);
    final blocked = KlondikeState.deal(shuffledDeck(Random(4)), drawCount: 1);
    expect(blocked.canAutoComplete, isFalse);
  });

  test('undo restores the table', () {
    final g = KlondikeGame(
      KlondikeState.deal(shuffledDeck(Random(5)), drawCount: 1),
    );
    final before = g.state.key;
    expect(g.play(const KlondikeMove(MoveKind.draw)), isTrue);
    expect(g.state.key, isNot(before));
    expect(g.undo(), isTrue);
    expect(g.state.key, before);
    expect(g.undo(), isFalse);
    expect(g.play(const KlondikeMove(MoveKind.wasteToFoundation)), isFalse);
  });

  test('the solver proves a nearly finished deal and refuses a stuck one', () {
    final s = empty();
    for (var suit = 0; suit < 4; suit++) {
      for (var r = 13; r >= 1; r--) {
        s.tableau[suit].add(card(suit, r));
      }
    }
    expect(solveKlondike(s), isTrue);
    final stuck = empty();
    stuck.tableau[0].addAll([card(0, 5), card(1, 1)]);
    stuck.down[0] = 1;
    stuck.foundation.setAll(0, [0, 0, 0, 0]);
    expect(solveKlondike(stuck, maxNodes: 1000), isFalse);
  });

  test('winnable deals: proven by the solver, repeatable by seed', () {
    final a = dealKlondike(Random(11), drawCount: 1, winnable: true);
    final b = dealKlondike(Random(11), drawCount: 1, winnable: true);
    expect(a.proven, isTrue);
    expect(solveKlondike(a.state), isTrue);
    expect(a.state.key, b.state.key);
    final plain = dealKlondike(Random(11), drawCount: 3, winnable: false);
    expect(plain.proven, isFalse);
  });

  group('levels', () {
    test('presets: draw, deal, hints and win bonus', () {
      expect(
        [
          for (final l in SolitaireLevel.values.take(4))
            (l.drawCount, l.winnable, l.hints, l.winBonus),
        ],
        [
          (1, true, 3, 300),
          (1, false, 3, 500),
          (3, true, 1, 800),
          (3, false, 0, 1200),
        ],
      );
    });

    test('old draw and winnable settings map to a level', () {
      expect(
        SolitaireLevel.fromLegacy(draw3: false, winnable: true),
        SolitaireLevel.easy,
      );
      expect(
        SolitaireLevel.fromLegacy(draw3: false, winnable: false),
        SolitaireLevel.medium,
      );
      expect(
        SolitaireLevel.fromLegacy(draw3: true, winnable: true),
        SolitaireLevel.hard,
      );
      expect(
        SolitaireLevel.fromLegacy(draw3: true, winnable: false),
        SolitaireLevel.expert,
      );
    });

    test('the win bonus replaces the flat 500', () {
      final g = KlondikeGame(empty()..score = 40, winBonus: 800);
      expect(g.finalScore, 840);
    });

    test(
      'hints are limited, cost 10, never below 0, and undo keeps the cost',
      () {
        final s = empty()
          ..stock.add(card(0, 5))
          ..score = 15;
        final g = KlondikeGame(s, hintLimit: 2);
        expect(g.takeHint(), isNotNull);
        expect(g.state.score, 5);
        g.play(const KlondikeMove(MoveKind.draw));
        g.takeHint(); // nothing useful now? a hint is only charged when one exists
        g.undo();
        expect(g.hintsUsed, greaterThanOrEqualTo(1));
        expect(g.state.score, lessThanOrEqualTo(5));
        expect(g.state.score, greaterThanOrEqualTo(0));
        final none = KlondikeGame(empty(), hintLimit: 0);
        expect(none.canHint, isFalse);
        expect(none.takeHint(), isNull);
      },
    );
  });

  group('hint finder priority', () {
    test('a foundation move comes first', () {
      final s = empty();
      s.tableau[0].add(card(0, 1)); // ace of spades
      s.tableau[1].add(card(1, 6));
      s.tableau[2].add(card(0, 5));
      final h = findKlondikeHint(s)!;
      expect(h.move.kind, MoveKind.tableauToFoundation);
      expect(h.move.from, 0);
    });

    test('then a move that turns a face-down card', () {
      final s = empty();
      s.tableau[0].addAll([card(2, 9), card(0, 5)]);
      s.down[0] = 1;
      s.tableau[1].add(card(1, 6));
      s.tableau[3].addAll([card(3, 3), card(3, 12)]);
      s.down[3] = 0;
      s.stock.add(card(2, 2));
      final h = findKlondikeHint(s)!;
      expect(h.move.kind, MoveKind.tableauToTableau);
      expect(h.move.from, 0);
      expect(h.move.to, 1);
    });

    test('then a king-led run to an empty column', () {
      final s = empty();
      // A king on top of a face-up card (no face-down card to turn), empty columns elsewhere.
      s.tableau[0].addAll([card(3, 12), card(1, 13)]);
      s.stock.add(card(2, 2));
      final h = findKlondikeHint(s)!;
      expect(h.move.kind, MoveKind.tableauToTableau);
      expect(h.move.from, 0);
      expect(h.move.count, 1);
      expect(s.tableau[h.move.to], isEmpty);
    });

    test('then a king from the waste to an empty column, then other moves', () {
      final s = empty();
      s.waste.add(card(1, 13));
      s.tableau[0].add(card(1, 6));
      s.tableau[1].add(card(0, 5));
      var h = findKlondikeHint(s)!;
      expect(h.move.kind, MoveKind.wasteToTableau);
      s.waste.clear();
      s.stock.add(card(2, 2));
      s.tableau[2].add(card(2, 9));
      h = findKlondikeHint(s)!;
      expect(h.move.kind, MoveKind.tableauToTableau);
    });

    test('draw when only the stock is left, nothing useful when stuck', () {
      final s = empty();
      s.tableau[0].add(card(0, 5));
      s.tableau[1].add(card(0, 7));
      s.stock.add(card(2, 2));
      expect(findKlondikeHint(s)!.move.kind, MoveKind.draw);
      s.stock.clear();
      expect(findKlondikeHint(s), isNull);
    });
  });
}
