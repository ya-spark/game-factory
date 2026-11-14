import 'package:flutter_game_template/core/profile/child_profile.dart';
import 'package:flutter_game_template/core/save/save_data.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';

void main() {
  test('a version 3 save loads with the new settings at their defaults', () {
    final old = <String, Object?>{
      'version': 3,
      'coins': 12,
      'remindersOn': true,
      'profiles': [
        {'id': 'p1', 'nickname': 'Mia', 'year': 3},
      ],
    };
    final d = SaveData.fromJson(SaveMigrator.migrate(old));
    expect(d.coins, 12);
    expect(d.remindersOn, isTrue);
    expect(d.reminderHour, 19);
    expect(d.reminderMinute, 0);
    expect(d.textSize, 'normal');
    expect(d.reduceMotion, isFalse);
    expect(d.profiles.single.playTime.secondsByDay, isEmpty);
    expect(SaveData.currentVersion, 9);
  });

  test('settings and play time survive a save round trip', () {
    final d = SaveData(
      textSize: 'large',
      reduceMotion: true,
      reminderHour: 7,
      reminderMinute: 45,
      profiles: [
        ChildProfile(
          id: 'p1',
          nickname: 'Mia',
          playTime: const PlayTimeLog().add(50, 90),
        ),
      ],
    );
    final back = SaveData.fromJson(SaveMigrator.migrate(d.toJson()));
    expect(back.textSize, 'large');
    expect(back.reduceMotion, isTrue);
    expect(back.reminderHour, 7);
    expect(back.reminderMinute, 45);
    expect(back.profiles.single.playTime.secondsByDay, {50: 90});
  });

  test('settings setters save through the profile store', () async {
    final s = await buildFakeServices();
    await s.profile.setTextSize(TextSizeChoice.large);
    await s.profile.setReduceMotion(true);
    await s.profile.setReminderTime(8, 30);
    await s.profile.setReminderTime(99, 99); // clamped
    final d = s.profile.data;
    expect(d.textSize, 'large');
    expect(d.reduceMotion, isTrue);
    expect(d.reminderHour, 23);
    expect(d.reminderMinute, 59);
  });

  test(
    'play time is added to the active child and counted this week',
    () async {
      var now = DateTime(2026, 11, 12, 16);
      final s = await buildFakeServices(clock: () => now);
      final kid = (await s.profile.addChild('Mia', year: 3))!;
      s.profile.selectChild(kid.id); // starts the clock
      now = now.add(const Duration(minutes: 10));
      await s.profile.pausePlay();
      now = now.add(const Duration(minutes: 5)); // not playing: not counted
      s.profile.resumePlay();
      now = now.add(const Duration(minutes: 3));
      await s.profile.leaveChild();
      final child = s.profile.children.single;
      expect(child.playTime.weekSeconds(s.profile.today), 13 * 60);
      // Pausing with nothing running changes nothing.
      await s.profile.pausePlay();
      expect(
        s.profile.children.single.playTime.weekSeconds(s.profile.today),
        780,
      );
    },
  );

  test('a clock moved back adds no time', () async {
    var now = DateTime(2026, 11, 12, 16);
    final s = await buildFakeServices(clock: () => now);
    final kid = (await s.profile.addChild('Mia', year: 3))!;
    s.profile.selectChild(kid.id);
    now = now.subtract(const Duration(hours: 1));
    await s.profile.pausePlay();
    expect(s.profile.children.single.playTime.secondsByDay, isEmpty);
  });

  test('reset progress keeps the player, coins and purchases', () async {
    final s = await buildFakeServices();
    final kid = (await s.profile.addChild('Mia', year: 3))!;
    await s.profile.setChildLockedMode(kid.id, LearnMode.study);
    await s.profile.addCoins(50);
    await s.profile.setChildProgress(
      kid.id,
      const ChildProgress(
        topics: {
          'maths/3/x': TopicResult(attempted: 1, answers: 2, correct: 1),
        },
      ),
    );
    s.profile.selectChild(kid.id);
    await s.profile.pausePlay();
    await s.profile.resetChildProgress(kid.id);
    final c = s.profile.children.single;
    expect(c.nickname, 'Mia');
    expect(c.year, 3);
    expect(c.lockedMode, LearnMode.study);
    expect(c.progress.topics, isEmpty);
    expect(c.playTime.secondsByDay, isEmpty);
    expect(s.profile.data.coins, 50);
  });
}
