import 'package:shared_preferences/shared_preferences.dart';

/// Leaderboards and (Play Games) achievements. Falls back to local-only behaviour.
abstract interface class LeaderboardService {
  bool get isStub;

  Future<void> submitScore(String leaderboardId, int score);

  /// Best locally known score for [leaderboardId].
  Future<int> bestScore(String leaderboardId);

  Future<void> unlockAchievement(String achievementId);

  /// Opens the platform leaderboard UI; returns false when none is available (local fallback).
  Future<bool> showLeaderboard(String leaderboardId);
  Future<bool> showAchievements();
}

class LocalLeaderboardService implements LeaderboardService {
  LocalLeaderboardService(this._prefs);
  final SharedPreferences _prefs;

  @override
  bool get isStub => false;

  @override
  Future<void> submitScore(String leaderboardId, int score) async {
    final key = 'lb.$leaderboardId';
    if (score > (_prefs.getInt(key) ?? 0)) await _prefs.setInt(key, score);
  }

  @override
  Future<int> bestScore(String leaderboardId) async =>
      _prefs.getInt('lb.$leaderboardId') ?? 0;

  @override
  Future<void> unlockAchievement(String achievementId) async {
    await _prefs.setBool('ach.$achievementId', true);
  }

  @override
  Future<bool> showLeaderboard(String leaderboardId) async => false;
  @override
  Future<bool> showAchievements() async => false;
}

// ---------------------------------------------------------------------------
// STUB: Google Play Games leaderboards + achievements.
// Not implemented in v1: every call is forwarded to the local fallback and the
// "show" calls report false (UI then shows its local screen). Implement with a Play
// Games plugin inside this class only.
// ---------------------------------------------------------------------------
class PlayGamesLeaderboardStub implements LeaderboardService {
  PlayGamesLeaderboardStub(this._fallback);
  final LeaderboardService _fallback;

  @override
  bool get isStub => true;
  @override
  Future<void> submitScore(String id, int score) =>
      _fallback.submitScore(id, score);
  @override
  Future<int> bestScore(String id) => _fallback.bestScore(id);
  @override
  Future<void> unlockAchievement(String id) => _fallback.unlockAchievement(id);
  @override
  Future<bool> showLeaderboard(String id) async => false;
  @override
  Future<bool> showAchievements() async => false;
}
