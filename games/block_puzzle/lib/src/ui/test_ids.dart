import 'package:flutter/widgets.dart';

/// Stable widget keys for tests and automation. Rule: every interactive widget and key
/// element gets an ID here; tests must find widgets by these keys, never by text or position.
abstract final class TestIds {
  // Home
  static const homePlay = Key('home.play');
  static const homeDailyReward = Key('home.dailyReward');
  static const homeChallenges = Key('home.challenges');
  static const homeShop = Key('home.shop');
  static const gamePauseResume = Key('game.pause.resume');
  static const gamePauseQuit = Key('game.pause.quit');
  static const resumeDialog = Key('home.resume.dialog');
  static const resumeGame = Key('home.resume.resume');
  static const resumeNewGame = Key('home.resume.new');
  static const gameItemDescription = Key('game.item.description');
  static const gameOverRemoveAds = Key('game.over.removeAds');
  static const homeSettings = Key('home.settings');
  static const homeCoins = Key('home.coins');
  static const homeBestScore = Key('home.bestScore');
  static const homeStreak = Key('home.streak');
  static const homeHero = Key('home.hero');

  // Game
  static const gameWidget = Key('game.widget');
  static const gameScore = Key('game.score');
  static const gameScoreLabel = Key('game.score_label');
  static const gameBest = Key('game.best');
  static const gameBack = Key('game.back');
  static const gameOverDialog = Key('game.over.dialog');
  static const gameOverRevive = Key('game.over.revive');
  static const gateDialog = Key('gate.dialog');
  static const gateAnswer = Key('gate.answer');
  static const gateSubmit = Key('gate.submit');
  static const gateCancel = Key('gate.cancel');
  static const gameOverRevivesLeft = Key('game.over.revivesLeft');
  static const gameOverRetry = Key('game.over.retry');
  static const gameOverHome = Key('game.over.home');
  static const gameOverShare = Key('game.over.share');
  static const gameOverBestMove = Key('game.over.bestMove');
  static const bestMoveDialog = Key('bestMove.dialog');
  static const bestMoveBoard = Key('bestMove.board');
  static const bestMoveNext = Key('bestMove.next');
  static const gameOverPanel = Key('game.over.panel');
  static const gameOverView = Key('game.over.view');
  static const gameBanner = Key('game.banner');
  static const gameStreak = Key('game.streak');
  static const gameCombo = Key('game.combo');
  static const gameRush = Key('game.rush');

  // Boosts (`<id>` is blast, shuffle, undo, sweep, hammer)
  static Key gameItem(String id) => Key('game.item.$id');
  static Key gameItemCount(String id) => Key('game.item.$id.count');
  static const gameItemRow = Key('game.item.row');
  static const gameItemChip = Key('game.item.chip');
  static const gameItemCancel = Key('game.item.cancel');
  static const gameItemTarget = Key('game.item.target');
  static const gameItemSheet = Key('game.item.sheet');
  static const gameItemRefillCoins = Key('game.item.refill.coins');
  static const gameItemRefillAd = Key('game.item.refill.ad');
  static const gameItemRefillShop = Key('game.item.refill.shop');

  /// Invisible; its Semantics value is the id of the current theme.
  static const gameTheme = Key('game.theme');

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
  static const shopBoosts = Key('shop.boosts');
  static Key shopItemBuy(String id) => Key('shop.item.$id.buy');
  static Key shopItemCount(String id) => Key('shop.item.$id.count');

  // Settings
  static const settingsSound = Key('settings.sound');
  static const settingsVibration = Key('settings.vibration');
  static const settingsReminders = Key('settings.reminders');
  static const settingsPrivacy = Key('settings.privacy');
  static const settingsPlayGames = Key('settings.playGames');
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

  // Tips: one dialog on the home page, never in a game
  static const tipHome = Key('tip.home');
  static const tipClose = Key('tip.close');
  static const tipDontShow = Key('tip.dontShow');
}
