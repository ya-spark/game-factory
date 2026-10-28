/// Remotely tunable values. v1 ships a no-op that always returns the supplied default
/// (no backend, no Firebase Remote Config).
abstract interface class RemoteConfigService {
  Future<void> refresh();
  bool getBool(String key, bool defaultValue);
  int getInt(String key, int defaultValue);
  String getString(String key, String defaultValue);
}

class NoopRemoteConfigService implements RemoteConfigService {
  const NoopRemoteConfigService();
  @override
  Future<void> refresh() async {}
  @override
  bool getBool(String key, bool defaultValue) => defaultValue;
  @override
  int getInt(String key, int defaultValue) => defaultValue;
  @override
  String getString(String key, String defaultValue) => defaultValue;
}
