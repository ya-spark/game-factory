import 'package:flutter/widgets.dart';

/// Stable widget keys for tests and automation. Rule: every interactive widget and key
/// element gets an ID here; tests must find widgets by these keys, never by text or position.
abstract final class TestIds {
  // Profile picker (who is playing)
  static Key pickerChild(String id) => Key('picker.child.$id');
  static const pickerAdd = Key('picker.add');
  static const pickerParent = Key('picker.parent');
  static const pickerNickname = Key('picker.nickname');
  static Key pickerAvatar(String id) => Key('picker.avatar.$id');
  static Key pickerYear(int y) => Key('picker.year.$y');
  static const pickerSave = Key('picker.save');

  // Parent area (behind the gate)
  static const parentArea = Key('parent.area');
  static Key parentChild(String id) => Key('parent.child.$id');
  static const parentYear = Key('parent.year');
  static Key parentYearOption(int y) => Key('parent.year.$y');
  static const parentLockNone = Key('parent.lock.none');
  static const parentLockGame = Key('parent.lock.game');
  static const parentLockStudy = Key('parent.lock.study');
  static const parentReport = Key('parent.report');
  static const parentDelete = Key('parent.delete');
  static const parentDeleteConfirm = Key('parent.delete.confirm');
  static const parentWifiOnly = Key('parent.wifiOnly');
  static const parentAllYears = Key('parent.allYears');
  static const parentBuyFull = Key('parent.buy.full');
  static const parentRestore = Key('parent.restore');
  static Key parentPackPreview(String id) => Key('parent.pack.preview.$id');
  static Key parentBundleBuy(String id) => Key('parent.bundle.buy.$id');
  static Key parentPackBuy(String id) => Key('parent.pack.buy.$id');
  static Key parentPackDownload(String id) => Key('parent.pack.download.$id');
  static const parentMobileConfirm = Key('parent.mobile.confirm');
  static const parentMobileCancel = Key('parent.mobile.cancel');

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
  static const gameBanner = Key(
    'game.banner',
  ); // post_game banner (game-over panel)
  static const menuBanner = Key('menu.banner');
  static const quizSpeak = Key('quiz.speak');
  static const quizSpeakOptions = Key('quiz.speakOptions');
  static const quizSpeakExplanation = Key('quiz.speakExplanation');
  static const gameStreak = Key('game.streak');
  static const gameCombo = Key('game.combo');
  static const gameRush = Key('game.rush');

  // Daily reward
  static const dailyClaim = Key('daily.claim');
  static const dailyStreak = Key('daily.streak');
  static Key dailyDay(int i) => Key('daily.day.$i');

  // Challenges / achievements
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

  // Quick quiz (minigame framework)
  static const quizScreen = Key('quiz.screen');
  static const quizPrompt = Key('quiz.prompt');
  static const quizProgress = Key('quiz.progress');
  static const quizCheck = Key('quiz.check');
  static const quizNext = Key('quiz.next');
  static const quizExit = Key('quiz.exit');
  static const quizFeedback = Key('quiz.feedback');
  static const quizExplanation = Key('quiz.explanation');
  static const quizStars = Key('quiz.stars');
  static const quizSummary = Key('quiz.summary');
  static Key quizOption(int i) => Key('quiz.option.$i');

  // Shared minigames (door runner, balloon pop); [g] is the game id.
  static Key mgScreen(String g) => Key('$g.screen');
  static Key mgIntro(String g) => Key('$g.intro');
  static Key mgStart(String g) => Key('$g.start');
  static Key mgExit(String g) => Key('$g.exit');
  static Key mgPrompt(String g) => Key('$g.prompt');
  static Key mgProgress(String g) => Key('$g.progress');
  static Key mgScore(String g) => Key('$g.score');
  static Key mgSpeak(String g) => Key('$g.speak');
  static Key mgTimer(String g) => Key('$g.timer');
  static Key mgField(String g) => Key('$g.field');
  static Key mgChoice(String g, int i) => Key('$g.choice.$i');
  static Key mgFeedback(String g) => Key('$g.feedback');
  static Key mgNext(String g) => Key('$g.next');
  static Key mgResults(String g) => Key('$g.results');
  static Key mgStars(String g) => Key('$g.stars');
  static Key mgDone(String g) => Key('$g.done');
  static Key mgBanner(String g) => Key('$g.banner');
  // Tug-of-war and flash review.
  static Key mgRope(String g) => Key('$g.rope');
  static Key mgCard(String g) => Key('$g.card');
  static Key mgFlip(String g) => Key('$g.flip');
  static Key mgKnew(String g) => Key('$g.knew');
  static Key mgNotYet(String g) => Key('$g.not_yet');

  // Memory match
  static const matchScreen = Key('match.screen');
  static const matchExit = Key('match.exit');
  static const matchProgress = Key('match.progress');
  static const matchPrompt = Key('match.prompt');
  static const matchSpeak = Key('match.speak');
  static const matchTimer = Key('match.timer');
  static const matchNext = Key('match.next');
  static const matchFeedback = Key('match.feedback');
  static const matchSummary = Key('match.summary');
  static const matchStars = Key('match.stars');
  static Key matchCard(int i) => Key('match.card.$i');

  // Sort into bins
  static const sortScreen = Key('sort.screen');
  static const sortExit = Key('sort.exit');
  static const sortProgress = Key('sort.progress');
  static const sortPrompt = Key('sort.prompt');
  static const sortSpeak = Key('sort.speak');
  static const sortTimer = Key('sort.timer');
  static const sortItem = Key('sort.item');
  static const sortNext = Key('sort.next');
  static const sortFeedback = Key('sort.feedback');
  static const sortSummary = Key('sort.summary');
  static const sortStars = Key('sort.stars');
  static Key sortBin(int i) => Key('sort.bin.$i');

  // Minigame menu
  static Key miniGameCard(String id) => Key('minigame.card.$id');
  static Key miniGameUnlock(String id) => Key('minigame.unlock.$id');

  // Tips: one dialog on the home page, never in a game
  static const tipHome = Key('tip.home');
  static const tipClose = Key('tip.close');
  static const tipDontShow = Key('tip.dontShow');

  // Design system kit (lib/ui/kit/). Every shared widget takes an `id` and keys itself
  // `ds.<kind>.<id>`; use these builders in tests.
  static Key dsButton(String id) => Key('ds.button.$id');
  static Key dsCoinChip(String id) => Key('ds.coinChip.$id');
  static Key dsStatChip(String id) => Key('ds.statChip.$id');
  static Key dsTopBar(String id) => Key('ds.topBar.$id');
  static Key dsBottomBar(String id) => Key('ds.bottomBar.$id');
  static Key dsTab(String barId, String tabId) => Key('ds.tab.$barId.$tabId');
  static Key dsCard(String id) => Key('ds.card.$id');
  static Key dsProgress(String id) => Key('ds.progress.$id');
  static Key dsMasteryChip(String id) => Key('ds.masteryChip.$id');
  static Key dsGameTile(String id) => Key('ds.gameTile.$id');
  static Key dsTopicCard(String id) => Key('ds.topicCard.$id');
  static Key dsPackCard(String id) => Key('ds.packCard.$id');
  static Key dsSuggestedCard(String id) => Key('ds.suggestedCard.$id');
  static Key dsHero(String id) => Key('ds.hero.$id');
  static Key dsDialog(String id) => Key('ds.dialog.$id');
  static Key dsDialogAction(String id, String action) =>
      Key('ds.dialog.$id.$action');

  // Mode system and app shell (issue 2B1)
  static const modeToggle = Key('mode.toggle');
  static const modeGame = Key('mode.game');
  static const modeStudy = Key('mode.study');
  static const modeLock = Key('mode.lock');
  static const shell = Key('shell.screen');
  static const shellBottomBar =
      'shell'; // id of the bottom bar: `dsTab('shell', tabId)`
  static const playTab = Key('tab.play');
  static const challengesTab = Key('tab.challenges');
  static const shopTab = Key('tab.shop');
  static const learnTab = Key('tab.learn');
  static const progressTab = Key('tab.progress');
  static const reviseTab = Key('tab.revise');
  static const learnGoal = Key('learn.goal');
  static Key progressTopic(String key) => Key('progress.topic.$key');
  static Key reviseTopic(String key) => Key('revise.topic.$key');
  static const playTryNext = Key('play.tryNext');
  static const playDaily = Key('play.daily');
  static const playHero = Key('play.hero');
  static Key playGame(String id) => Key('play.game.$id');
  static Key challengeClaim(String id) => Key('challenge.claim.$id');
  static Key challengeGoal(String id) => Key('challenge.goal.$id');
  static Key shopAvatar(String id) => Key('shop.avatar.$id');
  static Key shopTheme(String id) => Key('shop.theme.$id');
  static Key shopGame(String id) => Key('shop.game.$id');
  static const shopParentArea = Key('shop.parentArea');

  // Theme gallery (debug only)
  static const themeGallery = Key('gallery.theme');
  static const settingsThemeGallery = Key('settings.themeGallery');
  static Key galleryMode(String mode) => Key('gallery.mode.$mode');
  static const galleryLargeText = Key('gallery.largeText');
  static const galleryReduceMotion = Key('gallery.reduceMotion');
}
