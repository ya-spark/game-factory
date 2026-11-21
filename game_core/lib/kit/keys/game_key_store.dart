import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'game_key_map.dart';

/// Where the player's keys are kept between visits (on this device only; no account, no server).
abstract interface class GameKeyStore {
  /// The saved keys as text, or null when nothing was saved.
  Future<String?> read();
  Future<void> write(String json);
  Future<void> clear();
}

/// [GameKeyStore] in shared preferences (browser storage on the web).
class PrefsGameKeyStore implements GameKeyStore {
  PrefsGameKeyStore(this._prefs, {this.name = 'game_keys_v1'});

  final SharedPreferences _prefs;
  final String name;

  @override
  Future<String?> read() async => _prefs.getString(name);

  @override
  Future<void> write(String json) => _prefs.setString(name, json);

  @override
  Future<void> clear() => _prefs.remove(name);
}

/// In memory (tests).
class MemoryGameKeyStore implements GameKeyStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String json) async => value = json;

  @override
  Future<void> clear() async => value = null;
}

/// A [GameKeyMap] that loads its keys from a [GameKeyStore] and saves every change.
Future<GameKeyMap> loadGameKeyMap(GameKeyStore store) async {
  final map = GameKeyMap();
  try {
    final text = await store.read();
    if (text != null) {
      final json = jsonDecode(text);
      if (json is Map<String, Object?>) map.restore(GameKeyMap.fromJson(json));
    }
  } catch (_) {
    // A damaged save is not worth a crash: the starting keys stay.
  }
  map.addListener(() {
    if (map.allDefault) {
      store.clear();
    } else {
      store.write(jsonEncode(map.toJson()));
    }
  });
  return map;
}
