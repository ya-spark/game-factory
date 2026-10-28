import 'dart:convert';

import 'package:flutter_game_template/core/clock.dart';
import 'package:flutter_game_template/core/save/save_data.dart';
import 'package:flutter_game_template/core/save/save_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCloud implements CloudSaveBackend {
  String? stored;
  bool failing = false;
  @override
  Future<String?> read() async {
    if (failing) throw Exception('offline');
    return stored;
  }

  @override
  Future<void> write(String json) async {
    if (failing) throw Exception('offline');
    stored = json;
  }
}

void main() {
  group('SaveData / migration', () {
    test('round trips through JSON with the current version', () {
      const d = SaveData(coins: 12, bestScore: 340, adsRemoved: true);
      final json = d.toJson();
      expect(json['version'], SaveData.currentVersion);
      final back = SaveData.fromJson(SaveMigrator.migrate(json));
      expect(back.coins, 12);
      expect(back.bestScore, 340);
      expect(back.adsRemoved, isTrue);
    });

    test('v0 saves migrate to the current version', () {
      final migrated = SaveMigrator.migrate({
        'highScore': 99,
        'coinBalance': 7,
      });
      final d = SaveData.fromJson(migrated);
      expect(migrated['version'], SaveData.currentVersion);
      expect(d.bestScore, 99);
      expect(d.coins, 7);
    });

    test('v1 saves migrate to v2', () {
      final d = SaveData.fromJson(
        SaveMigrator.migrate({'version': 1, 'coins': 5, 'bestScore': 8}),
      );
      expect(d.coins, 5);
      expect(d.processedPurchases, isEmpty);
    });

    test('a save from a newer app version is rejected', () {
      expect(
        () => SaveMigrator.migrate({'version': SaveData.currentVersion + 1}),
        throwsFormatException,
      );
    });
  });

  group('LocalSaveService', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('empty storage gives a fresh save', () async {
      final s = LocalSaveService(await SharedPreferences.getInstance());
      expect((await s.load()).coins, 0);
    });

    test('save then load', () async {
      final s = LocalSaveService(await SharedPreferences.getInstance());
      await s.save(const SaveData(coins: 50));
      expect((await s.load()).coins, 50);
    });

    test('corrupt primary falls back to the backup slot', () async {
      final prefs = await SharedPreferences.getInstance();
      final s = LocalSaveService(prefs);
      await s.save(const SaveData(coins: 10));
      await s.save(const SaveData(coins: 20)); // backup now holds coins=10
      await prefs.setString(LocalSaveService.primaryKey, '{not json');
      expect((await s.load()).coins, 10);
    });

    test('all slots corrupt gives a fresh save, not a crash', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(LocalSaveService.primaryKey, 'x');
      await prefs.setString(LocalSaveService.backupKey, 'y');
      expect((await LocalSaveService(prefs).load()).coins, 0);
    });
  });

  group('SyncingSaveService', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('newer cloud save wins, older loses', () async {
      final local = MemorySaveService(const SaveData(coins: 1, savedAtMs: 100));
      final cloud = _FakeCloud()
        ..stored = jsonEncode(
          const SaveData(coins: 9, savedAtMs: 200).toJson(),
        );
      final s = SyncingSaveService(local, cloud);
      expect((await s.load()).coins, 9);
      cloud.stored = jsonEncode(
        const SaveData(coins: 9, savedAtMs: 50).toJson(),
      );
      expect((await s.load()).coins, 1);
    });

    test('offline cloud never breaks local saves', () async {
      final local = MemorySaveService();
      final cloud = _FakeCloud()..failing = true;
      final s = SyncingSaveService(local, cloud);
      await s.save(const SaveData(coins: 3));
      expect((await s.load()).coins, 3);
    });
  });

  group('ClockGuard (backwards clock)', () {
    const guard = ClockGuard();
    final t = DateTime(2026, 5, 10, 12);

    test('never returns a time earlier than the last seen', () {
      final earlier = t.subtract(const Duration(days: 3));
      expect(guard.trusted(earlier, t.millisecondsSinceEpoch), t);
      expect(guard.isTampered(earlier, t.millisecondsSinceEpoch), isTrue);
    });

    test('normal forward time is trusted', () {
      final later = t.add(const Duration(hours: 5));
      expect(guard.trusted(later, t.millisecondsSinceEpoch), later);
      expect(guard.isTampered(later, t.millisecondsSinceEpoch), isFalse);
    });

    test('first run (no last seen) trusts the device clock', () {
      expect(guard.trusted(t, 0), t);
    });
  });
}
