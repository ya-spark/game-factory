import 'package:flutter/widgets.dart';

/// Stable widget keys for tests and automation. Rule: every interactive widget and key
/// element gets an ID here; tests must find widgets by these keys, never by text or position.
abstract final class TestIds {
  // Home
  static const homePlay = Key('home.play');
  static const homeDailyReward = Key('home.dailyReward');
  static const homeChallenges = Key('home.challenges');
  static const homeShop = Key('home.shop');
  static const homeSettings = Key('home.settings');
  static const homeCoins = Key('home.coins');
  static const homeBestScore = Key('home.bestScore');
  static const homeStreak = Key('home.streak');

  // Game
  static const gameWidget = Key('game.widget');
  static const gameScore = Key('game.score');
  static const gameBest = Key('game.best');
  static const gameBack = Key('game.back');
  static const gameOverDialog = Key('game.over.dialog');
  static const gameOverRevive = Key('game.over.revive');
  static const gameOverShare = Key('game.over.share');
  static const gameOverPanel = Key('game.over.panel');
  static const gameOverView = Key('game.over.view');

  // Parent gate (before every real-money purchase)
  static const gateDialog = Key('gate.dialog');
  static const gateAnswer = Key('gate.answer');
  static const gateSubmit = Key('gate.submit');
  static const gateCancel = Key('gate.cancel');
  static const gameOverRevivesLeft = Key('game.over.revivesLeft');
  static const gameOverRetry = Key('game.over.retry');
  static const gameOverHome = Key('game.over.home');
  static const gameBanner = Key('game.banner');
  static const gameStreak = Key('game.streak');
  static const gameCombo = Key('game.combo');
  static const gameRush = Key('game.rush');

  // Daily reward
  static const dailyClaim = Key('daily.claim');
  static const dailyStreak = Key('daily.streak');
  static Key dailyDay(int i) => Key('daily.day.$i');

  // Challenges / achievements
  static Key challengeClaim(String id) => Key('challenge.claim.$id');
  static Key challengeTile(int i) => Key('challenge.tile.$i');
  static Key achievementTile(String id) => Key('achievement.$id');
  static Key achievementShare(String id) => Key('achievement.share.$id');

  // Shop
  static const shopRestore = Key('shop.restore');
  static const shopUnavailable = Key('shop.unavailable');
  static Key shopBuy(String productId) => Key('shop.buy.$productId');

  // Settings
  static const settingsSound = Key('settings.sound');
  static const settingsVibration = Key('settings.vibration');
  static const settingsReminders = Key('settings.reminders');
  static const settingsPrivacy = Key('settings.privacy');
  static const settingsPlayGames = Key('settings.playGames');
  static const settingsVolume = Key('settings.volume');
  static const settingsAmbience = Key('settings.ambience');
  static const settingsVoice = Key('settings.voice');
  static const settingsHand = Key('settings.hand');
  static const settingsTips = Key('settings.tips');
  static const settingsShareApp = Key('settings.shareApp');

  // More games
  static const homeMoreGames = Key('home.moreGames');
  static const settingsMoreGames = Key('settings.moreGames');
  static const moreGamesScreen = Key('moreGames.screen');
  static const moreGamesBack = Key('moreGames.back');
  static Key moreGamesCard(String id) => Key('moreGames.card.$id');
  static Key moreGamesGet(String id) => Key('moreGames.get.$id');

  // Tips: one dialog on the home page, never in a game
  static const tipHome = Key('tip.home');
  static const tipClose = Key('tip.close');
  static const tipDontShow = Key('tip.dontShow');
}
