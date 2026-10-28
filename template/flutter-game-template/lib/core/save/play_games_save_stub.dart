import 'save_service.dart';

// ---------------------------------------------------------------------------
// STUB: Google Play Games "Saved Games" backend.
// Not implemented in v1: read() returns null and write() does nothing, so
// SyncingSaveService falls back to local storage only. Implement this class with
// a Play Games plugin when cloud saves are needed; no other code changes.
// ---------------------------------------------------------------------------
class PlayGamesCloudSaveStub implements CloudSaveBackend {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String json) async {}
}
