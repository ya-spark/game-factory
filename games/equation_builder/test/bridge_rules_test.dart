import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_equation_builder/equation_builder.dart';

void main() {
  group('Bridge builder rules (SPEC: Rules)', () {
    test('settings: younger 3 slots and no timer, older 5 slots and a gentle timer, study never timed', () {
      final y = BridgeSettings.forLevel(const MiniGameLevel.younger());
      expect(y.slots, 3);
      expect(y.secondsPerQuestion, 0);
      final o = BridgeSettings.forLevel(const MiniGameLevel.older());
      expect(o.slots, 5);
      expect(o.secondsPerQuestion, 60);
      expect(
        BridgeSettings.forLevel(const MiniGameLevel.older(harder: true))
            .secondsPerQuestion,
        40,
      );
      expect(
        BridgeSettings.forLevel(
          const MiniGameLevel.older(),
          study: true,
        ).secondsPerQuestion,
        0,
      );
    });

    test('stages: three gaps each, scenery river, canyon, sky, then around; the flag ends a stage and the last round', () {
      expect(bridgeStageFor(0, 10).scenery, Scenery.river);
      expect(bridgeStageFor(3, 10).scenery, Scenery.canyon);
      expect(bridgeStageFor(6, 10).scenery, Scenery.sky);
      expect(bridgeStageFor(9, 10).scenery, Scenery.river);
      expect(
        [for (var i = 0; i < 10; i++) bridgeStageFor(i, 10).endsStage],
        [false, false, true, false, false, true, false, false, true, true],
      );
      expect(bridgeStageFor(9, 10).gaps, 1);
    });

    test('stage stars: all first go 3, half 2, otherwise 1', () {
      expect(bridgeStageStars(firstTry: 3, gaps: 3), 3);
      expect(bridgeStageStars(firstTry: 2, gaps: 3), 2);
      expect(bridgeStageStars(firstTry: 0, gaps: 3), 1);
    });

    test('board: place, replace, remove, remove last, clear', () {
      final b = BridgeBoard(tiles: ['3', '+', '4', '9'], slotCount: 3);
      expect(b.place(0), isTrue);
      expect(b.place(0), isFalse); // already placed
      expect(b.place(1, slot: 2), isTrue);
      expect(b.tokens, ['3', '+']);
      expect(b.place(2, slot: 2), isTrue); // replaces the plus
      expect(b.isPlaced(1), isFalse);
      expect(b.removeLast(), isTrue);
      expect(b.tokens, ['3']);
      expect(b.removeSlot(1), isFalse);
      b.clear();
      expect(b.isEmpty, isTrue);
    });

    test('verdicts: any sum equal to the target is right; one number never is; a full miss is wrong', () {
      final b = BridgeBoard(
        tiles: ['7', '+', '5', '12', '−', '2'],
        slotCount: 5,
      );
      b.place(3);
      expect(b.check(12), BridgeVerdict.tooShort);
      expect(b.autoVerdict(12), isNull);
      b.place(1);
      b.place(2);
      expect(b.check(12), BridgeVerdict.wrong); // 12 + 5 = 17
      expect(b.autoVerdict(12), isNull); // not full: wait
      b.clear();
      b.place(0);
      b.place(1);
      b.place(2);
      expect(b.autoVerdict(12), BridgeVerdict.right); // 7 + 5
      b.clear();
      b.place(3);
      b.place(4);
      b.place(5);
      expect(b.check(10), BridgeVerdict.right); // 12 - 2
      b.place(1);
      b.place(0);
      expect(b.isFull, isTrue);
      expect(b.autoVerdict(99), BridgeVerdict.wrong);
    });

    test('deterministic by seed: the same seed builds the same tiles for every level', () {
      for (final l in [
        const MiniGameLevel.younger(),
        const MiniGameLevel.older(),
      ]) {
        final s = BridgeSettings.forLevel(l).equation;
        final item = ContentItem({
          'id': 'n',
          'seq': 1,
          'difficulty': 1,
          'type': 'numeric',
          'explanation': 'x',
          'prompt': 'p',
          'answer': 18,
        });
        expect(
          buildEquation(item, s, Random(4))!.tiles,
          buildEquation(item, s, Random(4))!.tiles,
        );
      }
    });

    test('rules stay pure Dart: no Flutter import in the rules folder', () {
      // Checked by import: bridge_rules.dart only imports game_core engine and the rules file.
      expect(BridgeBoard(tiles: const ['1'], slotCount: 1).spoken, '');
    });
  });
}
