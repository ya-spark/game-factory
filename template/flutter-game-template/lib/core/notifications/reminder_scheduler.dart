import 'package:flutter/widgets.dart';

import '../../engine/engine.dart';
import '../profile/profile_store.dart';
import 'notification_service.dart';

/// Keeps the one-off local reminders in step with the save (C4). All the rules live in
/// [ReminderPlan]; this class only reads the save and calls [NotificationService].
/// Does nothing unless the parent turned reminders on. Notification text carries only the app
/// name as title and a neutral message (no nickname, coins or counts: a lock screen shows it).
class ReminderScheduler with WidgetsBindingObserver {
  ReminderScheduler({
    required this.notifications,
    required this.profile,
    required this.title,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final NotificationService notifications;
  final ProfileStore profile;
  final String title;
  final DateTime Function() _now;

  Object? _lastSignature;
  bool _busy = false;

  /// Reschedules when the app opens or goes to the background.
  Future<void> sync() => _run(force: true);

  /// Starts watching: reschedules now, when the settings or the goal state change, and when the
  /// app returns to or leaves the foreground.
  Future<void> start() {
    profile.addListener(_onChange);
    WidgetsBinding.instance.addObserver(this);
    return sync();
  }

  void stop() {
    profile.removeListener(_onChange);
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      profile.onAppOpened().then((_) => sync());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      sync();
    }
  }

  void _onChange() => _run(force: false);

  Future<void> _run({required bool force}) async {
    final d = profile.data;
    final today = profile.today;
    final child = profile.activeChild;
    final goalMet =
        child != null &&
        child.progress.rewards.dayMarks.contains('goal:$today');
    final sig = [
      d.remindersOn,
      d.reminderHour,
      d.reminderMinute,
      ([...d.reminderDays]..sort()).join(),
      d.lastOpenedDay,
      today,
      goalMet,
    ].join('|');
    if (!force && sig == _lastSignature) return;
    if (_busy) return;
    _busy = true;
    try {
      _lastSignature = sig;
      // The old repeating reminder (before C4) is cancelled on upgrade.
      await notifications.cancelById(ReminderPlan.legacyDailyId);
      for (var i = 0; i < ReminderPlan.idCount; i++) {
        await notifications.cancelById(ReminderPlan.idBase + i);
      }
      if (!d.remindersOn) return;
      final now = _now();
      final slots = ReminderPlan.build(
        today: today,
        nowMinutes: now.hour * 60 + now.minute,
        hour: d.reminderHour,
        minute: d.reminderMinute,
        weekdays: d.reminderDays,
        lastOpenedDay: d.lastOpenedDay,
        goalMetToday: goalMet,
      );
      final at = ReminderPlan.clampHour(d.reminderHour);
      for (final s in slots) {
        final date = DateTime.utc(1970).add(Duration(days: s.day));
        await notifications.scheduleAt(
          id: s.id,
          when: DateTime(date.year, date.month, date.day, at, d.reminderMinute),
          title: title,
          body: s.body,
        );
      }
    } on Object catch (e) {
      debugPrint('Reminder scheduling failed: $e');
    } finally {
      _busy = false;
    }
  }
}
