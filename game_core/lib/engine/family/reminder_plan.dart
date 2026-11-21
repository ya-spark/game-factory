/// One reminder to schedule: the calendar [day] (days since 1970-01-01), a stable notification
/// [id] and the [body] text.
class ReminderSlot {
  const ReminderSlot(this.day, this.id, this.body);
  final int day;
  final int id;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is ReminderSlot &&
      other.day == day &&
      other.id == id &&
      other.body == body;

  @override
  int get hashCode => Object.hash(day, id, body);
}

/// Which days get a gentle reminder (pure Dart, no clock of its own: the caller passes today).
abstract final class ReminderPlan {
  /// One-off reminders are scheduled for this many days from today (today included).
  static const int lookAheadDays = 7;

  /// No reminder after this many days without opening the app.
  static const int stopAfterDays = 3;

  /// The time picker allows 07:00 to 20:00 (child apps).
  static const int earliestHour = 7;
  static const int latestHour = 20;

  /// Notification ids 100..106: one per weekday slot, so a day always maps to the same id.
  static const int idBase = 100;
  static const int idCount = 7;

  /// The id the old repeating daily reminder used; cancelled on upgrade.
  static const int legacyDailyId = 1;

  /// Neutral wording: no streak loss, no coins, no names, no counts.
  static const List<String> messages = [
    'Time for a quick round?',
    'A few minutes of practice today?',
    'Ready for a short round?',
    'Come and have a go when you like.',
  ];

  /// Days of the week as Dart's `DateTime.weekday` (1 Monday .. 7 Sunday).
  static const Set<int> everyDay = {1, 2, 3, 4, 5, 6, 7};

  static int weekdayOf(int day) => (day + 3) % 7 + 1; // day 0 was a Thursday

  static int idFor(int day) => idBase + day % idCount;

  static int clampHour(int hour) => hour.clamp(earliestHour, latestHour);

  /// The reminders to schedule now.
  ///
  /// - [today], [nowMinutes] (minutes since local midnight): the injected clock.
  /// - [weekdays]: the days the parent allows.
  /// - [lastOpenedDay]: the last day the app was opened (negative: unknown, counts as today).
  ///   A value after [today] (the clock moved back) counts as today.
  /// - [goalMetToday]: the active child's daily goal is met, so today gets no reminder.
  ///
  /// Slots run from today through [lookAheadDays] - 1 days ahead, never after
  /// `lastOpenedDay + stopAfterDays` (silent stop; the next open restores the schedule).
  static List<ReminderSlot> build({
    required int today,
    required int nowMinutes,
    required int hour,
    required int minute,
    Set<int> weekdays = everyDay,
    required int lastOpenedDay,
    bool goalMetToday = false,
  }) {
    final opened = (lastOpenedDay < 0 || lastOpenedDay > today)
        ? today
        : lastOpenedDay;
    final last = opened + stopAfterDays;
    final at = clampHour(hour) * 60 + minute.clamp(0, 59);
    final out = <ReminderSlot>[];
    for (var i = 0; i < lookAheadDays; i++) {
      final day = today + i;
      if (day > last) break;
      if (!weekdays.contains(weekdayOf(day))) continue;
      if (i == 0 && (goalMetToday || at <= nowMinutes)) continue;
      out.add(ReminderSlot(day, idFor(day), messages[day % messages.length]));
    }
    return out;
  }
}
