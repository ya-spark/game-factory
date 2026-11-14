import 'package:flutter/foundation.dart';

import '../../engine/engine.dart';
import 'child_profile.dart';
import '../clock.dart';
import '../config/app_config.dart';
import '../config/products.dart';
import '../purchase/purchase_service.dart';
import '../retention/achievements.dart';
import '../retention/game_challenges.dart';
import '../retention/daily_challenges.dart';
import '../retention/daily_reward.dart';
import '../retention/streaks.dart';
import '../save/save_data.dart';
import '../save/save_service.dart';

/// Result of one finished game, fed into stats / challenges / achievements.
class GameSummary {
  const GameSummary({
    required this.score,
    required this.linesCleared,
    required this.piecesPlaced,
    required this.maxCombo,
  });
  final int score;
  final int linesCleared;
  final int piecesPlaced;
  final int maxCombo;
}

/// Holds the player's [SaveData], applies the retention engines and persists every change.
/// UI listens to it; game rules never touch it.
class ProfileStore extends ChangeNotifier {
  ProfileStore({
    required this._saves,
    required this.retention,
    this.cappedRewards,
    Clock? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Set in the Craft apps: coins from the daily reward and the daily challenges count against
  /// the active child's weekly coin cap (`RewardsEngine.grantCapped`). Null: paid in full.
  final RewardsConfig? cappedRewards;

  final SaveService _saves;
  final RetentionConfig retention;
  final Clock _clock;
  static const ClockGuard _guard = ClockGuard();

  SaveData _data = const SaveData();
  SaveData get data => _data;

  /// Device clock is behind the latest time we saw (the player moved it back).
  bool clockTampered = false;

  /// Time used for all date logic: never earlier than the latest time ever seen.
  DateTime get trustedNow => _guard.trusted(_clock(), _data.lastSeenMs);
  int get today => dayIndexOf(trustedNow);

  Future<void> init() async {
    _data = await _saves.load();
    await _tick();
  }

  /// Re-reads the save (local vs cloud, newer wins). Call after the player signs in to Play Games.
  Future<void> reload() async {
    _data = await _saves.load();
    await _tick();
  }

  /// Call on app start and on resume: refreshes the day, streak and today's challenges.
  Future<void> onAppOpened() => _tick();

  Future<void> _tick() async {
    final raw = _clock();
    clockTampered = _guard.isTampered(raw, _data.lastSeenMs);
    final now = _guard.trusted(raw, _data.lastSeenMs);
    final day = dayIndexOf(now);
    var d = _data.copyWith(lastSeenMs: now.millisecondsSinceEpoch);
    if (retention.streaks) {
      final u = StreakEngine.recordActivity(d.streak, day);
      d = d.copyWith(
        streak: u.state,
        stats: d.stats.copyWith(
          bestStreak: u.state.best > d.stats.bestStreak ? u.state.best : null,
        ),
      );
    }
    if (retention.dailyChallenges) {
      d = d.copyWith(
        challenges: retention.gameChallenges
            ? GameChallengeEngine.ensureToday(
                d.challenges,
                day,
                StreakEngine.displayStreak(d.streak, day),
              )
            : DailyChallengeEngine.ensureToday(d.challenges, day),
      );
    }
    d = _unlockAchievements(d).data;
    await _commit(d);
  }

  Future<void> _commit(SaveData d) async {
    _data = d;
    notifyListeners();
    await _saves.save(d);
  }

  // ---- daily reward -------------------------------------------------------

  bool get dailyRewardAvailable =>
      retention.dailyReward &&
      DailyRewardEngine.canClaim(_data.dailyReward, today);

  int get dailyRewardDayToClaim =>
      DailyRewardEngine.dayToClaim(_data.dailyReward, today);

  /// Claims today's reward; returns coins granted or null if unavailable.
  Future<int?> claimDailyReward() async {
    if (!retention.dailyReward) return null;
    final c = DailyRewardEngine.claim(_data.dailyReward, today);
    if (c == null) return null;
    final paid = _capped(c.coins);
    await _commit(
      _withCappedChild(
        _data.copyWith(dailyReward: c.state, coins: _data.coins + paid.coins),
        paid.rewards,
      ),
    );
    return paid.coins;
  }

  /// [wanted] coins cut to the active child's weekly cap, when the cap applies.
  ({int coins, RewardState? rewards}) _capped(int wanted) {
    final cfg = cappedRewards;
    final child = activeChild;
    if (cfg == null || child == null) return (coins: wanted, rewards: null);
    final g = RewardsEngine.grantCapped(
      child.progress.rewards,
      wanted,
      today,
      cfg,
    );
    return (coins: g.coins, rewards: g.state);
  }

  SaveData _withCappedChild(SaveData d, RewardState? rewards) {
    final id = _activeId;
    if (rewards == null || id == null) return d;
    return d.copyWith(
      profiles: [
        for (final p in d.profiles)
          if (p.id == id)
            p.copyWith(progress: p.progress.copyWith(rewards: rewards))
          else
            p,
      ],
    );
  }

  // ---- streak -------------------------------------------------------------

  int get displayStreak => StreakEngine.displayStreak(_data.streak, today);

  // ---- challenges ---------------------------------------------------------

  List<Challenge> get challenges =>
      retention.dailyChallenges ? _data.challenges.challenges : const [];

  Future<int?> claimChallenge(String id) async {
    final r = DailyChallengeEngine.claim(_data.challenges, id);
    if (r == null) return null;
    final paid = _capped(r.coins);
    await _commit(
      _withCappedChild(
        _data.copyWith(challenges: r.state, coins: _data.coins + paid.coins),
        paid.rewards,
      ),
    );
    return paid.coins;
  }

  // ---- gameplay -----------------------------------------------------------

  /// A hub game reported a score (`retention.game_challenges`): feeds the game-based challenges.
  Future<void> recordGamePlayed(String gameId, int score) async {
    if (!retention.dailyChallenges || !retention.gameChallenges) return;
    final c = GameChallengeEngine.recordPlay(
      GameChallengeEngine.ensureToday(_data.challenges, today, displayStreak),
      gameId,
      score,
    );
    await _commit(_data.copyWith(challenges: c));
  }

  /// Records a finished game. Returns achievements unlocked by it.
  Future<List<AchievementDef>> recordGameFinished(GameSummary g) async {
    var d = _data;
    final stats = d.stats.copyWith(
      gamesPlayed: d.stats.gamesPlayed + 1,
      totalLines: d.stats.totalLines + g.linesCleared,
      piecesPlaced: d.stats.piecesPlaced + g.piecesPlaced,
      bestScore: g.score > d.stats.bestScore ? g.score : null,
      maxCombo: g.maxCombo > d.stats.maxCombo ? g.maxCombo : null,
    );
    d = d.copyWith(
      stats: stats,
      bestScore: g.score > d.bestScore ? g.score : null,
    );
    if (retention.dailyChallenges) {
      var c = DailyChallengeEngine.ensureToday(d.challenges, today);
      c = DailyChallengeEngine.record(c, ChallengeKind.playGames, 1);
      c = DailyChallengeEngine.record(c, ChallengeKind.scorePoints, g.score);
      c = DailyChallengeEngine.record(
        c,
        ChallengeKind.clearLines,
        g.linesCleared,
      );
      c = DailyChallengeEngine.record(
        c,
        ChallengeKind.placePieces,
        g.piecesPlaced,
      );
      c = DailyChallengeEngine.record(c, ChallengeKind.makeCombo, g.maxCombo);
      d = d.copyWith(challenges: c);
    }
    final r = _unlockAchievements(d);
    await _commit(r.data);
    return r.unlocked;
  }

  ({SaveData data, List<AchievementDef> unlocked}) _unlockAchievements(
    SaveData d,
  ) {
    if (!retention.achievements) return (data: d, unlocked: const []);
    final fresh = AchievementEngine.newlyUnlocked(
      d.stats,
      d.unlockedAchievements,
    );
    if (fresh.isEmpty) return (data: d, unlocked: const []);
    return (
      data: d.copyWith(
        unlockedAchievements: {
          ...d.unlockedAchievements,
          for (final a in fresh) a.id,
        },
        coins: d.coins + fresh.fold<int>(0, (s, a) => s + a.reward),
      ),
      unlocked: fresh,
    );
  }

  // ---- coins / settings ---------------------------------------------------

  Future<void> addCoins(int n) =>
      _commit(_data.copyWith(coins: _data.coins + n));

  bool isGameUnlocked(String gameId) => _data.unlockedGames.contains(gameId);

  /// Spends [price] coins to unlock a coin-locked minigame for good. False when the coins
  /// are not enough; an already unlocked game costs nothing.
  Future<bool> unlockGame(String gameId, int price) async {
    if (_data.unlockedGames.contains(gameId)) return true;
    if (_data.coins < price) return false;
    await _commit(
      _data.copyWith(
        coins: _data.coins - price,
        unlockedGames: {..._data.unlockedGames, gameId},
      ),
    );
    return true;
  }

  /// Free items are owned from the start; the rest once bought.
  bool ownsItem(ShopItem i) => i.price == 0 || _data.ownedItems.contains(i.id);

  /// Buys a shop item with coins. False when the coins are not enough; owned items cost nothing.
  Future<bool> buyItem(ShopItem i) async {
    if (ownsItem(i)) return true;
    if (_data.coins < i.price) return false;
    await _commit(
      _data.copyWith(
        coins: _data.coins - i.price,
        ownedItems: {..._data.ownedItems, i.id},
      ),
    );
    return true;
  }

  /// Uses an owned avatar or colour theme for a child. False when the child does not own it.
  Future<bool> equipItem(String childId, ShopItem i) async {
    if (!ownsItem(i)) return false;
    if (i.kind == ShopKind.sound) {
      // Sound packs are device-wide: using one sets the Music choice in Settings.
      await setAmbience(i.id);
      return true;
    }
    await _updateChild(
      childId,
      (p) => i.kind == ShopKind.avatar
          ? p.copyWith(avatar: i.id)
          : p.copyWith(colorTheme: i.id),
    );
    return true;
  }

  Future<bool> spendCoins(int n) async {
    if (_data.coins < n) return false;
    await _commit(_data.copyWith(coins: _data.coins - n));
    return true;
  }

  Future<void> setSound(bool v) => _commit(_data.copyWith(soundOn: v));
  Future<void> setMasterVolume(double v) =>
      _commit(_data.copyWith(masterVolume: v.clamp(0.0, 1.0)));
  Future<void> setAmbience(String id) => _commit(_data.copyWith(ambience: id));
  Future<void> setVoice(bool v) => _commit(_data.copyWith(voiceOn: v));
  Future<void> setLeftHanded(bool v) => _commit(_data.copyWith(leftHanded: v));
  Future<void> setVibration(bool v) => _commit(_data.copyWith(vibrationOn: v));
  Future<void> setReminders(bool v) => _commit(_data.copyWith(remindersOn: v));
  Future<void> setReminderTime(int hour, int minute) => _commit(
    _data.copyWith(
      reminderHour: hour.clamp(0, 23),
      reminderMinute: minute.clamp(0, 59),
    ),
  );
  Future<void> setTextSize(TextSizeChoice v) =>
      _commit(_data.copyWith(textSize: v.name));
  Future<void> setReduceMotion(bool v) =>
      _commit(_data.copyWith(reduceMotion: v));

  // ---- tips ---------------------------------------------------------------

  /// Tips on/off: the "Don't show tips again" checkbox and the settings switch share this.
  bool get tipsEnabled => !_data.tipsOff;
  bool get spacedReview => _data.spacedReview;
  Future<void> setSpacedReview(bool v) =>
      _commit(_data.copyWith(spacedReview: v));
  Future<void> setTipsEnabled(bool v) => _commit(_data.copyWith(tipsOff: !v));

  /// The home tip of the day has not been closed today.
  bool get homeTipPending => tipsEnabled && _data.tipHomeDay != today;
  Future<void> closeHomeTip() => _commit(_data.copyWith(tipHomeDay: today));

  // ---- purchases ----------------------------------------------------------

  /// Delivers a purchase/restore once. Replays of the same purchaseId are ignored;
  /// restores of non-consumables are idempotent by nature.
  Future<void> deliverPurchase(PurchaseUpdate u, ProductCatalog catalog) async {
    if (u.status != PurchaseStatus.purchased &&
        u.status != PurchaseStatus.restored) {
      return;
    }
    if (u.productId == ProductDef.legacyRemoveAdsId) {
      // Retired id: a restore (or old purchase) still unlocks the entitlement.
      if (!_data.adsRemoved) await _commit(_data.copyWith(adsRemoved: true));
      return;
    }
    if (isExtraProductId(u.productId)) {
      // Extra pack: bought once, shared by every child on this device.
      if (!_data.ownedPacks.contains(u.productId)) {
        await _commit(
          _data.copyWith(ownedPacks: {..._data.ownedPacks, u.productId}),
        );
      }
      return;
    }
    final def = catalog.byId(u.productId);
    if (def == null) return;
    var d = _data;
    if (def.type == ProductType.consumable) {
      final key = u.purchaseId;
      if (u.status == PurchaseStatus.restored) {
        return; // consumables are never restored
      }
      if (key != null && d.processedPurchases.contains(key)) {
        return;
      }
      d = d.copyWith(
        coins: d.coins + def.coins,
        processedPurchases: key == null ? null : {...d.processedPurchases, key},
      );
    } else if (def.grants == ProductDef.removeAdsGrant) {
      d = d.copyWith(adsRemoved: true);
    } else if (def.grants == ProductDef.unlockFullGrant) {
      d = d.copyWith(fullUnlock: true);
    }
    await _commit(d);
  }

  // ---- child profiles -----------------------------------------------------

  /// The child using the device now. Not saved: the picker shows on every launch.
  String? _activeId;

  ChildProfile? get activeChild {
    for (final p in _data.profiles) {
      if (p.id == _activeId) return p;
    }
    return null;
  }

  List<ChildProfile> get children => _data.profiles;
  bool get canAddChild => _data.profiles.length < maxChildProfiles;

  bool ownsPack(String productId) => _data.ownedPacks.contains(productId);

  void selectChild(String id) {
    if (_data.profiles.any((p) => p.id == id)) {
      _activeId = id;
      _playStart = _clock();
      notifyListeners();
    }
  }

  // ---- play time ------------------------------------------------------------

  DateTime? _playStart;

  /// The app came to the front with a child selected: start counting.
  void resumePlay() {
    if (_activeId != null && !_playHeld) _playStart ??= _clock();
  }

  bool _playHeld = false;

  /// Family mode: the active child's own counting stops (their turns are credited with
  /// [creditPlay]) until [releasePlay].
  Future<void> holdPlay() async {
    await pausePlay();
    _playHeld = true;
  }

  void releasePlay() {
    _playHeld = false;
    resumePlay();
  }

  /// Adds [seconds] of play to the named child's weekly total (family mode: the child whose
  /// turn it was, not necessarily the active one). Non-positive amounts add nothing.
  Future<void> creditPlay(String childId, int seconds) async {
    if (seconds <= 0 || !_data.profiles.any((p) => p.id == childId)) return;
    final day = today;
    await _updateChild(
      childId,
      (p) => p.copyWith(playTime: p.playTime.add(day, seconds)),
    );
  }

  /// The app went to the background, or the child left: add the time since [resumePlay] to the
  /// child's weekly total. A device clock moved back adds nothing.
  Future<void> pausePlay() async {
    final start = _playStart;
    final id = _activeId;
    _playStart = null;
    if (start == null || id == null) return;
    final seconds = _clock().difference(start).inSeconds;
    if (seconds <= 0) return;
    final day = today;
    await _updateChild(
      id,
      (p) => p.copyWith(playTime: p.playTime.add(day, seconds)),
    );
  }

  /// Clears one child's progress and play time. The player, coins, purchases and shop items stay.
  Future<void> resetChildProgress(String id) => _updateChild(
    id,
    (p) => ChildProfile(
      id: p.id,
      nickname: p.nickname,
      avatar: p.avatar,
      year: p.year,
      colorTheme: p.colorTheme,
      mode: p.mode,
      lockedMode: p.lockedMode,
    ),
  );

  /// Hubs without learning content have no picker: one built-in local player, selected at once.
  Future<ChildProfile> ensureLocalPlayer() async {
    var p = _data.profiles.isEmpty ? null : _data.profiles.first;
    p ??= await addChild('Player');
    _activeId = p!.id;
    _playStart = _clock();
    notifyListeners();
    return p;
  }

  /// Back to the picker.
  Future<void> leaveChild() {
    final saved = pausePlay(); // reads the active child before it is cleared
    _activeId = null;
    notifyListeners();
    return saved;
  }

  /// Adds a child (a made-up nickname and a built-in avatar). Null when the limit is reached
  /// or the nickname is empty.
  Future<ChildProfile?> addChild(
    String nickname, {
    String avatar = 'fox',
    int? year,
  }) async {
    final name = nickname.trim();
    if (!canAddChild || name.isEmpty) return null;
    var n = _data.profiles.length + 1;
    while (_data.profiles.any((p) => p.id == 'p$n')) {
      n++;
    }
    final child = ChildProfile(
      id: 'p$n',
      nickname: name.length > maxNicknameLength
          ? name.substring(0, maxNicknameLength)
          : name,
      avatar: avatarIds.contains(avatar) ? avatar : avatarIds.first,
      year: year,
    );
    await _commit(_data.copyWith(profiles: [..._data.profiles, child]));
    return child;
  }

  Future<void> _updateChild(String id, ChildProfile Function(ChildProfile) f) =>
      _commit(
        _data.copyWith(
          profiles: [
            for (final p in _data.profiles)
              if (p.id == id) f(p) else p,
          ],
        ),
      );

  /// Sets the year level (child at first launch, or a parent later). Items already open stay
  /// open; the new year starts its own release.
  Future<void> setChildYear(String id, int year) =>
      _updateChild(id, (p) => p.copyWith(year: year.clamp(0, 12)));

  /// Switches the child to [mode] and remembers it. False (nothing changes) while a parent
  /// has locked the child to a mode.
  Future<bool> setChildMode(String id, LearnMode mode) async {
    final c = _data.profiles.where((p) => p.id == id).firstOrNull;
    if (c == null || c.lockedMode != null) return false;
    await _updateChild(id, (p) => p.copyWith(mode: mode));
    return true;
  }

  /// Locks a child to Game or Study mode; null lifts the lock.
  Future<void> setChildLockedMode(String id, LearnMode? mode) => _updateChild(
    id,
    (p) => mode == null
        ? p.copyWith(clearLock: true)
        : p.copyWith(lockedMode: mode),
  );

  /// Deletes one child and their progress. Coins, purchases and other children stay.
  Future<void> deleteChild(String id) async {
    if (_activeId == id) {
      _activeId = null;
      _playStart = null;
    }
    await _commit(
      _data.copyWith(
        profiles: [
          for (final p in _data.profiles)
            if (p.id != id) p,
        ],
      ),
    );
  }

  /// Saves a child's progress (after an answer or a release step).
  Future<void> setChildProgress(String id, ChildProgress progress) =>
      _updateChild(id, (p) => p.copyWith(progress: progress));

  Future<void> setDownloadWifiOnly(bool v) =>
      _commit(_data.copyWith(downloadWifiOnly: v));
}
