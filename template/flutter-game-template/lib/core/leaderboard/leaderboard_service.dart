import 'package:games_services/games_services.dart';
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

/// Play Games leaderboards + achievements. Every write also goes to the local fallback, so
/// [bestScore] works offline and when the player is not signed in; Play calls are best-effort.
class PlayGamesLeaderboardService implements LeaderboardService {
  PlayGamesLeaderboardService(this._fallback);
  final LeaderboardService _fallback;

  @override
  bool get isStub => false;

  @override
  Future<void> submitScore(String id, int score) async {
    await _fallback.submitScore(id, score);
    try {
      await GamesServices.submitScore(
        score: Score(androidLeaderboardID: id, value: score),
      );
    } on Object {
      // Not signed in / offline.
    }
  }

  @override
  Future<int> bestScore(String id) => _fallback.bestScore(id);

  @override
  Future<void> unlockAchievement(String id) async {
    await _fallback.unlockAchievement(id);
    try {
      await GamesServices.unlock(achievement: Achievement(androidID: id));
    } on Object {
      // Not signed in / offline.
    }
  }

  @override
  Future<bool> showLeaderboard(String id) async {
    try {
      if (!await GamesServices.isSignedIn) return false;
      await GamesServices.showLeaderboards(androidLeaderboardID: id);
      return true;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> showAchievements() async {
    try {
      if (!await GamesServices.isSignedIn) return false;
      await GamesServices.showAchievements();
      return true;
    } on Object {
      return false;
    }
  }
}
