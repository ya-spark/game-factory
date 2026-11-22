import 'dart:math';

import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_bridge_builder/bridge_builder.dart';

ContentItem _numeric(int i, Object answer) => ContentItem({
  'id': 'n.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'numeric',
  'explanation': 'x',
  'prompt': 'What is it?',
  'answer': answer,
});

ContentItem _word(int i, String answer) => ContentItem({
  'id': 'w.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'word',
  'explanation': 'x',
  'answer': answer,
  'hint': 'Clue for $answer',
});

void main() {
  group('Bridge builder', () {
    test('evaluates with the usual order and rejects bad shapes', () {
      expect(evaluateTokens(['2', '+', '3', '×', '4']), 14);
      expect(evaluateTokens(['12', '÷', '4', '−', '1']), 2);
      expect(evaluateTokens(['5']), 5);
      expect(evaluateTokens(['5', '+']), isNull);
      expect(evaluateTokens(['+', '5', '3']), isNull);
      expect(evaluateTokens(['4', '÷', '0']), isNull);
      expect(evaluateTokens([]), isNull);
    });

    test('any valid sum that equals the target counts', () {
      expect(sumHitsTarget(['6', '+', '6'], 12), isTrue);
      expect(sumHitsTarget(['3', '×', '4'], 12), isTrue);
      expect(sumHitsTarget(['20', '−', '8'], 12), isTrue);
      expect(sumHitsTarget(['2', '×', '5'], 12), isFalse);
      expect(sumHitsTarget(['12', '+'], 12), isFalse);
    });

    test('the target comes from a whole-number numeric item only', () {
      expect(sumTarget(_numeric(1, 12)), 12);
      expect(sumTarget(_numeric(2, '1,000')), isNull);
      expect(sumTarget(_numeric(3, 2.5)), isNull);
      expect(sumTarget(_numeric(4, -3)), isNull);
      expect(sumTarget(_word(5, 'cat')), isNull);
    });

    test('every built puzzle can be solved with its own tiles', () {
      for (final level in [
        const MiniGameLevel.younger(),
        const MiniGameLevel.older(),
        const MiniGameLevel.older(harder: true),
      ]) {
        final s = SumSettings.forLevel(level);
        for (var seed = 0; seed < 30; seed++) {
          for (final t in [0, 1, 2, 7, 12, 36, 100]) {
            final p = buildSum(_numeric(1, t), s, Random(seed))!;
            expect(sumHitsTarget(p.solution, t), isTrue, reason: '$t');
            // The solution tiles are in the bank (each once).
            final bank = [...p.tiles];
            for (final tile in p.solution) {
              expect(bank.remove(tile), isTrue);
            }
            expect(p.tiles.length, greaterThanOrEqualTo(4));
          }
        }
      }
    });

    test('younger levels use only plus and minus and have no timer', () {
      final s = SumSettings.forLevel(const MiniGameLevel.younger());
      expect(s.secondsPerQuestion, 0);
      for (var seed = 0; seed < 20; seed++) {
        final p = buildSum(_numeric(1, 9), s, Random(seed))!;
        expect(p.tiles.where((t) => t == opMul || t == opDiv), isEmpty);
      }
      expect(
        SumSettings.forLevel(const MiniGameLevel.older()).secondsPerQuestion,
        greaterThan(
          SumSettings.forLevel(const MiniGameLevel.older(harder: true))
              .secondsPerQuestion,
        ),
      );
    });

    test('the same seed builds the same puzzle', () {
      final s = SumSettings.forLevel(const MiniGameLevel.older());
      final a = buildSum(_numeric(1, 24), s, Random(9))!;
      final b = buildSum(_numeric(1, 24), s, Random(9))!;
      expect(a.tiles, b.tiles);
    });
  });
}
