import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ads/ad_service.dart';
import '../core/profile/profile_store.dart';
import '../core/services.dart';
import '../game/flame/block_puzzle_game.dart';
import 'game_over_panel.dart';
import 'share_card.dart';
import 'test_ids.dart';
import 'widgets.dart';

/// Player-facing name of the second chance on the game over screen (rename it here only).
const String continueLabel = 'Continue';

/// Coins spent on a continue paid with coins (counts against the same per-run limit as an ad).
const int continueCoinCost = 50;

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
  Services? _services;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_services != null) return;
    final s = _services = ServicesScope.of(context);
    _applyAudio(s);
    s.audio.startAmbience(); // loops under the voice, ducked while it speaks
  }

  /// Pushes the saved sound settings to the audio service (applied immediately).
  void _applyAudio(Services s) {
    final d = s.profile.data;
    s.audio.apply(
      sound: d.soundOn,
      volume: d.masterVolume,
      ambience: d.ambience,
      voice: d.voiceOn,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final s = _services;
    if (s == null) return;
    if (state == AppLifecycleState.resumed) {
      s.audio.startAmbience();
    } else {
      s.audio.pauseAmbience();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _services?.audio.pauseAmbience();
    super.dispose();
  }

  BlockPuzzleGame _ensureGame(Services s) {
    final existing = _game;
    if (existing != null) return existing;
    final game =
        widget.game ?? BlockPuzzleGame(bestScore: s.profile.data.bestScore);
    game.onPlaced = (o) {
      if (s.profile.data.vibrationOn && o.linesCleared > 0) {
        HapticFeedback.mediumImpact();
      }
    };
    game.onChanged = () => setState(() {});
    game.onGameOver = () => _showGameOver(s);
    return _game = game;
  }

  Future<void> _finishGame(Services s) async {
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
    await s.leaderboard.submitScore(
      s.config.playGames.leaderboardHighScore,
      g.score,
    );
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

  /// Small choice shown when the player can afford coins: 'ad', 'coins' or null (dismissed).
  Future<String?> _askContinueChoice() => showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Continue?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: TestIds.gameOverContinueAd,
              icon: const Icon(Icons.smart_display),
              label: const Text('Watch an ad (free)'),
              onPressed: () => Navigator.pop(ctx, 'ad'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              key: TestIds.gameOverContinueCoins,
              icon: const CoinIcon(size: 20),
              label: const Text('Use $continueCoinCost coins'),
              onPressed: () => Navigator.pop(ctx, 'coins'),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _showGameOver(Services s) async {
    if (_dialogOpen || !mounted) return;
    _dialogOpen = true;
    final game = _game!;
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (ctx) => GameOverPanel(
        key: TestIds.gameOverDialog,
        title: 'Game over',
        details: [
          Text(
            'Score ${game.state.score}',
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          Text('Best ${game.state.bestScore}'),
          if (game.state.canRevive)
            Text(
              'Continues left: ${game.state.revivesRemaining}',
              key: TestIds.gameOverRevivesLeft,
            ),
        ],
        share: GameOverButton(
          key: TestIds.gameOverShare,
          kind: GameOverButtonKind.ghost,
          size: GameOverButtonSize.compact,
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
              ),
            );
            await s.share.shareScore(score: game.state.score, image: png);
          },
        ),
        again: GameOverButton(
          key: TestIds.gameOverRetry,
          kind: game.state.canRevive
              ? GameOverButtonKind.secondary
              : GameOverButtonKind.primary,
          size: game.state.canRevive
              ? GameOverButtonSize.regular
              : GameOverButtonSize.large,
          icon: Icons.replay,
          label: 'Play again',
          onPressed: () => Navigator.pop(ctx, 'retry'),
        ),
        home: GameOverButton(
          key: TestIds.gameOverHome,
          kind: GameOverButtonKind.ghost,
          icon: Icons.home,
          label: 'Home',
          onPressed: () => Navigator.pop(ctx, 'home'),
        ),
        cont: game.state.canRevive
            ? GameOverButton(
                key: TestIds.gameOverRevive,
                kind: GameOverButtonKind.primary,
                size: GameOverButtonSize.large,
                icon: Icons.smart_display,
                label: '$continueLabel · ${game.state.revivesRemaining} left',
                onPressed: () => Navigator.pop(ctx, 'revive'),
              )
            : null,
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
        var useCoins = false;
        if (s.profile.data.coins >= continueCoinCost) {
          final choice = await _askContinueChoice();
          if (!mounted) return;
          if (choice == null) {
            _showGameOver(s);
            return;
          }
          useCoins = choice == 'coins';
        }
        if (useCoins) {
          if (game.state.canRevive &&
              await s.profile.spendCoins(continueCoinCost)) {
            if (!mounted) return;
            if (game.revive()) return;
          }
          if (!mounted) return;
          _showGameOver(s);
          return;
        }
        final earned = await s.ads.showRewarded(AdPlacement.revive);
        if (!mounted) return;
        if (earned && game.revive()) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ad not available. Try again later.')),
        );
        _showGameOver(s);
      case 'retry':
        await _finishGame(s);
        await s.ads.maybeShowInterstitialAfterGameOver();
        if (!mounted) return;
        _recorded = false;
        game.restart();
      default:
        await _finishGame(s);
        if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final game = _ensureGame(s);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1),
            radius: 1.4,
            colors: [Color(0xFF1D4552), Color(0xFF0F2430), Color(0xFF0A1822)],
            stops: [0, 0.55, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
                // Left-handed: back button and best score swap sides.
                child: Row(
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
                      onPressed: () => Navigator.of(context).pop(),
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
                          Text(
                            '${game.state.bestScore}',
                            key: TestIds.gameBest,
                            style: const TextStyle(
                              color: Color(0xFFFFC145),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _ScorePill(score: game.state.score),
              Expanded(
                child: GameWidget<BlockPuzzleGame>(
                  key: TestIds.gameWidget,
                  game: game,
                ),
              ),
              _StreakBar(
                streak: s.profile.displayStreak,
                combo: game.state.comboStreak,
                showStreak: s.config.retention.streaks,
              ),
              const SizedBox(height: 6),
              KeyedSubtree(key: TestIds.gameBanner, child: s.ads.buildBanner()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Score in a glowing outlined pill.
class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 4),
        Container(
          width: 170,
          alignment: Alignment.center,
          padding: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFF2EC4B6), width: 1.5),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x18FFFFFF), Color(0x06FFFFFF)],
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x552EC4B6), blurRadius: 22),
            ],
          ),
          child: Text(
            '$score',
            key: TestIds.gameScore,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'SCORE',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 3,
            color: Color(0xFF7FB7BD),
          ),
        ),
      ],
    );
  }
}

/// Streak (daily play streak) and current combo.
class _StreakBar extends StatelessWidget {
  const _StreakBar({
    required this.streak,
    required this.combo,
    required this.showStreak,
  });
  final int streak;
  final int combo;
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
              size: 18,
              color: Color(0xFFFF6B5E),
            ),
            const SizedBox(width: 4),
            Text('Day $streak streak'),
          ],
        ),
      if (combo > 0) Text('Combo x$combo', key: TestIds.gameCombo),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Color(0xFFCFE9EC), fontSize: 13),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 14,
          children: parts,
        ),
      ),
    );
  }
}
