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
  Future<void> cancelAll() async {}
}
