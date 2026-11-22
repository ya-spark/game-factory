import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../engine/content/mastery.dart';
import '../../engine/content/progress.dart';

/// Where web progress is kept: plain text under a key, on this device only (no account, no
/// server). Every call may throw when storage is blocked; [BrowserProgress] catches it.
abstract interface class ProgressStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
  Future<List<String>> keys();
}

/// [ProgressStorage] in shared preferences: browser local storage on the web (the plugin writes
/// `flutter.<key>`; no `dart:html` here), a plain store elsewhere.
class PrefsProgressStorage implements ProgressStorage {
  PrefsProgressStorage(this._prefs);
  final SharedPreferences _prefs;

  @override
  Future<String?> read(String key) async => _prefs.getString(key);
  @override
  Future<void> write(String key, String value) async {
    if (!await _prefs.setString(key, value)) {
      throw StateError('storage refused the write');
    }
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  @override
  Future<List<String>> keys() async => _prefs.getKeys().toList();
}

/// In memory (tests). [blocked] makes every call throw, like blocked browser storage.
class MemoryProgressStorage implements ProgressStorage {
  final Map<String, String> data = {};
  bool blocked = false;

  void _check() {
    if (blocked) throw StateError('storage blocked');
  }

  @override
  Future<String?> read(String key) async {
    _check();
    return data[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _check();
    data[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _check();
    data.remove(key);
  }

  @override
  Future<List<String>> keys() async {
    _check();
    return data.keys.toList();
  }
}

/// Game ids that were renamed (owner, 2026-11-22: a game's id is its name): old id to new id. Saved data under the
/// old id is read once and written under the new one (best scores here, the web's `amc.state` in games-web).
const Map<String, String> renamedGameIds = {
  'equation_builder': 'bridge_builder',
  'snake': 'parcel_train',
  'series_builder': 'domino_chain',
};

/// Browser-saved progress of the web games (W3; spec in the studio repo `docs/FEATURE-SPECS.md`).
///
/// Holds the skill progress behind the Constellation (one [SkillProgress] per rung, so stars
/// persist) and each game's best score. Keys: `amc.progress.v1` and `amc.best.<gameId>`.
/// When storage is blocked or full the object keeps working in memory ([storageOk] is false) and
/// the player simply loses progress on reload. It never throws.
class BrowserProgress extends ChangeNotifier {
  BrowserProgress(this._storage);

  static const String progressKey = 'amc.progress.v1';
  static const String bestPrefix = 'amc.best.';
  static const String prefix = 'amc.';

  /// Version written into the saved document. A newer version than this is ignored (not
  /// overwritten until the player records something new), an older one is migrated.
  static const int version = 1;

  final ProgressStorage _storage;

  Map<String, SkillProgress> _skills = {};
  final Map<String, int> _best = {};
  bool _storageOk = true;

  /// False after any read or write failed (blocked, full, private mode).
  bool get storageOk => _storageOk;

  /// Skill progress by skill key (`subject/year/id`), to feed `Trail.build`.
  ChildProgress get progress =>
      ChildProgress(skills: Map.unmodifiable(_skills));

  int bestScore(String gameId) => _best[gameId] ?? 0;

  /// Reads everything saved. Missing, corrupt or unknown-version data starts empty.
  Future<void> load() async {
    try {
      final raw = await _storage.read(progressKey);
      if (raw != null) _skills = _decode(raw);
      for (final k in await _storage.keys()) {
        if (!k.startsWith(bestPrefix)) continue;
        final v = int.tryParse(await _storage.read(k) ?? '');
        if (v != null && v > 0) _best[k.substring(bestPrefix.length)] = v;
      }
      await _migrateRenamed();
    } on Object {
      _storageOk = false;
    }
    notifyListeners();
  }

  /// Moves each best score saved under a renamed game's old id to the new id (the higher one wins), once: the old
  /// key is removed after the new one is written. A failure leaves the old key for the next load.
  Future<void> _migrateRenamed() async {
    for (final e in renamedGameIds.entries) {
      final old = _best.remove(e.key);
      if (old == null) continue;
      final best = old > bestScore(e.value) ? old : bestScore(e.value);
      _best[e.value] = best;
      await _storage.write('$bestPrefix${e.value}', '$best');
      await _storage.remove('$bestPrefix${e.key}');
    }
  }

  static Map<String, SkillProgress> _decode(String raw) {
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return {};
      final v = (j['v'] as num?)?.toInt() ?? 1;
      if (v > version) return {};
      final out = <String, SkillProgress>{};
      for (final e in (j['skills'] as Map? ?? const {}).entries) {
        if (e.key is String && e.value is Map) {
          try {
            out[e.key as String] = SkillProgress.fromJson(
              (e.value as Map).cast<String, Object?>(),
            );
          } on Object {
            continue; // one bad rung does not lose the others
          }
        }
      }
      return out;
    } on Object {
      return {};
    }
  }

  /// Adds one answer to a rung, updates the Constellation and saves.
  Future<void> recordEvidence(
    String skillKey,
    SkillEvidence evidence,
    SkillRules rules,
  ) async {
    final cur = _skills[skillKey] ?? const SkillProgress();
    _skills = {..._skills, skillKey: cur.add(evidence, rules)};
    notifyListeners();
    await _persist();
  }

  /// Keeps [score] as the game's best when it beats the saved one.
  Future<void> recordBest(String gameId, int score) async {
    if (score <= bestScore(gameId)) return;
    _best[gameId] = score;
    try {
      await _storage.write('$bestPrefix$gameId', '$score');
    } on Object {
      _storageOk = false;
    }
    notifyListeners();
  }

  /// Forgets everything this class saved (the "reset progress" button).
  Future<void> clear() async {
    _skills = {};
    _best.clear();
    try {
      for (final k in await _storage.keys()) {
        if (k == progressKey || k.startsWith(bestPrefix)) {
          await _storage.remove(k);
        }
      }
    } on Object {
      _storageOk = false;
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      await _storage.write(
        progressKey,
        jsonEncode({
          'v': version,
          'skills': {for (final e in _skills.entries) e.key: e.value.toJson()},
        }),
      );
    } on Object {
      _storageOk = false;
    }
  }
}
