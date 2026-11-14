/// Local (on-device) notifications such as a daily reward reminder. No push, no backend.
abstract interface class NotificationService {
  Future<void> initialize();

  /// Asks for permission where needed (Android 13+). Returns whether notifications are allowed.
  Future<bool> requestPermission();

  /// Schedules a repeating daily reminder at [hour]:[minute] local time.
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
  });

  /// Schedules a one-off, inexact notification at [when] (local time) with the given [id]
  /// (no exact-alarm permission). Scheduling an id again replaces it. No-op when [when] is past.
  Future<void> scheduleAt({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  });

  /// Cancels one scheduled notification.
  Future<void> cancelById(int id);

  Future<void> cancelAll();
}

class NoopNotificationService implements NotificationService {
  const NoopNotificationService();
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {}
  @override
  Future<void> scheduleAt({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {}
  @override
  Future<void> cancelById(int id) async {}
  @override
  Future<void> cancelAll() async {}
}
