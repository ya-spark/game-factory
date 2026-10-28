import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ads/ad_service.dart';
import '../core/profile/profile_store.dart';
import '../core/services.dart';
import '../game/flame/block_puzzle_game.dart';
import 'test_ids.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.game});

  /// Injectable for tests (seeded generator).
  final BlockPuzzleGame? game;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  BlockPuzzleGame? _game;
  bool _recorded = false;
  bool _dialogOpen = false;

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

  Future<void> _showGameOver(Services s) async {
    if (_dialogOpen || !mounted) return;
    _dialogOpen = true;
    final game = _game!;
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        key: TestIds.gameOverDialog,
        title: const Text('Game over'),
        content: Text(
          'Score ${game.state.score}\nBest ${game.state.bestScore}',
        ),
        actions: [
          if (game.state.canRevive)
            FilledButton.icon(
              key: TestIds.gameOverRevive,
              icon: const Icon(Icons.smart_display),
              label: const Text('Revive (watch ad)'),
              onPressed: () => Navigator.pop(ctx, 'revive'),
            ),
          TextButton(
            key: TestIds.gameOverRetry,
            onPressed: () => Navigator.pop(ctx, 'retry'),
            child: const Text('Play again'),
          ),
          TextButton(
            key: TestIds.gameOverHome,
            onPressed: () => Navigator.pop(ctx, 'home'),
            child: const Text('Home'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (!mounted) return;
    switch (action) {
      case 'revive':
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
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    key: TestIds.gameBack,
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Column(
                    children: [
                      Text(
                        '${game.state.score}',
                        key: TestIds.gameScore,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text(
                        'Best ${game.state.bestScore}',
                        key: TestIds.gameBest,
                      ),
                    ],
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: GameWidget<BlockPuzzleGame>(
                key: TestIds.gameWidget,
                game: game,
              ),
            ),
            KeyedSubtree(key: TestIds.gameBanner, child: s.ads.buildBanner()),
          ],
        ),
      ),
    );
  }
}
