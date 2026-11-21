import 'package:flutter/widgets.dart';

/// Stable widget keys for tests and automation. Rule: every interactive widget and key
/// element gets an ID here; tests must find widgets by these keys, never by text or position.
abstract final class TestIds {
  // Home
  static const homePlay = Key('home.play');
  static const homeDailyReward = Key('home.dailyReward');
  static const homeChallenges = Key('home.challenges');
  static const homeShop = Key('home.shop');
  static const resumeDialog = Key('home.resume.dialog');
  static const resumeGame = Key('home.resume.resume');
  static const resumeNewGame = Key('home.resume.new');
  static const gameRefillDescription = Key('game.refill.description');
  static const gameOverRemoveAds = Key('game.over.removeAds');
  static const homeSettings = Key('home.settings');
  static const homeCoins = Key('home.coins');
  static const homeBestScore = Key('home.bestScore');
  static const homeStreak = Key('home.streak');
  static const homeBanner = Key('home.banner');
  static const homeHero = Key('home.hero');

  // Game
  static const gameWidget = Key('game.widget');
  static const gameField = Key('game.field');
  static const gameReady = Key('game.ready');
  static const gameScore = Key('game.score');
  static const gameBest = Key('game.best');
  static const gameStreak = Key('game.streak');
  static const gameMeter = Key('game.meter');
  static const gameDash = Key('game.dash');
  static const gameDashState = Key('game.dash.state');
  static const gamePause = Key('game.pause');
  static const gameBack = Key('game.back');
  static const gameCountdown = Key('game.countdown');

  // Game over
  static const gameOverDialog = Key('game.over.dialog');
  static const gameOverScore = Key('game.over.score');
  static const gameOverBest = Key('game.over.best');
  static const gameOverMedal = Key('game.over.medal');
  static const gameOverRevive = Key('game.over.revive');
  static const gameOverRefill = Key('game.over.refill');
  static const gameOverRetry = Key('game.over.retry');
  static const gameOverHome = Key('game.over.home');
  static const gameOverShare = Key('game.over.share');
  static const gameOverPanel = Key('game.over.panel');
  static const gameOverView = Key('game.over.view');

  // Pause dialog
  static const gamePauseResume = Key('game.pause.resume');
  static const gamePauseQuit = Key('game.pause.quit');

  // Dash Refill sheet
  static const gameRefillSheet = Key('game.refill.sheet');
  static const gameRefillCoins = Key('game.refill.coins');
  static const gameRefillAd = Key('game.refill.ad');

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
  static const shopBuyRefill = Key('shop.buy.dash_refill');
  static const shopBuyFreeze = Key('shop.buy.streak_freeze');

  static Key shopSkin(String id) => Key('shop.skin.$id');
  static Key shopSkinBuy(String id) => Key('shop.skin.$id.buy');
  static Key shopSkinEquip(String id) => Key('shop.skin.$id.equip');

  // Parent gate
  static const gateDialog = Key('gate.dialog');
  static const gateAnswer = Key('gate.answer');
  static const gateSubmit = Key('gate.submit');
  static const gateCancel = Key('gate.cancel');

  // Settings
  static const settingsSound = Key('settings.sound');
  static const settingsVolume = Key('settings.volume');
  static const settingsAmbience = Key('settings.ambience');
  static const settingsAmbiencePreview = Key('settings.ambience.preview');
  static const settingsVoice = Key('settings.voice');
  static const settingsSfx = Key('settings.sfx');
  static const settingsHand = Key('settings.hand');
  static const settingsHaptics = Key('settings.haptics');
  static const settingsReduceMotion = Key('settings.reduceMotion');
  static const settingsReminders = Key('settings.reminders');
  static const settingsPrivacy = Key('settings.privacy');
  static const settingsPlayGames = Key('settings.playGames');
  // More games
  static const homeMoreGames = Key('home.moreGames');
  static const settingsMoreGames = Key('settings.moreGames');
  static const moreGamesScreen = Key('moreGames.screen');
  static const moreGamesBack = Key('moreGames.back');
  static Key moreGamesCard(String id) => Key('moreGames.card.$id');
  static Key moreGamesGet(String id) => Key('moreGames.get.$id');

  static const settingsTips = Key('settings.tips');
  static const settingsShareApp = Key('settings.shareApp');

  // Tips
  static const tipHome = Key('tip.home');
  static const tipClose = Key('tip.close');
  static const tipDontShow = Key('tip.dontShow');
}
