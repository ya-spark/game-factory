import 'package:flutter_game_template/core/profile/profile_store.dart';
import 'package:flutter_game_template/core/save/save_data.dart';
import 'package:flutter_game_template/core/save/save_service.dart';
import 'package:flutter_game_template/core/config/app_config.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

ProfileStore _store({bool on = true}) => ProfileStore(
  saves: MemorySaveService(),
  retention: const RetentionConfig(),
  gameStatsEnabled: on,
);

void main() {
  test('an old save (v9) migrates with empty stats', () {
    final j = SaveMigrator.migrate({'version': 9, 'coins': 4});
    expect(j['version'], SaveData.currentVersion);
    final d = SaveData.fromJson(j);
    expect(d.coins, 4);
    expect(d.gameStats.isEmpty, isTrue);
  });

  test('stats survive a save round trip', () {
    final book = const GameStats()
        .record(
          const RunReport(gameId: 'g', score: 5, won: true, seconds: 3),
          2,
        )
        .book;
    final d = SaveData.fromJson(
      SaveMigrator.migrate(SaveData(gameStats: book).toJson()),
    );
    expect(d.gameStats.entry('g').plays, 1);
  });

  test('recordRun is a no-op when the flag is off', () async {
    final p = _store(on: false);
    await p.init();
    await p.recordRun(const RunReport(gameId: 'g', score: 5));
    expect(p.data.gameStats.isEmpty, isTrue);
  });

  test('new-best message is given once; reset keeps coins and best', () async {
    final p = _store();
    await p.init();
    await p.addCoins(10);
    await p.recordRun(
      const RunReport(gameId: 'g', score: 5),
      gameTitle: 'Game',
    );
    expect(p.takeNewBestMessage(), isNull);
    await p.recordRun(
      const RunReport(gameId: 'g', score: 9),
      gameTitle: 'Game',
    );
    expect(p.takeNewBestMessage(), contains('Game'));
    expect(p.takeNewBestMessage(), isNull);
    await p.resetGameStats();
    expect(p.data.gameStats.entry('g').plays, 0);
    expect(p.data.gameStats.entry('g').bestScore, 9);
    expect(p.data.coins, 10);
  });
}
