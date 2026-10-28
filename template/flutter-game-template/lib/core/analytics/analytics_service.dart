/// Event tracking. v1 ships a no-op: no analytics SDK, no backend, no Firebase.
abstract interface class AnalyticsService {
  void logEvent(String name, [Map<String, Object?> params = const {}]);
}

class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();
  @override
  void logEvent(String name, [Map<String, Object?> params = const {}]) {}
}

/// Records events in memory; used by tests.
class RecordingAnalyticsService implements AnalyticsService {
  final List<(String, Map<String, Object?>)> events = [];
  @override
  void logEvent(String name, [Map<String, Object?> params = const {}]) =>
      events.add((name, params));
}
