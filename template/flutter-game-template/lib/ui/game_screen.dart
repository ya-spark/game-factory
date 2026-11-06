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

/// Player-facing name of the second chance on the game over screen (rename it here only).
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
  Services? _services;
  Services? _runFlagOwner;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Tells Home (the tip of the day) that a run is on screen; cleared in dispose.
    _runFlagOwner =
        context.getInheritedWidgetOfExactType<ServicesScope>()?.services
          ?..inRun = true;
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
    _runFlagOwner?.inRun = false;
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
      if (o.gems > 0) s.profile.addCoins(o.gems); // 1 coin per gem
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
        final earned = await s.ads.showRewarded(AdPlacement.revive);
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
                rushLeft: game.state.rushLeft,
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
              size: 18,
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
                  style: const TextStyle(
                    color: Color(0xFFFFE08A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
      ),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Color(0xFFCFE9EC), fontSize: 13),
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
