import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../host/ad_service.dart';

import 'package:game_core/kit/audio/audio.dart' hide ambienceTracks;
import 'package:game_core/kit/keys/keys.dart';
import 'package:game_core/kit/layout/game_frame.dart';
import 'package:game_core/kit/layout/window_class.dart';

import '../core/audio/blockfall_audio.dart';
import '../host/profile_store.dart';
import '../core/save/save_data.dart';
import '../host/services.dart';
import '../game/flame/blockfall_flame_game.dart';
import '../game/flame/blockfall_layout.dart';
import '../game/rules/blockfall_game.dart';
import '../game/rules/events.dart';
import '../game/rules/powerups.dart';
import '../game/rules/well.dart';
import '../game/themes/block_theme.dart';
import 'game_over_panel.dart';
import 'hud_widgets.dart';
import '../host/routes.dart';
import 'share_card.dart';
import 'test_ids.dart';
import 'versus_screen.dart';
import 'theme_fade.dart';
import 'widgets.dart';

/// `--dart-define=BLOCKFALL_SEED=<int>` fixes the bag order and prism placement.
const int kBlockfallSeed = int.fromEnvironment(
  'BLOCKFALL_SEED',
  defaultValue: -1,
);

/// Player-facing label of the game-over continue action (rewarded ad). Rename it here only.
const String kContinueLabel = 'Continue';

/// Game-over button sizes (see docs/SPEC.md, "Game over layout").
const double _kLargeFont = 22;
const EdgeInsets _kLargePadding = EdgeInsets.symmetric(
  horizontal: 28,
  vertical: 16,
);
const double _kSmallFont = 15;
const EdgeInsets _kSmallPadding = EdgeInsets.symmetric(
  horizontal: 18,
  vertical: 9,
);

final ValueNotifier<int> _noRevision = ValueNotifier(0);

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.game, this.offerVersus = false});

  /// Offers "2 players" (versus) before a fresh game on windows 600 dp wide and up. A container
  /// opts in; a game being resumed or a test game never shows the choice.
  final bool offerVersus;

  /// Injectable for tests (seeded rules, preloaded well).
  final BlockfallGame? game;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  BlockfallFlameGame? _flame;
  BlockfallServices? _s;
  bool _started = false;
  bool _recorded = false;
  bool _dialogOpen = false;
  bool _sheetOpen = false;
  bool _paused = false;

  /// The 1 or 2 players choice is showing over a fresh game; "2 players" swaps to the versus screen.
  bool _choosing = false;
  bool _versus = false;
  int _gameIndex = 0;
  final AudioService _audio = newBlockfallAudio();
  bool _warned = false;
  BlockfallServices? _runFlagOwner;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Tells Home (the tip of the day) that a run is on screen; cleared in dispose.
    _runFlagOwner =
        context
            .getInheritedWidgetOfExactType<BlockfallServicesScope>()
            ?.services
          ?..inRun = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = BlockfallServicesScope.of(context);
    if (!_started) {
      _started = true;
      _init();
    }
  }

  @override
  void dispose() {
    _runFlagOwner?.inRun = false;
    WidgetsBinding.instance.removeObserver(this);
    _persistStock();
    _flame?.onEvent = null;
    _audio.dispose();
    _flame?.revision.dispose();
    super.dispose();
  }

  void _init() {
    // An unfinished game (autosave) comes back as it was, paused; a bad save is dropped.
    BlockfallGame? restored;
    var themeStart = _s!.profile.data.themeIndex;
    final saved = widget.game == null ? _s!.profile.data.game : null;
    if (saved != null) {
      restored = BlockfallGame.restore(saved, stock: _savedStock());
      themeStart = (saved['themeStart'] as num?)?.toInt() ?? themeStart;
      if (restored == null) {
        // Not during build: clearing notifies the profile's listeners.
        final profile = _s!.profile;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => profile.saveGame(null),
        );
      }
    }
    final rules = widget.game ?? restored ?? _newRules();
    _flame = BlockfallFlameGame(
      rules: rules,
      showGhost: _s!.profile.data.ghostOn,
      themeStart: themeStart,
    )..onEvent = _onEvent;
    _syncAudio();
    if (restored != null) {
      _paused = true;
      rules.isPaused = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _snack('Game resumed'),
      );
      return;
    }
    if (widget.offerVersus &&
        widget.game == null &&
        WindowClass.ofContext(context) != WindowClass.compact) {
      _choosing = true;
      rules.isPaused = true;
      return;
    }
    _audio.startAmbience();
    _audio.voice('go');
  }

  void _chooseOnePlayer() {
    setState(() => _choosing = false);
    _syncPause();
    _audio.startAmbience();
    _audio.voice('go');
  }

  void _chooseVersus() => setState(() {
    _choosing = false;
    _versus = true;
  });

  Map<PowerUpType, int> _savedStock() {
    final saved = _s!.profile.data;
    return {for (final t in PowerUpType.values) t: saved.powerUpCount(t.name)};
  }

  /// Saves the running game (not a finished or untouched one) so leaving, a call or a
  /// kill never loses it. A finished game clears the save.
  void _autosave() {
    final f = _flame;
    final s = _s;
    if (f == null || s == null || widget.game != null) return;
    final g = f.rules;
    if (g.isGameOver || (g.piecesPlaced == 0 && g.score == 0)) {
      s.profile.saveGame(null);
    } else {
      s.profile.saveGame({...g.toJson(), 'themeStart': f.themeStart});
    }
  }

  void _syncAudio() {
    final d = _s!.profile.data;
    _audio.apply(
      sound: d.soundOn,
      volume: d.masterVolume,
      ambience: d.ambience,
      voice: d.voiceOn,
    );
  }

  BlockfallGame _newRules() {
    final stock = _savedStock();
    if (kBlockfallSeed >= 0) {
      return BlockfallGame.seeded(kBlockfallSeed + _gameIndex, stock: stock);
    }
    return BlockfallGame(random: Random(), stock: stock);
  }

  // ----------------------------------------------------------- pause logic

  void _syncPause() {
    final f = _flame;
    if (f == null) return;
    f.rules.isPaused = _paused || _sheetOpen || _choosing;
    f.touch.cancel();
    f.setSoftDrop(false);
    f.refresh();
  }

  void _pause() {
    final f = _flame;
    if (f == null || f.rules.isGameOver || _dialogOpen) return;
    setState(() => _paused = true);
    _audio.pauseAmbience();
    _syncPause();
    _autosave();
  }

  void _resume() {
    setState(() => _paused = false);
    _audio.startAmbience();
    _syncPause();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _audio.pauseAmbience();
      _pause();
    } else if (!_paused) {
      _audio.startAmbience();
    }
  }

  // ------------------------------------------------------------ game events

  void _onEvent(GameEvent e) {
    final s = _s;
    if (s == null) return;
    final vib = s.profile.data.vibrationOn;
    _syncAudio();
    switch (e) {
      case PieceLocked():
        if (vib) HapticFeedback.lightImpact();
        _warnIfStackHigh();
        _autosave();
      case LinesCleared():
        if (vib) HapticFeedback.mediumImpact();
        _praiseClear(e);
      case LevelUp():
        _audio.voice('awesome');
        // Remember the rotation so a new game (or a new launch) continues it.
        s.profile.setThemeIndex(_flame!.themeIndex);
      case PowerUpUsed():
        _persistStock();
        _autosave();
      case GameOver():
        if (_flame!.rules.score > s.profile.data.bestScore) {
          _audio.voice('better_than_the_best');
        } else {
          _audio.voice('game_over', variants: 2);
        }
        _persistStock();
        _autosave();
        _showGameOver();
      default:
        break;
    }
  }

  /// Narrator line for a clear: the rarest achievement in it wins.
  void _praiseClear(LinesCleared e) {
    final String? line;
    if (e.perfectClear) {
      line = 'unbelievable';
    } else if (e.count >= 4) {
      line = 'incredible';
    } else if (e.backToBack) {
      line = 'fantastic';
    } else if (e.combo >= 5) {
      line = 'unstoppable';
    } else if (e.combo >= 3) {
      line = 'combo';
    } else if (e.count == 3) {
      line = 'excellent';
    } else if (e.count == 2) {
      line = 'great';
    } else if (e.combo >= 2) {
      line = 'nice';
    } else {
      line = null;
    }
    if (line != null) _audio.voice(line);
  }

  /// "Careful" once the stack reaches the top few visible rows; re-armed when it drops.
  void _warnIfStackHigh() {
    final well = _flame?.rules.well;
    if (well == null) return;
    const limit = Well.hiddenRows + 4;
    var high = false;
    for (var r = Well.hiddenRows; r < limit && !high; r++) {
      for (var c = 0; c < Well.cols && !high; c++) {
        high = well.isFilled(r, c);
      }
    }
    if (high && !_warned) _audio.voice('careful');
    _warned = high;
  }

  void _persistStock() {
    final f = _flame;
    final s = _s;
    if (f == null || s == null) return;
    s.profile.setPowerUps({
      for (final t in PowerUpType.values) t.name: f.rules.stock(t),
    });
  }

  Future<void> _finishGame() async {
    if (_recorded) return;
    final s = _s!;
    final g = _flame!.rules;
    if (g.piecesPlaced == 0 && g.score == 0 && !g.isGameOver) return;
    _recorded = true;
    _persistStock();
    if (g.coinsFromPrisms > 0) await s.profile.addCoins(g.coinsFromPrisms);
    final unlocked = await s.profile.recordGameFinished(
      GameSummary(
        score: g.score,
        linesCleared: g.lines,
        piecesPlaced: g.piecesPlaced,
        maxCombo: g.maxCombo,
        quads: g.quads,
        prismRows: g.prismRowsCleared,
        holdsUsed: g.holdsUsed,
        perfectClears: g.perfectClears,
        level: g.level,
      ),
    );
    await s.leaderboard.submitScore(s.config.leaderboardHighScore, g.score);
    for (final a in unlocked) {
      await s.leaderboard.unlockAchievement(a.id);
    }
    s.analytics.logEvent('game_over', {'score': g.score});
    if (unlocked.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Achievement unlocked: ${unlocked.map((a) => a.title).join(', ')} '
            '(+${unlocked.fold<int>(0, (n, a) => n + a.reward)} coins)',
          ),
        ),
      );
    }
  }

  Future<void> _showGameOver() async {
    if (_dialogOpen || !mounted) return;
    _dialogOpen = true;
    final s = _s!;
    final flame = _flame!;
    final game = flame.rules;
    final best = max(s.profile.data.bestScore, game.score);
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (ctx) => GameKeyboard(
        // Enter or Space plays again, Esc goes Home, R continues (B-09).
        onInput: (i) {
          if (i.repeat) return;
          if (i.action == GameAction.action || i.action == GameAction.pause) {
            Navigator.pop(ctx, 'retry');
          } else if (i.action == GameAction.exit) {
            Navigator.pop(ctx, 'home');
          }
        },
        shortcuts: {
          if (game.canRevive)
            LogicalKeyboardKey.keyR: () => Navigator.pop(ctx, 'revive'),
        },
        child: GameOverPanel(
          key: TestIds.gameOverDialog,
          panelKey: TestIds.gameOverPanel,
          viewKey: TestIds.gameOverView,
          title: 'Game over',
          shareButton: GameOverButton(
            key: TestIds.gameOverShare,
            kind: GameOverButtonKind.ghost,
            icon: Icons.share,
            semanticLabel: 'Share',
            fontSize: _kSmallFont,
            padding: _kSmallPadding,
            onPressed: () async {
              final png = await captureShareCard(
                ctx,
                ShareCardData(
                  gameName: s.config.displayName,
                  headline: 'Score',
                  big: '${game.score}',
                  best: best,
                  theme: flame.theme,
                ),
              );
              await s.share.shareScore(score: game.score, image: png);
            },
          ),
          details: [
            ValueNode(
              key: TestIds.gameOverScore,
              value: '${game.score}',
              child: Text(
                'Score ${game.score}',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text('Best $best'),
            if (!s.profile.data.adsRemoved)
              RemoveAdsPill(
                key: TestIds.gameOverRemoveAds,
                onPressed: () =>
                    Navigator.of(ctx).pushNamed(BlockfallRoutes.shop),
              ),
            if (game.score >= best && game.score > 0)
              const Text('New best!', style: TextStyle(color: kGold)),
          ],
          leadButton: game.canRevive
              ? GameOverButton(
                  key: TestIds.gameOverRevive,
                  kind: GameOverButtonKind.primary,
                  icon: Icons.smart_display,
                  label: '$kContinueLabel · ${game.revivesRemaining} left (R)',
                  fontSize: _kLargeFont,
                  padding: _kLargePadding,
                  onPressed: () => Navigator.pop(ctx, 'revive'),
                )
              : null,
          buttons: [
            GameOverButton(
              key: TestIds.gameOverRetry,
              kind: game.canRevive
                  ? GameOverButtonKind.secondary
                  : GameOverButtonKind.primary,
              icon: Icons.replay,
              label: 'Play again (Enter / Space)',
              fontSize: game.canRevive ? _kSmallFont : _kLargeFont,
              padding: game.canRevive ? _kSmallPadding : _kLargePadding,
              onPressed: () => Navigator.pop(ctx, 'retry'),
            ),
            GameOverButton(
              key: TestIds.gameOverHome,
              kind: GameOverButtonKind.ghost,
              icon: Icons.home,
              label: 'Home (Esc)',
              fontSize: _kSmallFont,
              padding: _kSmallPadding,
              onPressed: () => Navigator.pop(ctx, 'home'),
            ),
          ],
        ),
      ),
    );
    _dialogOpen = false;
    if (!mounted) return;
    switch (action) {
      case 'revive':
        if (await _continueGame(s, game)) {
          if (mounted) flame.refresh();
          return;
        }
        if (mounted) _showGameOver();
      case 'retry':
        await _finishGame();
        await s.ads.maybeShowInterstitialAfterGameOver();
        if (!mounted) return;
        _gameIndex++;
        _recorded = false;
        setState(() => _paused = false);
        flame.reset(_newRules(), themeStart: s.profile.data.themeIndex);
        _warned = false;
        _audio.voice('go');
        _syncPause();
      default:
        await _finishGame();
        await s.ads.maybeShowInterstitialAfterGameOver();
        if (mounted) Navigator.of(context).pop();
    }
  }

  /// Game-over Continue. Remove Ads owners continue at once; everyone else must
  /// earn the rewarded ad. Never falls back to coins or a free continue.
  /// Returns true when the game continued.
  Future<bool> _continueGame(BlockfallServices s, BlockfallGame game) async {
    if (s.profile.data.adsRemoved) return game.revive();
    final earned = await s.ads.showRewarded(BlockfallAdPlacement.revive);
    if (!mounted) return false;
    if (earned && game.revive()) return true;
    _snack('No ad available right now. Try again in a moment.');
    return false;
  }

  Future<void> _leave() async {
    final g = _flame?.rules;
    if (g != null && !g.isGameOver && widget.game == null) {
      _autosave(); // an unfinished game stays resumable; it is recorded when it ends
    } else {
      await _finishGame();
    }
    if (mounted) Navigator.of(context).pop();
  }

  // -------------------------------------------------------------- power-ups

  Future<void> _onPowerUp(PowerUpType t) async {
    final f = _flame;
    if (f == null || _paused || f.rules.isGameOver) return;
    final rules = f.rules;
    if (rules.stock(t) <= 0) {
      if (rules.usesThisGame(t) >= PowerUpRules.maxUsesPerTypePerGame) {
        _snack('${PowerUpButton.title(t)} is used up for this game');
        return;
      }
      await _openRefill(t);
      return;
    }
    final r = f.usePowerUp(t);
    if (r == PowerUpResult.limitReached) {
      _snack('Max ${PowerUpRules.maxUsesPerTypePerGame} uses per game');
    }
    _persistStock();
  }

  Future<void> _openRefill(PowerUpType t) async {
    final f = _flame!;
    final s = _s!;
    _sheetOpen = true;
    _syncPause();
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF0F2430),
      builder: (ctx) => GameKeyboard(
        // 1 buys with coins, 2 watches an ad, Esc closes (B-09).
        onInput: (i) {
          if (i.repeat) return;
          if (i.action == GameAction.pick1) {
            Navigator.pop(ctx, 'coins');
          } else if (i.action == GameAction.pick2 &&
              f.rules.adRefillsLeft > 0) {
            Navigator.pop(ctx, 'ad');
          } else if (i.action == GameAction.exit) {
            Navigator.pop(ctx);
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 10,
              children: [
                Text(
                  'Out of ${PowerUpButton.title(t)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // What the power does, readable before spending anything.
                Text(
                  PowerUpButton.description(t),
                  key: TestIds.gameRefillDescription,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                FilledButton.icon(
                  key: TestIds.gameRefillCoins,
                  icon: const CoinIcon(),
                  label: Text(withKey('Buy with coins (${t.price})', '1')),
                  onPressed: () => Navigator.pop(ctx, 'coins'),
                ),
                OutlinedButton.icon(
                  key: TestIds.gameRefillAd,
                  icon: const Icon(Icons.smart_display),
                  label: Text(
                    withKey(
                      s.profile.data.adsRemoved
                          ? 'Get +1 free (${f.rules.adRefillsLeft} left)'
                          : 'Watch ad for +1 (${f.rules.adRefillsLeft} left)',
                      '2',
                    ),
                  ),
                  onPressed: f.rules.adRefillsLeft > 0
                      ? () => Navigator.pop(ctx, 'ad')
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    _sheetOpen = false;
    if (!mounted) return;
    switch (choice) {
      case 'coins':
        if (await s.profile.spendCoins(t.price)) {
          f.rules.addStock(t);
        } else {
          _snack('Not enough coins (${t.price} needed)');
        }
      case 'ad':
        final earned =
            s.profile.data.adsRemoved ||
            await s.ads.showRewarded(BlockfallAdPlacement.powerUp);
        if (earned && !f.rules.refillWithAd(t)) {
          _snack('No more ad refills this game');
        } else if (!earned) {
          _snack('Ad not available. Try again later.');
        }
    }
    _persistStock();
    if (mounted) {
      _syncPause();
      f.refresh();
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  // ------------------------------------------------------------------ keyboard
  // docs/KEYBOARD.md. Left and right move (held keys repeat), Up rotates, Down soft-drops while
  // held, Enter drops at once, Q holds, 1 to 3 use the power-ups, Space or Esc pause.

  void _onKey(GameInput i) {
    final f = _flame;
    if (f == null) return;
    if (_choosing) {
      // Enter, Space or 1 starts one player, 2 opens versus (the buttons work too).
      if (i.repeat) return;
      if (i.action == GameAction.action ||
          i.action == GameAction.pause ||
          i.action == GameAction.pick1) {
        _chooseOnePlayer();
      } else if (i.action == GameAction.pick2) {
        _chooseVersus();
      }
      return;
    }
    final pausing = i.action == GameAction.pause || i.action == GameAction.exit;
    if (pausing) {
      if (i.repeat) return;
      // Esc and Space pause; on the pause screen they go back to the game.
      _paused ? _resume() : _pause();
      return;
    }
    if (_paused || _sheetOpen || _dialogOpen || f.rules.isGameOver) return;
    switch (i.action) {
      case GameAction.left:
        f.moveLeft();
      case GameAction.right:
        f.moveRight();
      case GameAction.up:
        if (!i.repeat) f.rotate();
      case GameAction.down:
        if (!i.repeat) f.setSoftDrop(true, minSeconds: 0.15);
      case GameAction.action:
        if (!i.repeat) f.hardDrop();
      case GameAction.question:
        if (!i.repeat) f.hold();
      case GameAction.pick1 || GameAction.pick2 || GameAction.pick3:
        if (!i.repeat) {
          final n = i.action.pickNumber! - 1;
          if (n < PowerUpType.values.length) _onPowerUp(PowerUpType.values[n]);
        }
      default:
        break;
    }
  }

  void _onKeyRelease(GameInput i) {
    if (i.action == GameAction.down) _flame?.setSoftDrop(false);
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    if (_versus) {
      return BlockfallVersusScreen(
        theme: BlockTheme.byIndex(_s!.profile.data.themeIndex),
        onExit: () => Navigator.of(context).pop(),
      );
    }
    final flame = _flame;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _pause();
      },
      child: Scaffold(
        body: ListenableBuilder(
          listenable: flame?.revision ?? _noRevision,
          builder: (context, child) => ThemeBackground(
            theme:
                flame?.theme ?? BlockTheme.byIndex(_s!.profile.data.themeIndex),
            child: child!,
          ),
          child: SafeArea(
            child: GameKeyboard(
              onInput: _onKey,
              onRelease: _onKeyRelease,
              // L exits from the pause screen (B-09).
              shortcuts: {if (_paused) LogicalKeyboardKey.keyL: _leave},
              child: flame == null
                  ? Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: IconButton.filledTonal(
                          key: TestIds.gameBack,
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    )
                  : GameFrame(
                      // Centered; no ad beside the well while a game is played.
                      showAds: _paused || _choosing,
                      phoneBanner: null,
                      maxWidth: 640,
                      padding: EdgeInsets.zero,
                      child: Stack(
                        children: [
                          ValueListenableBuilder<int>(
                            valueListenable: flame.revision,
                            builder: (context, _, _) =>
                                _buildPlay(context, flame),
                          ),
                          if (_paused) _buildPauseOverlay(),
                          if (_choosing) _buildModeChoice(),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlay(BuildContext context, BlockfallFlameGame flame) {
    final s = _s!;
    final rules = flame.rules;
    final buttons = s.profile.controlScheme == ControlScheme.buttons;
    final left = s.profile.data.leftHanded;
    return Column(
      children: [
        // Invisible; the current theme id is its Semantics value (tests, bot).
        Semantics(
          key: TestIds.gameTheme,
          identifier: 'game.theme',
          value: flame.theme.id,
          child: const SizedBox.shrink(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Row(
            children: [
              // Left-handed: pause on the left, back on the right (score and best stay).
              IconButton.filledTonal(
                key: left ? TestIds.gamePause : TestIds.gameBack,
                icon: Icon(left ? Icons.pause : Icons.chevron_left),
                onPressed: _pause,
              ),
              // Score shares the header row, so the well gets the freed height.
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ScorePill(score: rules.score),
                  ),
                ),
              ),
              ListenableBuilder(
                listenable: s.profile,
                builder: (context, _) =>
                    _BestChip(best: max(s.profile.data.bestScore, rules.score)),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                key: left ? TestIds.gameBack : TestIds.gamePause,
                icon: Icon(left ? Icons.chevron_left : Icons.pause),
                onPressed: _pause,
              ),
            ],
          ),
        ),
        _StreakBar(
          streak: s.profile.displayStreak,
          showStreak: s.config.streaksEnabled,
          combo: rules.combo,
          prismCoins: rules.coinsFromPrisms,
          rushSeconds: rules.rushRemaining.ceil(),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) =>
                _buildMiddle(BlockfallLayout(c.maxWidth, c.maxHeight), flame),
          ),
        ),
        if (buttons) _buildControls(flame, left),
        const SizedBox(height: 6),
        _buildPowerUps(flame),
        const SizedBox(height: 8),
        if (WindowClass.ofContext(context) != WindowClass.compact)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: KeyHints(
              style: TextStyle(color: Colors.white70, fontSize: 12),
              words: {
                GameAction.up: 'rotate',
                GameAction.down: 'soft drop',
                GameAction.action: 'hard drop',
                GameAction.question: 'hold',
                GameAction.pick1: 'power-ups',
              },
              actions: [
                GameAction.left,
                GameAction.right,
                GameAction.up,
                GameAction.down,
                GameAction.action,
                GameAction.question,
                GameAction.pick1,
                GameAction.pick2,
                GameAction.pick3,
                GameAction.pause,
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMiddle(BlockfallLayout l, BlockfallFlameGame flame) {
    final rules = flame.rules;
    final touch = _s!.profile.controlScheme != ControlScheme.buttons;
    final leftHanded = _s!.profile.data.leftHanded;
    Widget well = SizedBox(
      width: l.wellWidth,
      height: l.wellHeight,
      child: GameWidget<BlockfallFlameGame>(
        key: TestIds.gameWidget,
        game: flame,
        // Flame's own focus would swallow every key; the game's keys go through GameKeyboard.
        autofocus: false,
      ),
    );
    well = _WellInput(
      key: TestIds.gameWell,
      flame: flame,
      enabled: touch,
      child: well,
    );
    final hold = rules.holdPiece;
    final holdBox = GestureDetector(
      key: TestIds.gameHold,
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_paused) return;
        flame.hold();
      },
      child: ValueNode(
        key: TestIds.gameHoldPiece,
        value: hold?.type.displayName ?? 'empty',
        label: 'Hold',
        child: HudBox(
          label: 'HOLD',
          width: l.boxWidth,
          height: l.hudHeight,
          child: hold == null
              ? const SizedBox.shrink()
              : PiecePreview(
                  theme: flame.theme,
                  spec: hold,
                  cell: l.miniCell(l.boxWidth),
                  dim: !rules.canHold,
                ),
        ),
      ),
    );
    final next = rules.next;
    final hud = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: l.gap,
      children: [
        if (!leftHanded) holdBox,
        ValueNode(
          key: TestIds.gameLevel,
          value: '${rules.level}',
          label: 'Level',
          child: StatPanel(
            label: 'LEVEL',
            value: rules.level,
            width: l.boxWidth,
            height: l.hudHeight,
          ),
        ),
        ValueNode(
          key: TestIds.gameGoal,
          value: '${rules.goal}',
          label: 'Goal',
          child: StatPanel(
            label: 'GOAL',
            value: rules.goal,
            width: l.boxWidth,
            height: l.hudHeight,
          ),
        ),
        for (var i = 0; i < next.length; i++)
          ValueNode(
            key: TestIds.gameNext(i),
            value: next[i].type.displayName,
            label: 'Next ${i + 1}',
            child: HudBox(
              label: i == 0 ? 'NEXT' : '',
              width: l.boxWidth,
              height: l.hudHeight,
              child: PiecePreview(
                theme: flame.theme,
                spec: next[i],
                cell: l.miniCell(l.boxWidth) * (i == 0 ? 1 : 0.8),
              ),
            ),
          ),
        if (leftHanded) holdBox,
      ],
    );
    return Stack(
      children: [
        Column(
          children: [
            SizedBox(height: l.gap),
            hud,
            SizedBox(height: l.gap),
            Expanded(child: Center(child: well)),
          ],
        ),
      ],
    );
  }

  Widget _buildControls(BlockfallFlameGame f, bool leftHanded) {
    final steer = <Widget>[
      ControlButton(
        key: TestIds.gameCtlLeft,
        icon: Icons.arrow_left,
        label: 'Move left',
        repeat: true,
        onPress: f.moveLeft,
      ),
      ControlButton(
        key: TestIds.gameCtlRotate,
        icon: Icons.rotate_right,
        label: 'Rotate',
        onPress: f.rotate,
      ),
      ControlButton(
        key: TestIds.gameCtlRight,
        icon: Icons.arrow_right,
        label: 'Move right',
        repeat: true,
        onPress: f.moveRight,
      ),
    ];
    final drops = <Widget>[
      ControlButton(
        key: TestIds.gameCtlSoftDrop,
        icon: Icons.keyboard_arrow_down,
        label: 'Soft drop',
        onPress: () => f.setSoftDrop(true, minSeconds: 0.15),
        onRelease: () => f.setSoftDrop(false),
      ),
      ControlButton(
        key: TestIds.gameCtlHardDrop,
        icon: Icons.keyboard_double_arrow_down,
        label: 'Hard drop',
        onPress: f.hardDrop,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8,
        children: [
          // Left-handed mirrors the groups: drops on the left, steering on the right.
          // Arrows keep their meaning, so move-left stays left of move-right.
          if (!leftHanded) ...steer,
          if (!leftHanded) ...drops,
          if (leftHanded) ...drops.reversed,
          if (leftHanded) ...steer,
        ],
      ),
    );
  }

  Widget _buildPowerUps(BlockfallFlameGame f) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    spacing: 18,
    children: [
      for (final t in PowerUpType.values)
        PowerUpButton(
          type: t,
          keyName: '${PowerUpType.values.indexOf(t) + 1}',
          stock: f.rules.stock(t),
          active: t == PowerUpType.slow && f.rules.slowActive,
          caption: t == PowerUpType.slow && f.rules.slowActive
              ? '${f.rules.slowRemaining.ceil()}s'
              : null,
          onTap: () => _onPowerUp(t),
        ),
    ],
  );

  /// The 1 or 2 players choice over a fresh game on a wide window.
  Widget _buildModeChoice() => Positioned.fill(
    child: Container(
      color: const Color(0xE60A1822),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 14,
          children: [
            const Text(
              'BLOCKFALL',
              style: TextStyle(
                fontSize: 30,
                letterSpacing: 6,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            SizedBox(
              width: 260,
              height: 52,
              child: FilledButton(
                key: TestIds.gameModeOne,
                autofocus: true,
                onPressed: _chooseOnePlayer,
                child: const Text('1 player (Enter)'),
              ),
            ),
            SizedBox(
              width: 260,
              height: 52,
              child: OutlinedButton(
                key: TestIds.gameModeTwo,
                onPressed: _chooseVersus,
                child: const Text(
                  '2 players: versus (2)',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildPauseOverlay() => Positioned.fill(
    child: Container(
      color: const Color(0xE60A1822),
      child: Stack(
        alignment: Alignment.center,
        children: [_buildPauseButtons()],
      ),
    ),
  );

  Widget _buildPauseButtons() => Column(
    mainAxisSize: MainAxisSize.min,
    spacing: 14,
    children: [
      const Text(
        'PAUSED',
        style: TextStyle(
          fontSize: 30,
          letterSpacing: 6,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      SizedBox(
        width: 240,
        height: 52,
        child: FilledButton.icon(
          key: TestIds.gamePauseResume,
          icon: const Icon(Icons.play_arrow),
          label: Text(withKey('Resume', 'Esc / Space')),
          onPressed: _resume,
        ),
      ),
      SizedBox(
        width: 240,
        height: 52,
        child: OutlinedButton.icon(
          key: TestIds.gamePauseQuit,
          icon: const Icon(Icons.exit_to_app),
          label: Text(withKey('Exit', 'L')),
          onPressed: _leave,
        ),
      ),
    ],
  );
}

/// Feeds raw pointer events on the well into the pure-Dart [TouchControls].
class _WellInput extends StatefulWidget {
  const _WellInput({
    super.key,
    required this.flame,
    required this.enabled,
    required this.child,
  });
  final BlockfallFlameGame flame;
  final bool enabled;
  final Widget child;

  @override
  State<_WellInput> createState() => _WellInputState();
}

class _WellInputState extends State<_WellInput> {
  int? _pointer;
  VelocityTracker? _velocity;

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: (e) {
      if (!widget.enabled || _pointer != null || widget.flame.rules.isPaused) {
        return;
      }
      _pointer = e.pointer;
      _velocity = VelocityTracker.withKind(e.kind)
        ..addPosition(e.timeStamp, e.position);
      widget.flame.touch.pointerDown(
        e.position.dx,
        e.position.dy,
        e.timeStamp.inMilliseconds,
      );
    },
    onPointerMove: (e) {
      if (e.pointer != _pointer) return;
      _velocity?.addPosition(e.timeStamp, e.position);
      widget.flame.touch.pointerMove(e.position.dx, e.position.dy);
    },
    onPointerUp: (e) {
      if (e.pointer != _pointer) return;
      _velocity?.addPosition(e.timeStamp, e.position);
      final v = _velocity?.getVelocity().pixelsPerSecond.dy ?? 0;
      _pointer = null;
      widget.flame.touch.pointerUp(
        e.position.dx,
        e.position.dy,
        e.timeStamp.inMilliseconds,
        v,
      );
    },
    onPointerCancel: (e) {
      if (e.pointer != _pointer) return;
      _pointer = null;
      widget.flame.touch.cancel();
    },
    child: widget.child,
  );
}

class _BestChip extends StatelessWidget {
  const _BestChip({required this.best});
  final int best;

  @override
  Widget build(BuildContext context) => ValueNode(
    key: TestIds.gameBest,
    value: '$best',
    label: 'Best score',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: kGold, size: 18),
          const SizedBox(width: 6),
          Text(
            '$best',
            key: TestIds.gameBestText,
            style: TextStyle(
              color: HudColors.of(context).text,
              shadows: HudColors.of(context).shadows,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Streak (daily play streak), current combo and prism coins earned this game.
class _StreakBar extends StatelessWidget {
  const _StreakBar({
    required this.streak,
    required this.showStreak,
    required this.combo,
    required this.prismCoins,
    required this.rushSeconds,
  });
  final int streak;
  final bool showStreak;
  final int combo;
  final int prismCoins;

  /// Whole seconds of Gold Rush left (0 when off).
  final int rushSeconds;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: DefaultTextStyle(
        style: TextStyle(
          color: HudColors.of(context).text,
          shadows: HudColors.of(context).shadows,
          fontSize: 13,
        ),
        // Wrap, so streak + combo + Gold Rush + prism coins never overflow a narrow screen.
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 14,
          runSpacing: 2,
          children: [
            if (showStreak)
              Row(
                key: TestIds.gameStreak,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    size: 18,
                    color: Color(0xFFFF6B5E),
                  ),
                  const SizedBox(width: 4),
                  Text('Day $streak streak'),
                ],
              ),
            ValueNode(
              key: TestIds.gameCombo,
              value: '$combo',
              label: 'Combo',
              child: Text(combo > 0 ? 'Combo x$combo' : 'Combo -'),
            ),
            // Always present: Semantics value = whole seconds left (0 when off).
            Semantics(
              key: TestIds.gameRush,
              identifier: 'game.rush',
              value: '$rushSeconds',
              child: rushSeconds <= 0
                  ? const SizedBox.shrink()
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x33FFC928),
                        border: Border.all(color: const Color(0xFFFFC928)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'GOLD RUSH x2 · ${rushSeconds}s',
                        style: TextStyle(
                          color: HudColors.of(context).text,
                          shadows: HudColors.of(context).shadows,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
            if (prismCoins > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.diamond, size: 16, color: Color(0xFF39D0F2)),
                  const SizedBox(width: 3),
                  Text('+$prismCoins'),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
