import 'package:game_core/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

ContentItem mcq({Object correct = 1, List<String>? options}) => ContentItem({
  'id': 'a.1',
  'seq': 1,
  'difficulty': 1,
  'type': 'mcq',
  'explanation': 'e',
  'prompt': 'p',
  'options': options ?? ['a', 'b', 'c', 'd'],
  'correct': correct,
});

ContentItem numeric(Object answer, {Object tolerance = 0}) => ContentItem({
  'id': 'n.1',
  'seq': 1,
  'difficulty': 1,
  'type': 'numeric',
  'explanation': 'e',
  'prompt': 'p',
  'answer': answer,
  'tolerance': tolerance,
});

PoolItem pool(String id, ItemType type) => PoolItem(
  packId: 'p',
  subject: 'm',
  year: 3,
  topic: 't',
  item: ContentItem({
    'id': id,
    'seq': 1,
    'difficulty': 1,
    'type': type.name,
    'explanation': 'e',
    'prompt': 'p',
    'options': ['a', 'b'],
    'correct': 0,
    'answer': 4,
  }),
);

void main() {
  group('Registry', () {
    final door = MiniGame(
      id: 'door_runner',
      title: 'Door runner',
      itemTypes: const {ItemType.mcq},
      build: (_) => Object(),
      modes: const {MiniGameMode.game},
    );
    final balloon = MiniGame(
      id: 'balloon_pop',
      title: 'Balloon pop',
      itemTypes: const {ItemType.mcq, ItemType.numeric},
      build: (_) => Object(),
      modes: const {MiniGameMode.game},
    );
    final reg = MiniGameRegistry([RegistryEntry(door), RegistryEntry(balloon)]);

    List<String> ids(
      List<PoolItem> open, {
      MiniGameMode m = MiniGameMode.game,
    }) => [
      for (final o in reg.offers(
        open: open,
        subject: 'm',
        year: 3,
        mode: m,
        unlocked: {},
      ))
        o.game.id,
    ];

    test('games appear only with enough open items', () {
      expect(
        ids([for (var i = 0; i < 3; i++) pool('a$i', ItemType.mcq)]),
        isEmpty,
      );
      expect(ids([for (var i = 0; i < 4; i++) pool('a$i', ItemType.mcq)]), [
        'door_runner',
        'balloon_pop',
      ]);
    });

    test('numeric items count for balloon pop only', () {
      final open = [for (var i = 0; i < 4; i++) pool('n$i', ItemType.numeric)];
      expect(ids(open), ['balloon_pop']);
    });

    test('Game mode only', () {
      final open = [for (var i = 0; i < 4; i++) pool('a$i', ItemType.mcq)];
      expect(ids(open, m: MiniGameMode.study), isEmpty);
    });
  });
}
