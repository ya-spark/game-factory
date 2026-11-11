import 'package:flutter_game_template/core/config/app_config.dart';
import 'package:flutter_game_template/core/profile/profile_store.dart';
import 'package:flutter_game_template/core/save/save_service.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ProfileStore> _store({RewardsConfig? cap}) async {
  final p = ProfileStore(
    saves: MemorySaveService(),
    retention: const RetentionConfig(),
    cappedRewards: cap,
    clock: () => DateTime(2026, 11, 11, 10),
  );
  await p.init();
  final kid = (await p.addChild('Mia', year: 3))!;
  p.selectChild(kid.id);
  return p;
}

void main() {
  test(
    'Craft apps: daily reward and challenges count against the weekly cap',
    () async {
      final p = await _store(cap: const RewardsConfig(weeklyCapPerChild: 60));
      // The reward is 50 coins on day one; the cap is 60.
      expect(await p.claimDailyReward(), 50);
      await p.recordGameFinished(
        const GameSummary(
          score: 100000,
          linesCleared: 100,
          piecesPlaced: 100,
          maxCombo: 100,
        ),
      );
      var paid = 50;
      for (final c in p.challenges.where((c) => c.claimable)) {
        paid += (await p.claimChallenge(c.id))!;
      }
      // Challenges only got what was left of the week: never more than 60 in total.
      expect(paid, 60);
      expect(
        p.data.coins - 0,
        greaterThanOrEqualTo(60),
      ); // achievements may add on top
      expect(p.activeChild!.progress.rewards.coinsThisWeek(p.today), 60);
    },
  );

  test(
    'without the cap (the plain template) the reward is paid in full',
    () async {
      final p = await _store();
      expect(await p.claimDailyReward(), 50);
      expect(p.activeChild!.progress.rewards.coinsThisWeek(p.today), 0);
    },
  );
}
