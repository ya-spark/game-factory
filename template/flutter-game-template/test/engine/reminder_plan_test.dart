import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Day 20000 is a Saturday? Compute from the rule instead of assuming.
  const today = 20000;
  final wd = ReminderPlan.weekdayOf(today);

  List<ReminderSlot> plan({
    int now = 600,
    int hour = 19,
    Set<int> days = ReminderPlan.everyDay,
    int? opened,
    bool met = false,
    int day = today,
  }) => ReminderPlan.build(
    today: day,
    nowMinutes: now,
    hour: hour,
    minute: 0,
    weekdays: days,
    lastOpenedDay: opened ?? day,
    goalMetToday: met,
  );

  test('weekday rule matches DateTime', () {
    final d = DateTime.utc(2026, 11, 14);
    final day = d.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    expect(ReminderPlan.weekdayOf(day), d.weekday);
  });

  test('opened today: today plus the next three days, then silence', () {
    final p = plan();
    expect(p.map((s) => s.day), [today, today + 1, today + 2, today + 3]);
    expect(ReminderPlan.lookAheadDays, 7);
    expect(ReminderPlan.stopAfterDays, 3);
  });

  test(
    'look-ahead is capped at 7 days when the app was opened more recently',
    () {
      expect(plan().length, lessThanOrEqualTo(7));
    },
  );

  test('today is skipped when the time has passed', () {
    expect(plan(now: 20 * 60).first.day, today + 1);
  });

  test('today is skipped when the goal is met', () {
    final p = plan(met: true);
    expect(p.first.day, today + 1);
    expect(p.length, 3);
  });

  test('only the chosen weekdays', () {
    final p = plan(days: {wd});
    expect(p.map((s) => s.day), [today]);
    final none = plan(days: <int>{});
    expect(none, isEmpty);
  });

  test('three days unopened: nothing is left to schedule', () {
    expect(
      plan(opened: today - 3, now: 0).where((s) => s.day > today - 3 + 3),
      isEmpty,
    );
    expect(plan(opened: today - 4), isEmpty);
  });

  test('opening again restores the schedule', () {
    expect(plan(opened: today - 10), isEmpty);
    expect(plan(opened: today), isNotEmpty);
  });

  test('clock moved back: a later last-opened day counts as today', () {
    expect(plan(opened: today + 30).map((s) => s.day).last, today + 3);
    expect(plan(opened: -1).isNotEmpty, isTrue);
  });

  test('hour is clamped to 07:00 to 20:00 and ids are stable per day', () {
    expect(ReminderPlan.clampHour(3), 7);
    expect(ReminderPlan.clampHour(23), 20);
    final a = plan();
    final b = plan(day: today + 1, opened: today + 1);
    final shared = a.where((s) => s.day == today + 1).single;
    expect(b.firstWhere((s) => s.day == today + 1).id, shared.id);
    expect(a.map((s) => s.id).toSet().length, a.length);
  });

  test('messages are neutral', () {
    expect(ReminderPlan.messages.length, inInclusiveRange(3, 4));
    for (final m in ReminderPlan.messages) {
      expect(m.toLowerCase(), isNot(contains('streak')));
      expect(m.toLowerCase(), isNot(contains('coin')));
    }
  });

  group('goal presets', () {
    test('values and default', () {
      expect(GoalPreset.values.map((p) => [p.dailyItems, p.weeklyItems]), [
        [3, 15],
        [5, 25],
        [8, 40],
      ]);
      expect(GoalPreset.parse(null), GoalPreset.steady);
      expect(GoalPreset.parse('big'), GoalPreset.big);
    });

    test('Steady equals the defaults; coins and cap do not change', () {
      const base = RewardsConfig();
      final steady = base.withPreset(GoalPreset.steady);
      expect(steady.dailyGoalItems, base.dailyGoalItems);
      expect(steady.weeklyGoalItems, base.weeklyGoalItems);
      for (final p in GoalPreset.values) {
        final c = base.withPreset(p);
        expect(c.dailyGoalCoins, base.dailyGoalCoins);
        expect(c.weeklyGoalCoins, base.weeklyGoalCoins);
        expect(c.weeklyCapPerChild, base.weeklyCapPerChild);
        expect(c.topicCoins, base.topicCoins);
      }
    });
  });
}
