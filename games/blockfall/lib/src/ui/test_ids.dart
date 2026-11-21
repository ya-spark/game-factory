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
  static const homeHero = Key('home.hero');
  static const homeBanner = Key('home.banner'); // Home only

  // Game (spec section 7)
  static const gameWidget = Key('game.widget');
  static const gameWell = Key('game.well');
  static const gameScore = Key('game.score');
  static const gameScoreLabel = Key('game.score_label');
  static const gameBestText = Key('game.best_text');
  static const gameBest = Key('game.best');
  static const gameLevel = Key('game.level');

  /// Invisible; its Semantics value is the id of the current theme.
  static const gameTheme = Key('game.theme');
  static const gameGoal = Key('game.goal');
  static const gameHold = Key('game.hold');
  static const gameHoldPiece = Key('game.holdPiece');
  static Key gameNext(int i) => Key('game.next.$i');
  static const gameCombo = Key('game.combo');
  static const gameRush = Key('game.rush');
  static const gamePause = Key('game.pause');
  static const gameBack = Key('game.back');
  static const gameBanner = Key('game.banner'); // must stay absent in play
  static const gameStreak = Key('game.streak');
  static const gamePowerUpSweep = Key('game.powerup.sweep');
  static const gamePowerUpSlow = Key('game.powerup.slow');
  static const gamePowerUpBomb = Key('game.powerup.bomb');
  static const gamePowerUpSweepCount = Key('game.powerup.sweep.count');
  static const gamePowerUpSlowCount = Key('game.powerup.slow.count');
  static const gamePowerUpBombCount = Key('game.powerup.bomb.count');
  static const gameRefillCoins = Key('game.refill.coins');
  static const gameRefillAd = Key('game.refill.ad');
  static const gameOverDialog = Key('game.over.dialog');
  static const gameOverRevive = Key('game.over.revive');
  static const gameOverRetry = Key('game.over.retry');
  static const gameOverHome = Key('game.over.home');
  static const gameOverShare = Key('game.over.share');
  static const gameOverScore = Key('game.over.score');
  static const gameOverPanel = Key('game.over.panel');
  static const gameOverView = Key('game.over.view');
  static const gamePauseResume = Key('game.pause.resume');
  static const gamePauseQuit = Key('game.pause.quit');
  // On-screen controls (Buttons scheme)
  static const gameCtlLeft = Key('game.ctl.left');
  static const gameCtlRight = Key('game.ctl.right');
  static const gameCtlRotate = Key('game.ctl.rotate');
  static const gameCtlSoftDrop = Key('game.ctl.softDrop');
  static const gameCtlHardDrop = Key('game.ctl.hardDrop');

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

  // Parent gate (before real-money purchases)
  static const gateDialog = Key('gate.dialog');
  static const gateAnswer = Key('gate.answer');
  static const gateSubmit = Key('gate.submit');
  static const gateCancel = Key('gate.cancel');

  // Settings
  static const settingsSound = Key('settings.sound');
  static const settingsVibration = Key('settings.vibration');
  static const settingsReminders = Key('settings.reminders');
  static const settingsPrivacy = Key('settings.privacy');
  static const settingsPlayGames = Key('settings.playGames');
  static const settingsControls = Key('settings.controls');
  static const settingsGhost = Key('settings.ghost');
  static const settingsVolume = Key('settings.volume');
  static const settingsAmbience = Key('settings.ambience');
  static const settingsAmbiencePreview = Key('settings.ambience.preview');
  static const settingsVoice = Key('settings.voice');
  static const settingsHand = Key('settings.hand');
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
