import 'package:games_services/games_services.dart';

import 'leaderboard_service.dart';

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
