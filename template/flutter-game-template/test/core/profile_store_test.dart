import 'package:flutter_game_template/core/config/app_config.dart';
import 'package:flutter_game_template/core/config/products.dart';
import 'package:flutter_game_template/core/profile/profile_store.dart';
import 'package:flutter_game_template/core/purchase/purchase_service.dart';
import 'package:flutter_game_template/core/save/save_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _catalog = ProductCatalog([
  ProductDef(
    id: 'remove_ads',
    type: ProductType.nonConsumable,
    title: 'Remove Ads',
    description: '',
    grants: 'remove_ads',
  ),
  ProductDef(
    id: 'coins_500',
    type: ProductType.consumable,
    title: 'Coins',
    description: '',
    coins: 500,
  ),
]);

void main() {
  late DateTime now;
  late MemorySaveService saves;

  ProfileStore make({RetentionConfig retention = const RetentionConfig()}) =>
      ProfileStore(saves: saves, retention: retention, clock: () => now);

  setUp(() {
    now = DateTime(2026, 3, 1, 10);
    saves = MemorySaveService();
  });

  test('daily reward: claim once per day, then again next day', () async {
    final p = make();
    await p.init();
    expect(p.dailyRewardAvailable, isTrue);
    expect(await p.claimDailyReward(), 50);
    expect(p.dailyRewardAvailable, isFalse);
    expect(await p.claimDailyReward(), isNull);
    now = now.add(const Duration(days: 1));
    await p.onAppOpened();
    expect(p.dailyRewardAvailable, isTrue);
    expect(await p.claimDailyReward(), 75);
    expect(p.data.coins, 125);
  });

  test('setting the clock back does not allow a second claim', () async {
    final p = make();
    await p.init();
    await p.claimDailyReward();
    now = now.subtract(const Duration(days: 2));
    await p.onAppOpened();
    expect(p.clockTampered, isTrue);
    expect(p.dailyRewardAvailable, isFalse);
    expect(await p.claimDailyReward(), isNull);
  });

  test('clock guard survives an app restart (persisted last seen)', () async {
    var p = make();
    await p.init();
    await p.claimDailyReward();
    now = now.subtract(const Duration(days: 2));
    p = make();
    await p.init();
    expect(p.dailyRewardAvailable, isFalse);
  });

  test('streak grows over consecutive days', () async {
    final p = make();
    await p.init();
    for (var i = 0; i < 3; i++) {
      now = now.add(const Duration(days: 1));
      await p.onAppOpened();
    }
    expect(p.displayStreak, 4);
  });

  test('finishing a game updates stats, best score and challenges', () async {
    final p = make();
    await p.init();
    final unlocked = await p.recordGameFinished(
      const GameSummary(
        score: 1500,
        linesCleared: 6,
        piecesPlaced: 20,
        maxCombo: 3,
      ),
    );
    expect(p.data.bestScore, 1500);
    expect(p.data.stats.gamesPlayed, 1);
    expect(unlocked.map((a) => a.id), contains('first_game'));
    expect(unlocked.map((a) => a.id), contains('score_1000'));
    expect(p.data.coins, greaterThan(0)); // achievement rewards
    expect(p.data.challenges.challenges, hasLength(3));
  });

  test('features can be switched off by config', () async {
    final p = make(
      retention: const RetentionConfig(
        dailyReward: false,
        streaks: false,
        dailyChallenges: false,
        achievements: false,
      ),
    );
    await p.init();
    expect(p.dailyRewardAvailable, isFalse);
    expect(await p.claimDailyReward(), isNull);
    expect(p.challenges, isEmpty);
    final unlocked = await p.recordGameFinished(
      const GameSummary(
        score: 5,
        linesCleared: 0,
        piecesPlaced: 1,
        maxCombo: 1,
      ),
    );
    expect(unlocked, isEmpty);
  });

  test('remove-ads purchase sets the flag; restore is idempotent', () async {
    final p = make();
    await p.init();
    const u = PurchaseUpdate('remove_ads', PurchaseStatus.purchased);
    await p.deliverPurchase(u, _catalog);
    await p.deliverPurchase(u, _catalog);
    expect(p.data.adsRemoved, isTrue);
  });

  test('consumable is granted once per purchase id', () async {
    final p = make();
    await p.init();
    const u = PurchaseUpdate(
      'coins_500',
      PurchaseStatus.purchased,
      purchaseId: 'order-1',
    );
    await p.deliverPurchase(u, _catalog);
    await p.deliverPurchase(u, _catalog); // replay
    expect(p.data.coins, 500);
    await p.deliverPurchase(
      const PurchaseUpdate(
        'coins_500',
        PurchaseStatus.purchased,
        purchaseId: 'order-2',
      ),
      _catalog,
    );
    expect(p.data.coins, 1000);
  });

  test('canceled purchases grant nothing', () async {
    final p = make();
    await p.init();
    await p.deliverPurchase(
      const PurchaseUpdate('remove_ads', PurchaseStatus.canceled),
      _catalog,
    );
    expect(p.data.adsRemoved, isFalse);
  });

  test('spendCoins refuses to go negative', () async {
    final p = make();
    await p.init();
    await p.addCoins(10);
    expect(await p.spendCoins(11), isFalse);
    expect(await p.spendCoins(10), isTrue);
    expect(p.data.coins, 0);
  });

  test('state is persisted after changes', () async {
    final p = make();
    await p.init();
    await p.addCoins(5);
    expect(saves.data.coins, 5);
  });
}
