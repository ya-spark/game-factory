import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_game_template/ui/game_registry.dart';
import 'package:flutter_game_template/ui/minigames/flash_review_screen.dart';
import 'package:flutter_game_template/ui/minigames/true_false_screen.dart';
import 'package:flutter_game_template/ui/minigames/tug_of_war_screen.dart';
import 'package:flutter_test/flutter_test.dart';

PoolItem pool(String id, ItemType type) => PoolItem(
  packId: 'p',
  subject: 'maths',
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
  }),
);

void main() {
  group('Registry', () {
    MiniGameRegistry reg() => MiniGameRegistry([
      RegistryEntry(tugOfWarGame),
      RegistryEntry(trueFalseGame),
      RegistryEntry(flashReviewGame),
    ]);
    List<String> ids(
      int n,
      MiniGameMode mode, {
      Set<String> unlocked = const {},
    }) => [
      for (final o in reg().offers(
        open: [for (var i = 0; i < n; i++) pool('q$i', ItemType.mcq)],
        subject: 'maths',
        year: 3,
        mode: mode,
        unlocked: unlocked,
      ))
        o.game.id,
    ];

    test('they appear only when enough items are open', () {
      expect(ids(3, MiniGameMode.game), isEmpty);
      expect(ids(3, MiniGameMode.study), isEmpty);
      expect(ids(4, MiniGameMode.game), ['tug_of_war', 'true_false']);
      expect(ids(4, MiniGameMode.study), ['true_false', 'flash_review']);
    });

    test('tug of war is coin-locked at 200, the others are free', () {
      expect(tugOfWarGame.access, GameAccess.coins);
      expect(tugOfWarGame.coinPrice, 200);
      expect(trueFalseGame.access, GameAccess.freeWithAds);
      expect(flashReviewGame.access, GameAccess.freeWithAds);
      expect(flashReviewGame.modes, {MiniGameMode.study});
      final offers = reg().offers(
        open: [for (var i = 0; i < 4; i++) pool('q$i', ItemType.mcq)],
        subject: 'maths',
        year: 3,
        mode: MiniGameMode.game,
        unlocked: const {},
      );
      expect(offers.first.locked, isTrue);
      expect(offers.first.price, 200);
    });

    test('the template registry carries all three', () {
      expect(
        appGames.entries.map((e) => e.game.id),
        containsAll(['tug_of_war', 'true_false', 'flash_review']),
      );
    });
  });
}
