import 'package:shared_preferences/shared_preferences.dart';

/// The storage key prefix of one game in the web build (`<app id>.`).
///
/// A browser keeps local storage per origin, not per path, and the web copies of all games share
/// one origin. Without a prefix every game would read and overwrite the same `save.json`. Pure Dart.
String webStoragePrefix(String appId) => '$appId.';

/// Opens [SharedPreferences] under [prefix] (plugin default prefix when null, as on Android).
/// The prefix must be set before the first `getInstance`, so this is the only place that opens
/// preferences.
Future<SharedPreferences> openPreferences({String? prefix}) async {
  if (prefix != null) SharedPreferences.setPrefix(prefix);
  return SharedPreferences.getInstance();
}
