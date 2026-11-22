import 'package:shared_preferences/shared_preferences.dart';

import 'rules/dash_rules.dart';

/// What Wind-up dash keeps on the device (the game's own prefs; the web's localStorage in the browser).
///
/// - `arcade.wind_up_dash.best`: the free run best score (the Games tab best and stars come from it only).
/// - `arcade.wind_up_dash.courses`: best stars of the five courses (list of five numbers 0 to 3).
/// - `arcade.wind_up_dash.courseBest`: best score of each course (coins are paid on the difference).
///
/// The old key of the game when it was called Runner (`arcade.runner.best`) is moved to the new one once
/// ([migrate]; the web build also moves `amc.best.runner` by `renamedGameIds`).
class DashProgress {
  DashProgress(this._p);
  final SharedPreferences _p;

  static const String bestKey = 'arcade.wind_up_dash.best';
  static const String coursesKey = 'arcade.wind_up_dash.courses';
  static const String courseBestKey = 'arcade.wind_up_dash.courseBest';

  /// Moves the key saved under the old id to the new id. The higher best wins; the old key is removed.
  static Future<void> migrate(
    SharedPreferences p, {
    String oldId = 'runner',
  }) async {
    final oldBest = p.getInt('arcade.$oldId.best');
    if (oldBest != null) {
      final cur = p.getInt(bestKey) ?? 0;
      await p.setInt(bestKey, oldBest > cur ? oldBest : cur);
      await p.remove('arcade.$oldId.best');
    }
  }

  int get best => _p.getInt(bestKey) ?? 0;

  List<int> _list(String key) {
    final raw = _p.getStringList(key) ?? const <String>[];
    return [
      for (var i = 0; i < dashCourseCount; i++)
        i < raw.length ? (int.tryParse(raw[i]) ?? 0) : 0,
    ];
  }

  List<int> get stars => _list(coursesKey);
  List<int> get courseBest => _list(courseBestKey);

  Future<void> setBest(int v) => _p.setInt(bestKey, v);

  /// Records a course finish: keeps the higher stars and score.
  Future<void> recordCourse(int index, int stars, int score) async {
    final s = this.stars;
    final b = courseBest;
    if (stars > s[index]) s[index] = stars;
    if (score > b[index]) b[index] = score;
    await _p.setStringList(coursesKey, [for (final v in s) '$v']);
    await _p.setStringList(courseBestKey, [for (final v in b) '$v']);
  }
}
