import 'dart:async';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../host/ad_service.dart';
import '../core/audio/audio_service.dart';
import '../host/profile_store.dart';
import '../host/services.dart';
import '../game/flame/block_puzzle_game.dart';
import '../game/layout.dart';
import '../game/rules/best_move.dart';
import '../game/rules/boosts.dart';
import '../game/rules/game_state.dart';
import 'best_move_dialog.dart';
import 'boost_widgets.dart';
import 'game_over_panel.dart';
import '../host/routes.dart';
import 'share_card.dart';
import 'test_ids.dart';
import 'theme_background.dart';
import 'widgets.dart';

/// Player-facing name of the rewarded-ad second chance on the game over screen (rename it here only).
const String continueLabel = 'Continue';

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

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.game});

  /// Injectable for tests (seeded generator).
  final BlockPuzzleGame? game;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  BlockPuzzleGame? _game;
  bool _recorded = false;
  bool _dialogOpen = false;
  bool _pauseOpen = false;
  final AudioService _audio = AudioService();
  bool _warned = false;
  BlockPuzzleProfileStore? _profile;
  BlockPuzzleServices? _services;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Tells Home (the tip of the day) that a run is on screen; cleared in dispose.
    _services =
        context
            .getInheritedWidgetOfExactType<BlockPuzzleServicesScope>()
            ?.services
          ?..inRun = true;
  }

  @override
  void dispose() {
    _services?.inRun = false;
    WidgetsBinding.instance.removeObserver(this);
    _profile?.removeListener(_applyAudio);
    _audio.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _audio.startAmbience();
    } else {
      _audio.pauseAmbience();
    }
  }

  /// Pushes the saved sound settings to the audio service (applied immediately).
  void _applyAudio() {
    final d = _profile!.data;
    _audio.apply(
      sound: d.soundOn,
      volume: d.masterVolume,
      ambience: d.ambience,
      voice: d.voiceOn,
    );
  }

  BlockPuzzleGame _ensureGame(BlockPuzzleServices s) {
    final existing = _game;
    if (existing != null) return existing;
    // An unfinished game (autosave) comes back as it was; a bad save is dropped.
    GameState? restored;
    var restoredThemeStart = s.profile.data.themeIndex;
    final saved = widget.game == null ? s.profile.data.game : null;
    if (saved != null) {
      restored = GameState.fromJson(saved, bestScore: s.profile.data.bestScore);
      restoredThemeStart =
          (saved['themeStart'] as num?)?.toInt() ?? restoredThemeStart;
      if (restored == null) {
        // Not during build: clearing notifies the profile's listeners.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => s.profile.saveGame(null),
        );
      }
    }
    final game =
        widget.game ??
        BlockPuzzleGame(
          bestScore: s.profile.data.bestScore,
          themeStart: restored != null
              ? restoredThemeStart
              : s.profile.data.themeIndex,
          initialState: restored,
        );
    if (restored != null && restored.piecesPlaced > 0) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _snack('Game resumed'),
      );
    }
    _profile = s.profile..addListener(_applyAudio);
    game.onPlaced = (o) {
      // Remember the rotation so a new game (or a new launch) continues it.
      s.profile.setThemeIndex(game.themeIndex);
      if (!o.gameOver) {
        _praise(o);
        _warnIfCrowded(game);
      }
      if (o.gems > 0) s.profile.addCoins(o.gems); // 1 coin per gem
      if (s.profile.data.vibrationOn && o.linesCleared > 0) {
        HapticFeedback.mediumImpact();
      }
    };
    game.onChanged = () {
      if (!mounted) return;
      setState(() {});
      _autosave(s, game);
    };
    game.onGameOver = () {
      if (game.state.score > s.profile.data.bestScore) {
        _audio.voice('better_than_the_best');
      } else {
        _audio.voice('game_over', variants: 2);
      }
      _showGameOver(s);
    };
    _applyAudio();
    _audio.startAmbience();
    _audio.voice('go');
    return _game = game;
  }

  /// Saves the running game after every change so Back, a call or a kill never loses it.
  /// A finished game clears the save (the game over flow records it).
  void _autosave(BlockPuzzleServices s, BlockPuzzleGame game) {
    final st = game.state;
    if (st.isGameOver) {
      s.profile.saveGame(null);
    } else {
      s.profile.saveGame({...st.toJson(), 'themeStart': game.themeStart});
    }
  }

  /// Back or the arrow: ask Resume or Exit. The game is saved after every move, so Exit
  /// just leaves; the next Play offers Resume or New game.
  Future<void> _askPause() async {
    if (_dialogOpen || _pauseOpen || !mounted) return;
    final game = _game;
    if (game == null || game.state.isGameOver) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    _pauseOpen = true;
    _audio.pauseAmbience();
    final exit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Paused'),
        actions: [
          TextButton(
            key: TestIds.gamePauseQuit,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Exit'),
          ),
          FilledButton(
            key: TestIds.gamePauseResume,
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Resume'),
          ),
        ],
      ),
    );
    _pauseOpen = false;
    if (!mounted) return;
    if (exit ?? false) {
      Navigator.of(context).pop();
    } else {
      _audio.startAmbience();
    }
  }

  // ---- boosts -------------------------------------------------------------

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _onBoostTap(
    BlockPuzzleServices s,
    BlockPuzzleGame game,
    BoostDef def,
  ) async {
    final st = game.state;
    if (st.isGameOver) return;
    if (game.targeting == def.id) {
      game.cancelTargeting(); // tapping the button again spends nothing
      return;
    }
    if (!st.canUseBoost(def.id)) {
      if (st.boostUsesLeft(def.id) <= 0) {
        _snack('${def.name} is used up this game.');
      }
      return;
    }
    if (s.profile.itemCount(def.key) <= 0) {
      game.cancelTargeting();
      await _refill(s, game, def);
      return;
    }
    switch (def.id) {
      case BoostId.blast || BoostId.hammer:
        game.armTargeting(def.id);
      case BoostId.shuffle:
        game.cancelTargeting();
        if (game.applyShuffle()) await s.profile.useItem(def.key);
      case BoostId.sweep:
        game.cancelTargeting();
        if (game.applySweep() != null) {
          await s.profile.useItem(def.key);
        } else {
          _snack('Nothing to sweep.');
        }
      case BoostId.undo:
        game.cancelTargeting();
        final coins = game.applyUndo();
        if (coins != null) {
          await s.profile.useItem(def.key);
          await s.profile.removeCoins(coins); // gem coins that move paid
          await s.profile.setThemeIndex(game.themeIndex);
        }
    }
  }

  /// A tap on the board while Blast or Hammer is armed (a boost is spent only when applied).
  Future<void> _applyTarget(
    BlockPuzzleServices s,
    BlockPuzzleGame game,
    Offset p,
  ) async {
    final id = game.targeting;
    if (id == null) return;
    final cell = game.layout.cellAt(p.dx, p.dy);
    if (cell == null) return;
    final key = id.name;
    if (game.applyTargeted(cell.$1, cell.$2) != null) {
      await s.profile.useItem(key);
    }
  }

  Future<void> _refill(
    BlockPuzzleServices s,
    BlockPuzzleGame game,
    BoostDef def,
  ) async {
    final choice = await showBoostRefillSheet(
      context,
      services: s,
      def: def,
      adRefillsLeft: game.state.adRefillsLeft,
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case RefillChoice.coins:
        if (await s.profile.buyItem(def.key)) {
          _snack('Got 1 ${def.name}.');
        }
      case RefillChoice.shop:
        await Navigator.of(context).pushNamed(BlockPuzzleRoutes.shop);
      case RefillChoice.ad:
        if (game.state.adRefillsLeft <= 0) return;
        final ok =
            s.profile.data.adsRemoved ||
            await s.ads.showRewarded(BlockPuzzleAdPlacement.boostRefill);
        if (!mounted) return;
        if (ok && game.state.takeAdRefill()) {
          await s.profile.addItem(def.key);
          game.onChanged?.call();
          _snack('Got 1 ${def.name}.');
        } else {
          _snack('No ad available right now. Try again in a moment.');
        }
    }
  }

  /// "Careful" once the board is over 70% full; re-armed when it clears out.
  void _warnIfCrowded(BlockPuzzleGame game) {
    final b = game.state.board;
    final crowded = b.filledCount > b.size * b.size * 0.7;
    if (crowded && !_warned) _audio.voice('careful');
    _warned = crowded;
  }

  /// Narrator line for a placement that cleared lines; [PlaceOutcome.combo] is 1 for none.
  void _praise(PlaceOutcome o) {
    final String? line;
    if (o.linesCleared == 0) {
      line = null;
    } else if (o.linesCleared >= 4) {
      line = 'incredible';
    } else if (o.combo >= 5) {
      line = 'unstoppable';
    } else if (o.combo >= 3) {
      line = 'combo';
    } else if (o.linesCleared == 3) {
      line = 'excellent';
    } else if (o.linesCleared == 2) {
      line = 'great';
    } else if (o.combo >= 2) {
      line = 'nice';
    } else {
      line = null;
    }
    if (line != null) _audio.voice(line);
  }

  Future<void> _finishGame(BlockPuzzleServices s) async {
    if (_recorded) return;
    _recorded = true;
    final g = _game!.state;
    final unlocked = await s.profile.recordGameFinished(
      GameSummary(
        score: g.score,
        linesCleared: g.linesClearedTotal,
        piecesPlaced: g.piecesPlaced,
        maxCombo: g.maxComboReached,
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

  Future<void> _showGameOver(BlockPuzzleServices s) async {
    if (_dialogOpen || !mounted) return;
    _dialogOpen = true;
    final game = _game!;
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (ctx) => GameOverPanel(
        key: TestIds.gameOverDialog,
        panelKey: TestIds.gameOverPanel,
        viewKey: TestIds.gameOverView,
        title: 'Game over',
        shareButton: GameOverButton(
          key: TestIds.gameOverShare,
          kind: GameOverButtonKind.ghost,
          fontSize: _kSmallFont,
          padding: _kSmallPadding,
          icon: Icons.share,
          semanticLabel: 'Share',
          onPressed: () async {
            final png = await captureShareCard(
              ctx,
              ShareCardData(
                gameName: s.config.displayName,
                headline: 'Score',
                big: '${game.state.score}',
                best: game.state.bestScore,
                theme: game.theme,
              ),
            );
            await s.share.shareScore(score: game.state.score, image: png);
          },
        ),
        details: [
          Text(
            'Score ${game.state.score}',
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          Text('Best ${game.state.bestScore}'),
          if (!s.profile.data.adsRemoved)
            RemoveAdsPill(
              key: TestIds.gameOverRemoveAds,
              onPressed: () =>
                  Navigator.of(ctx).pushNamed(BlockPuzzleRoutes.shop),
            ),
          TextButton.icon(
            key: TestIds.gameOverBestMove,
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('Show best move'),
            onPressed: () => showDialog<void>(
              context: ctx,
              builder: (_) => BestMoveDialog(
                best: BestMoveSolver.solve(
                  game.state.trayStartBoard,
                  game.state.trayStartPieces,
                ),
                theme: game.theme,
              ),
            ),
          ),
          if (game.state.canRevive)
            Text(
              'Continues left: ${game.state.revivesRemaining}',
              key: TestIds.gameOverRevivesLeft,
            ),
        ],

        leadButton: game.state.canRevive
            ? GameOverButton(
                key: TestIds.gameOverRevive,
                kind: GameOverButtonKind.primary,
                icon: Icons.smart_display,
                label: '$continueLabel · ${game.state.revivesRemaining} left',
                fontSize: _kLargeFont,
                padding: _kLargePadding,
                onPressed: () => Navigator.pop(ctx, 'revive'),
              )
            : null,
        buttons: [
          GameOverButton(
            key: TestIds.gameOverRetry,
            kind: game.state.canRevive
                ? GameOverButtonKind.secondary
                : GameOverButtonKind.primary,
            icon: Icons.replay,
            label: 'Play again',
            fontSize: game.state.canRevive ? _kSmallFont : _kLargeFont,
            padding: game.state.canRevive ? _kSmallPadding : _kLargePadding,
            onPressed: () => Navigator.pop(ctx, 'retry'),
          ),
          GameOverButton(
            key: TestIds.gameOverHome,
            kind: GameOverButtonKind.ghost,
            icon: Icons.home,
            label: 'Home',
            fontSize: _kSmallFont,
            padding: _kSmallPadding,
            onPressed: () => Navigator.pop(ctx, 'home'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (!mounted) return;
    switch (action) {
      case 'revive':
        // Remove Ads owned: no ad at all, the continue is granted at once.
        if (s.profile.data.adsRemoved) {
          if (game.revive()) return;
          _showGameOver(s);
          return;
        }
        // Everyone else must earn the rewarded ad; never coins or a free continue.
        final earned = await s.ads.showRewarded(BlockPuzzleAdPlacement.revive);
        if (!mounted) return;
        if (earned && game.revive()) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No ad available right now. Try again in a moment.'),
          ),
        );
        _showGameOver(s);
      case 'retry':
        await _finishGame(s);
        await s.ads.maybeShowInterstitialAfterGameOver();
        if (!mounted) return;
        _recorded = false;
        game.restart();
        _warned = false;
        _audio.voice('go');
      default:
        await _finishGame(s);
        if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = BlockPuzzleServicesScope.of(context);
    final game = _ensureGame(s);
    final scaffold = Scaffold(
      body: ThemeBackground(
        theme: game.theme,
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  // Invisible; the current theme id is its Semantics value (tests, bot).
                  Semantics(
                    key: TestIds.gameTheme,
                    identifier: 'game.theme',
                    value: game.theme.id,
                    child: const SizedBox.shrink(),
                  ),
                  // One compact header row (back, score, best) plus a one-line streak
                  // strip, so the play area below keeps room for the piece tray.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Score is centred on the screen, independent of the side buttons.
                        _ScorePill(score: game.state.score),
                        Row(
                          textDirection: s.profile.data.leftHanded
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          children: [
                            IconButton.filledTonal(
                              key: TestIds.gameBack,
                              icon: Icon(
                                s.profile.data.leftHanded
                                    ? Icons.chevron_right
                                    : Icons.chevron_left,
                              ),
                              onPressed: _askPause,
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x0FFFFFFF),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFFFFC145),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Builder(
                                    builder: (context) => Text(
                                      '${game.state.bestScore}',
                                      key: TestIds.gameBest,
                                      style: TextStyle(
                                        color: HudColors.of(context).text,
                                        fontWeight: FontWeight.bold,
                                        shadows: HudColors.of(context).shadows,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _StreakBar(
                    streak: s.profile.displayStreak,
                    combo: game.state.comboStreak,
                    rushLeft: game.state.rushLeft,
                    showStreak: s.config.streaksEnabled,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        // Same geometry the game uses: the boost row sits in the free
                        // strip above the board, so the board and tray do not move.
                        final geo = PuzzleLayout(box.maxWidth, box.maxHeight);
                        final rowTop = max(
                          0.0,
                          (geo.boardTop - 4 - boostButtonSize) / 2,
                        );
                        final armed = game.targeting;
                        return Stack(
                          children: [
                            GameWidget<BlockPuzzleGame>(
                              key: TestIds.gameWidget,
                              game: game,
                            ),
                            if (armed != null)
                              // Absorbs every touch while targeting: no piece drags.
                              Positioned.fill(
                                child: Listener(
                                  key: TestIds.gameItemTarget,
                                  behavior: HitTestBehavior.opaque,
                                  onPointerDown: (e) =>
                                      game.targetCell = game.layout.cellAt(
                                        e.localPosition.dx,
                                        e.localPosition.dy,
                                      ),
                                  onPointerMove: (e) =>
                                      game.targetCell = game.layout.cellAt(
                                        e.localPosition.dx,
                                        e.localPosition.dy,
                                      ),
                                  onPointerUp: (e) =>
                                      _applyTarget(s, game, e.localPosition),
                                  onPointerCancel: (_) =>
                                      game.targetCell = null,
                                ),
                              ),
                            Positioned(
                              top: rowTop,
                              left: 0,
                              right: 0,
                              child: ListenableBuilder(
                                listenable: s.profile,
                                builder: (context, _) => Row(
                                  key: TestIds.gameItemRow,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  spacing: 10,
                                  children: [
                                    for (final def in Boosts.all)
                                      BoostButton(
                                        def: def,
                                        count: s.profile.itemCount(def.key),
                                        armed: armed == def.id,
                                        enabled:
                                            game.state.canUseBoost(def.id) &&
                                            !game.state.isGameOver,
                                        onTap: () => _onBoostTap(s, game, def),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (armed != null)
                              Positioned(
                                bottom: 2,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: TargetChip(
                                    onCancel: game.cancelTargeting,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  KeyedSubtree(
                    key: TestIds.gameBanner,
                    child: s.ads.buildBanner(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    // Back (the system button and the arrow) asks Resume or Exit instead of leaving.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _askPause();
      },
      child: scaffold,
    );
  }
}

/// Score in a glowing outlined pill.
class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      alignment: Alignment.center,
      padding: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF2EC4B6), width: 1.5),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x18FFFFFF), Color(0x06FFFFFF)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x552EC4B6), blurRadius: 18)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$score',
            key: TestIds.gameScore,
            style: TextStyle(
              color: HudColors.of(context).text,
              fontSize: 30,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              shadows: HudColors.of(context).shadows,
            ),
          ),
          Text(
            'SCORE',
            key: TestIds.gameScoreLabel,
            style: TextStyle(
              fontSize: 9,
              height: 1,
              letterSpacing: 3,
              color: HudColors.of(context).subtle,
              shadows: HudColors.of(context).shadows,
            ),
          ),
        ],
      ),
    );
  }
}

/// Streak (daily play streak) and current combo.
class _StreakBar extends StatelessWidget {
  const _StreakBar({
    required this.streak,
    required this.combo,
    required this.rushLeft,
    required this.showStreak,
  });
  final int streak;
  final int combo;
  final int rushLeft;
  final bool showStreak;

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[
      if (showStreak)
        Row(
          key: TestIds.gameStreak,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_fire_department,
              size: 16,
              color: Color(0xFFFF6B5E),
            ),
            const SizedBox(width: 4),
            Text('Day $streak streak'),
          ],
        ),
      if (combo > 0) Text('Combo x$combo', key: TestIds.gameCombo),
      // Always present: Semantics value = placements left (0 when off).
      Semantics(
        key: TestIds.gameRush,
        identifier: 'game.rush',
        value: '$rushLeft',
        child: rushLeft <= 0
            ? const SizedBox.shrink()
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0x33FFC928),
                  border: Border.all(color: const Color(0xFFFFC928)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'GOLD RUSH x2 · $rushLeft',
                  style: TextStyle(
                    color: HudColors.of(context).text,
                    fontWeight: FontWeight.w700,
                    shadows: HudColors.of(context).shadows,
                  ),
                ),
              ),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: DefaultTextStyle(
        style: TextStyle(
          color: HudColors.of(context).text,
          fontSize: 13,
          shadows: HudColors.of(context).shadows,
        ),
        // Wrap, so streak + combo + Gold Rush never overflow a narrow screen.
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 14,
          runSpacing: 2,
          children: parts,
        ),
      ),
    );
  }
}
