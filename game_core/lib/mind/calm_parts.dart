import 'package:flutter/material.dart';

import '../kit/keys/keys.dart';

import '../host/game_host.dart';
import 'mind_ids.dart';
import 'zen.dart';
import 'zen_scope.dart';

/// Parts shared by the calm games (Sudoku, Solitaire, Ball sort): the banner slot for the menu
/// and results screens (never in play) and the results view.

/// A banner for [placement] from the container (nothing when it has none).
class CalmBanner extends StatelessWidget {
  const CalmBanner({super.key, required this.game, required this.placement});
  final String game;
  final GameBannerSlot placement;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: MindIds.calmBanner(
      game,
      placement == GameBannerSlot.menu ? 'menu' : 'results',
    ),
    child: GameHostScope.of(context).banner(context, placement),
  );
}

/// Number of stars (0 to 3) for [score] against ascending [thresholds].
int starsFor(int score, List<int> thresholds) =>
    thresholds.where((t) => score >= t).length;

/// The results screen: a headline, the score and stars, Play again and Done, and the banner. The game
/// wires the keys (B-09): Enter or Space is again, Esc is Done; the buttons print them.
class CalmResults extends StatelessWidget {
  const CalmResults({
    super.key,
    required this.game,
    required this.title,
    required this.score,
    required this.thresholds,
    required this.onAgain,
    required this.onDone,
    this.detail,
    this.againLabel = 'Play again',
  });
  final String againLabel;
  final String game;
  final String title;
  final int score;
  final List<int> thresholds;
  final String? detail;
  final VoidCallback onAgain;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stars = starsFor(score, thresholds);
    if (ZenScope.of(context).zen) return _zen(context);
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    container: true,
                    label: 'Score $score. $stars of 3 stars.',
                    child: ExcludeSemantics(
                      child: Column(
                        children: [
                          Text(
                            'Score $score',
                            key: MindIds.calmResultStars(game),
                            style: theme.textTheme.titleLarge,
                          ),
                          Text(
                            '$stars of 3 stars',
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 8),
                    Text(detail!, textAlign: TextAlign.center),
                  ],
                  GameHostScope.of(context).achievementNote(context),
                  GameHostScope.of(context).leaderboardEntry(context, game),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton(
                        key: MindIds.calmControl(game, 'again'),
                        onPressed: onAgain,
                        child: Text(
                          keyedLabel(
                            context,
                            againLabel,
                            GameAction.action,
                            alsoSpace: true,
                          ),
                        ),
                      ),
                      OutlinedButton(
                        key: MindIds.calmControl(game, 'done'),
                        onPressed: onDone,
                        child: Text(
                          keyedLabel(context, 'Done', GameAction.exit),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        CalmBanner(game: game, placement: GameBannerSlot.postGame),
      ],
    );
  }

  /// Zen (M5): nothing counted. One line, Again and Done; the banner stays as in any run.
  Widget _zen(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ZenPolicy.resultsLine,
                    key: MindIds.zenResults(game),
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton(
                        key: MindIds.calmControl(game, 'again'),
                        onPressed: onAgain,
                        child: Text(
                          keyedLabel(
                            context,
                            againLabel,
                            GameAction.action,
                            alsoSpace: true,
                          ),
                        ),
                      ),
                      OutlinedButton(
                        key: MindIds.calmControl(game, 'done'),
                        onPressed: onDone,
                        child: Text(
                          keyedLabel(context, 'Done', GameAction.exit),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        CalmBanner(game: game, placement: GameBannerSlot.postGame),
      ],
    );
  }
}
