import 'package:shared_preferences/shared_preferences.dart';

import 'rules/parcel_train_rules.dart';

/// What Parcel train keeps on the device (the game's own prefs; the web's localStorage in the browser).
///
/// - `arcade.parcel_train.best`: the Free ride best score (the Games tab best and stars come from it only).
/// - `arcade.parcel_train.wrap`: the Free ride "tunnel edges" setting.
/// - `arcade.parcel_train.courses`: best stars of the five courses (list of five numbers 0 to 3).
/// - `arcade.parcel_train.courseBest`: best score of each course (coins are paid on the difference).
///
/// The old keys of the game when it was called Snake (`arcade.snake.best`, `arcade.snake.wrap`) are moved
/// to the new ones once ([migrate]; the web build also moves `amc.best.snake` by `renamedGameIds`).
class TrainProgress {
  TrainProgress(this._p);
  final SharedPreferences _p;

  static const String bestKey = 'arcade.parcel_train.best';
  static const String wrapKey = 'arcade.parcel_train.wrap';
  static const String coursesKey = 'arcade.parcel_train.courses';
  static const String courseBestKey = 'arcade.parcel_train.courseBest';

  /// Moves the keys saved under the old id to the new id. The higher best wins; the old keys are removed.
  static Future<void> migrate(
    SharedPreferences p, {
    String oldId = 'snake',
  }) async {
    final oldBest = p.getInt('arcade.$oldId.best');
    if (oldBest != null) {
      final cur = p.getInt(bestKey) ?? 0;
      await p.setInt(bestKey, oldBest > cur ? oldBest : cur);
      await p.remove('arcade.$oldId.best');
    }
    final oldWrap = p.getBool('arcade.$oldId.wrap');
    if (oldWrap != null) {
      if (!p.containsKey(wrapKey)) await p.setBool(wrapKey, oldWrap);
      await p.remove('arcade.$oldId.wrap');
    }
  }

  int get best => _p.getInt(bestKey) ?? 0;
  bool get wrap => _p.getBool(wrapKey) ?? false;

  List<int> _list(String key) {
    final raw = _p.getStringList(key) ?? const <String>[];
    return [
      for (var i = 0; i < trainCourseCount; i++)
        i < raw.length ? (int.tryParse(raw[i]) ?? 0) : 0,
    ];
  }

  List<int> get stars => _list(coursesKey);
  List<int> get courseBest => _list(courseBestKey);

  Future<void> setWrap(bool v) => _p.setBool(wrapKey, v);

  Future<void> setBest(int v) => _p.setInt(bestKey, v);

  /// Records a course arrival: keeps the higher stars and score.
  Future<void> recordCourse(int index, int stars, int score) async {
    final s = this.stars;
    final b = courseBest;
    if (stars > s[index]) s[index] = stars;
    if (score > b[index]) b[index] = score;
    await _p.setStringList(coursesKey, [for (final v in s) '$v']);
    await _p.setStringList(courseBestKey, [for (final v in b) '$v']);
  }
}
