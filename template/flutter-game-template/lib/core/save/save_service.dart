import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'save_data.dart';

/// Persists the player's [SaveData]. Game/UI code depends only on this interface.
abstract interface class SaveService {
  Future<SaveData> load();
  Future<void> save(SaveData data);
}

/// Optional cloud backend (Play Games saved games in v1 stub form).
abstract interface class CloudSaveBackend {
  /// Raw JSON of the cloud save, or null if none / unavailable.
  Future<String?> read();
  Future<void> write(String json);
}

/// Local storage with versioned JSON. A corrupt primary slot falls back to the backup slot.
class LocalSaveService implements SaveService {
  LocalSaveService(this._prefs);

  static const String primaryKey = 'save.json';
  static const String backupKey = 'save.backup.json';

  final SharedPreferences _prefs;

  @override
  Future<SaveData> load() async {
    for (final key in [primaryKey, backupKey]) {
      final raw = _prefs.getString(key);
      if (raw == null) continue;
      try {
        final decoded = jsonDecode(raw) as Map<String, Object?>;
        return SaveData.fromJson(SaveMigrator.migrate(decoded));
      } on Object {
        continue; // corrupt or from a newer app: try the backup, else start fresh
      }
    }
    return const SaveData();
  }

  @override
  Future<void> save(SaveData data) async {
    final previous = _prefs.getString(primaryKey);
    if (previous != null) await _prefs.setString(backupKey, previous);
    await _prefs.setString(primaryKey, jsonEncode(data.toJson()));
  }
}

/// Local-first save with optional cloud mirroring. The newer `savedAtMs` wins on load.
/// With the v1 stub backend (always empty) this behaves exactly like [LocalSaveService].
class SyncingSaveService implements SaveService {
  SyncingSaveService(this._local, this._cloud, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final SaveService _local;
  final CloudSaveBackend _cloud;
  final DateTime Function() _now;

  @override
  Future<SaveData> load() async {
    final local = await _local.load();
    try {
      final raw = await _cloud.read();
      if (raw == null) return local;
      final cloud = SaveData.fromJson(
        SaveMigrator.migrate(jsonDecode(raw) as Map<String, Object?>),
      );
      return cloud.savedAtMs > local.savedAtMs ? cloud : local;
    } on Object {
      return local; // offline / not signed in: local is the source of truth
    }
  }

  @override
  Future<void> save(SaveData data) async {
    final stamped = data.copyWith(savedAtMs: _now().millisecondsSinceEpoch);
    await _local.save(stamped);
    try {
      await _cloud.write(jsonEncode(stamped.toJson()));
    } on Object {
      // Cloud is best-effort.
    }
  }
}

/// In-memory implementation for tests.
class MemorySaveService implements SaveService {
  MemorySaveService([this.data = const SaveData()]);
  SaveData data;
  int saves = 0;

  @override
  Future<SaveData> load() async => data;

  @override
  Future<void> save(SaveData d) async {
    data = d;
    saves++;
  }
}
