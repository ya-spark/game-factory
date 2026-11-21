import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/kit/keys/keys.dart';

void main() {
  group('defaults', () {
    test('every slot has a key and no key is used twice', () {
      final map = GameKeyMap();
      final seen = <LogicalKeyboardKey>{};
      for (final s in KeySlot.all) {
        expect(map.keysOf(s), isNotEmpty, reason: s.id);
        for (final k in map.keysOf(s)) {
          expect(seen.add(k), isTrue, reason: '${s.id} reuses ${k.keyLabel}');
        }
      }
      expect(map.allDefault, isTrue);
    });

    test('player 1 has the arrows, player 2 has WASD on the left', () {
      final map = GameKeyMap();
      expect(
        map.resolve(LogicalKeyboardKey.arrowLeft)!.action,
        GameAction.left,
      );
      expect(map.resolve(LogicalKeyboardKey.keyA, twoPlayer: true)!.player, 2);
      expect(
        map.resolve(LogicalKeyboardKey.arrowLeft, twoPlayer: true)!.player,
        1,
      );
      expect(
        map.resolve(LogicalKeyboardKey.keyW, twoPlayer: true)!.action,
        GameAction.up,
      );
      expect(map.resolve(LogicalKeyboardKey.digit3)!.action, GameAction.pick3);
      expect(map.resolve(LogicalKeyboardKey.numpad3)!.action, GameAction.pick3);
    });

    test('in a single-player game the second hand also plays as player 1', () {
      final map = GameKeyMap();
      final i = map.resolve(LogicalKeyboardKey.keyD)!;
      expect((i.action, i.player), (GameAction.right, 1));
    });

    test('shared keys report player 1 and unknown keys nothing', () {
      final map = GameKeyMap();
      expect(
        map.resolve(LogicalKeyboardKey.space, twoPlayer: true)!.action,
        GameAction.pause,
      );
      expect(map.resolve(LogicalKeyboardKey.keyQ, twoPlayer: true)!.player, 1);
      expect(map.resolve(LogicalKeyboardKey.escape)!.action, GameAction.exit);
      expect(map.resolve(LogicalKeyboardKey.keyM), isNull);
    });

    test('player 1 keys stay on the right hand, player 2 on the left', () {
      const left = {'A', 'D', 'W', 'S', 'F', 'Z', 'X', 'C', 'V'};
      final map = GameKeyMap();
      for (final a in GameAction.values.where((a) => !a.shared)) {
        final k = map.primaryOf(KeySlot(a, 2));
        expect(left.contains(keyLabel(k)), isTrue, reason: a.name);
      }
    });
  });

  group('assign', () {
    test('a free key is assigned and the old one stops working', () {
      final map = GameKeyMap();
      final r = map.assign(
        const KeySlot(GameAction.left, 1),
        LogicalKeyboardKey.keyJ,
      );
      expect(r.ok, isTrue);
      expect(r.swappedWith, isNull);
      expect(map.resolve(LogicalKeyboardKey.keyJ)!.action, GameAction.left);
      expect(map.resolve(LogicalKeyboardKey.arrowLeft), isNull);
      expect(map.allDefault, isFalse);
    });

    test('a key in use is swapped, never leaving a slot without a key', () {
      final map = GameKeyMap();
      const left1 = KeySlot(GameAction.left, 1);
      const left2 = KeySlot(GameAction.left, 2);
      final r = map.assign(left1, LogicalKeyboardKey.keyA);
      expect(r.swappedWith, left2);
      expect(map.primaryOf(left1), LogicalKeyboardKey.keyA);
      expect(map.primaryOf(left2), LogicalKeyboardKey.arrowLeft);
      for (final s in KeySlot.all) {
        expect(map.keysOf(s), isNotEmpty, reason: s.id);
      }
    });

    test('Escape always exits and the system keys are refused', () {
      final map = GameKeyMap();
      expect(
        map
            .assign(const KeySlot(GameAction.exit, 0), LogicalKeyboardKey.keyX)
            .ok,
        isFalse,
      );
      for (final k in [
        LogicalKeyboardKey.escape,
        LogicalKeyboardKey.tab,
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.metaLeft,
      ]) {
        expect(
          map.assign(const KeySlot(GameAction.left, 1), k).ok,
          isFalse,
          reason: k.keyLabel,
        );
      }
      expect(map.allDefault, isTrue);
    });

    test('assigning the key a slot already has changes nothing', () {
      final map = GameKeyMap();
      var calls = 0;
      map.addListener(() => calls++);
      map.assign(
        const KeySlot(GameAction.left, 1),
        LogicalKeyboardKey.arrowLeft,
      );
      expect(calls, 0);
    });

    test('reset puts every key back', () {
      final map = GameKeyMap();
      map.assign(const KeySlot(GameAction.left, 1), LogicalKeyboardKey.keyJ);
      map.reset();
      expect(map.allDefault, isTrue);
    });
  });

  group('saving', () {
    test('keys survive a save and load', () async {
      final store = MemoryGameKeyStore();
      final a = await loadGameKeyMap(store);
      a.assign(const KeySlot(GameAction.pause, 0), LogicalKeyboardKey.keyP);
      a.assign(const KeySlot(GameAction.left, 1), LogicalKeyboardKey.keyA);
      expect(store.value, isNotNull);
      final b = await loadGameKeyMap(store);
      expect(
        b.primaryOf(const KeySlot(GameAction.pause, 0)),
        LogicalKeyboardKey.keyP,
      );
      expect(
        b.primaryOf(const KeySlot(GameAction.left, 1)),
        LogicalKeyboardKey.keyA,
      );
      expect(
        b.primaryOf(const KeySlot(GameAction.left, 2)),
        LogicalKeyboardKey.arrowLeft,
      );
    });

    test('going back to the defaults clears the save', () async {
      final store = MemoryGameKeyStore();
      final a = await loadGameKeyMap(store);
      a.assign(const KeySlot(GameAction.pause, 0), LogicalKeyboardKey.keyP);
      a.reset();
      expect(store.value, isNull);
    });

    test('a damaged or clashing save falls back safely', () async {
      for (final bad in [
        'not json',
        '[]',
        '{"p1.left": "x"}',
        '{"nope.x": [1]}',
      ]) {
        final store = MemoryGameKeyStore()..value = bad;
        final map = await loadGameKeyMap(store);
        expect(map.allDefault, isTrue, reason: bad);
      }
      // Two slots saved on one key: the second keeps its start key.
      final store = MemoryGameKeyStore()
        ..value = jsonEncode({
          'p1.left': [LogicalKeyboardKey.keyJ.keyId],
          'p2.left': [LogicalKeyboardKey.keyJ.keyId],
        });
      final map = await loadGameKeyMap(store);
      expect(
        map.primaryOf(const KeySlot(GameAction.left, 1)),
        LogicalKeyboardKey.keyJ,
      );
      expect(
        map.primaryOf(const KeySlot(GameAction.left, 2)),
        LogicalKeyboardKey.keyA,
      );
      final seen = <LogicalKeyboardKey>{};
      for (final s in KeySlot.all) {
        for (final k in map.keysOf(s)) {
          expect(seen.add(k), isTrue, reason: s.id);
        }
      }
    });

    test('saved slot ids are stable text', () {
      expect(const KeySlot(GameAction.left, 1).id, 'p1.left');
      expect(const KeySlot(GameAction.pick3, 2).id, 'p2.pick3');
      expect(const KeySlot(GameAction.pause, 0).id, 'all.pause');
      expect(KeySlot.byId('p2.down'), const KeySlot(GameAction.down, 2));
    });
  });

  test('labels are short and the arrows read aloud as words', () {
    expect(keyLabel(LogicalKeyboardKey.arrowLeft), '←');
    expect(keySpokenLabel(LogicalKeyboardKey.arrowLeft), 'Left arrow');
    expect(keyLabel(LogicalKeyboardKey.space), 'Space');
    expect(keyLabel(LogicalKeyboardKey.keyA), 'A');
  });
}
