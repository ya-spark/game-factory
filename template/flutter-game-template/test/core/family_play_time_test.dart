import 'package:flutter_game_template/core/config/app_config.dart';
import 'package:flutter_game_template/core/profile/profile_store.dart';
import 'package:flutter_game_template/core/save/save_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creditPlay adds seconds to the named child only; hold stops the active count', () async {
    var now = DateTime(2026, 11, 11, 10);
    final p = ProfileStore(
      saves: MemorySaveService(),
      retention: const RetentionConfig(),
      clock: () => now,
    );
    await p.init();
    final a = (await p.addChild('Mia', year: 3))!;
    final b = (await p.addChild('Sam', year: 4))!;
    p.selectChild(a.id);
    await p.holdPlay();
    now = now.add(const Duration(seconds: 100));
    p.resumePlay(); // held: no counting
    await p.pausePlay();
    await p.creditPlay(b.id, 40);
    await p.creditPlay(a.id, 25);
    await p.creditPlay(a.id, 0);
    await p.creditPlay('nobody', 10);
    int week(String id) =>
        p.children.firstWhere((c) => c.id == id).playTime.weekSeconds(p.today);
    expect(week(b.id), 40);
    expect(week(a.id), 25);
    p.releasePlay();
    now = now.add(const Duration(seconds: 30));
    await p.pausePlay();
    expect(week(a.id), 55);
    expect(week(b.id), 40);
  });
}
