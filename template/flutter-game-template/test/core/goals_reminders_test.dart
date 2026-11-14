import 'package:flutter_game_template/core/notifications/reminder_scheduler.dart';
import 'package:flutter_game_template/core/save/save_data.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';

void main() {
  test('a version 7 save gets the new defaults and keeps its reminder', () {
    final d = SaveData.fromJson(
      SaveMigrator.migrate({
        'version': 7,
        'remindersOn': true,
        'reminderHour': 8,
        'reminderMinute': 30,
        'profiles': [
          {'id': 'p1', 'nickname': 'Mia'},
        ],
      }),
    );
    expect(SaveData.currentVersion, 9);
    expect(d.remindersOn, isTrue);
    expect(d.reminderHour, 8);
    expect(d.reminderMinute, 30);
    expect(d.reminderDays, {1, 2, 3, 4, 5, 6, 7});
    expect(d.lastOpenedDay, -1);
    expect(d.profiles.single.goalPreset, GoalPreset.steady);
  });

  test('goal preset and reminder days survive a round trip', () async {
    final s = await buildFakeServices(contentEnabled: true);
    final c = (await s.profile.addChild('Mia'))!;
    await s.profile.setGoalPreset(c.id, GoalPreset.big);
    await s.profile.setReminderDays({1, 3});
    final back = SaveData.fromJson(
      SaveMigrator.migrate(s.profile.data.toJson()),
    );
    expect(back.profiles.single.goalPreset, GoalPreset.big);
    expect(back.reminderDays, {1, 3});
    expect(s.rewardsFor(s.profile.children.single).dailyGoalItems, 8);
  });

  group('ReminderScheduler', () {
    var now = DateTime(2026, 11, 14, 10); // 10:00
    late FakeNotificationService n;

    Future<ReminderScheduler> setup() async {
      n = FakeNotificationService();
      final s = await buildFakeServices(
        contentEnabled: true,
        goalsParentArea: true,
        notifications: n,
        clock: () => now,
      );
      await s.profile.addChild('Mia');
      s.profile.selectChild(s.profile.children.single.id);
      await s.profile.setReminders(true);
      await s.profile.setReminderTime(19, 0);
      return ReminderScheduler(
        notifications: n,
        profile: s.profile,
        title: 'App',
        now: () => now,
      );
    }

    test('schedules today and three more days with neutral text', () async {
      final r = await setup();
      await r.sync();
      expect(n.scheduled.length, 4);
      expect(n.scheduled.values.first.hour, 19);
      expect(n.cancelled, contains(ReminderPlan.legacyDailyId));
      for (final b in n.bodies.values) {
        expect(ReminderPlan.messages, contains(b));
      }
    });

    test('nothing scheduled when reminders are off', () async {
      final r = await setup();
      await r.profile.setReminders(false);
      await r.sync();
      expect(n.scheduled, isEmpty);
    });

    test('goal met cancels today only', () async {
      final r = await setup();
      await r.sync();
      final today = r.profile.today;
      final id = ReminderPlan.idFor(today);
      expect(n.scheduled.containsKey(id), isTrue);
      final c = r.profile.activeChild!;
      await r.profile.setChildProgress(
        c.id,
        c.progress.copyWith(
          rewards: c.progress.rewards.copyWith(dayMarks: {'goal:$today'}),
        ),
      );
      await r.sync();
      expect(n.scheduled.containsKey(id), isFalse);
      expect(n.scheduled.length, 3);
    });

    test('silent after 3 days unopened, restored on the next open', () async {
      final r = await setup();
      await r.sync();
      now = DateTime(2026, 11, 20, 10);
      // Not opened since the 14th: nothing in the future is allowed.
      await r.sync();
      expect(n.scheduled, isEmpty);
      await r.profile.onAppOpened();
      await r.sync();
      expect(n.scheduled, isNotEmpty);
    });
  });
}
