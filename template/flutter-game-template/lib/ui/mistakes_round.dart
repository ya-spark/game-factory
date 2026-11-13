import 'package:flutter/material.dart';

import '../core/services.dart';
import '../engine/engine.dart';
import 'kit/ds_cards.dart';
import 'minigames/flash_review_screen.dart';
import 'quick_quiz_screen.dart';
import 'test_ids.dart';
import 'theme/app_theme.dart';
import 'theme/design_scope.dart';

/// The items one "Practise my mistakes" round would use: open items in the notebook, oldest
/// first, at most [mistakeRoundSize]. Quick quiz plays multiple choice only, so the quiz round
/// skips other item types; Flash review (Scout) plays any type.
List<PoolItem> mistakeRoundItems(
  ChildProgress progress,
  List<PoolItem> open, {
  required bool flash,
}) => progress.mistakeRound([
  for (final p in open)
    if (flash || quickQuizPlays(p)) p,
]);

/// Home entry (Game mode and Study mode): shown only when at least one item needs revising.
/// It names the count and never a coin price. Otherwise nothing is drawn.
class MistakesEntry extends StatelessWidget {
  const MistakesEntry({super.key, required this.count, required this.onStart});
  final int count;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return KeyedSubtree(
      key: TestIds.mistakesEntry,
      child: DsSuggestedCard(
        id: 'mistakes',
        eyebrow: 'Practise my mistakes',
        title: count == 1 ? '1 to practise' : '$count to practise',
        subtitle: 'A short round, no rush',
        actionLabel: 'Start',
        onTap: onStart,
      ),
    );
  }
}

/// Empty state for the Revise page.
class MistakesEmpty extends StatelessWidget {
  const MistakesEmpty({super.key});

  @override
  Widget build(BuildContext context) => Text(
    'Nothing to practise. Great work!',
    key: TestIds.mistakesEmpty,
    style: ThemeTokens.of(context).styles['body']!,
  );
}

/// Starts one round (up to 10 items from the mistakes notebook, across topics) and returns when
/// it ends. Scout uses Flash review cards, everyone else the Quick quiz; answers, accuracy and
/// stars are recorded as in any other round. Coins are paid in Game mode only.
Future<void> startMistakesRound(
  BuildContext context, {
  required String childId,
  required List<PoolItem> open,
  required List<LoadedPack> packs,
  required MiniGameMode mode,
}) async {
  final s = ServicesScope.of(context);
  final nav = Navigator.of(context);
  final flash =
      DesignScope.bundleOf(context)?.app.practisesWithFlashCards ?? false;
  final child = s.profile.children.firstWhere((c) => c.id == childId);
  final items = mistakeRoundItems(child.progress, open, flash: flash);
  if (items.isEmpty) return;
  final game = flash ? flashReviewGame : quickQuizGame;
  final session = QuizSession(
    items: items,
    progress: child.progress,
    packs: packs,
    rewardsConfig: s.config.rewards,
    today: s.profile.today,
    streakDays: s.profile.displayStreak,
    gameId: game.id,
  );
  await nav.push(
    MaterialPageRoute<void>(
      builder: (_) => KeyedSubtree(
        key: TestIds.mistakesRound,
        child: game.build(
          MiniGameContext(
            session: session,
            mode: flash ? MiniGameMode.study : mode,
            onAnswered: (r, sess) async {
              await s.profile.setChildProgress(childId, sess.progress);
              if (!flash && mode == MiniGameMode.game && r.coins > 0) {
                await s.profile.addCoins(r.coins);
              }
            },
            onExit: () {
              if (nav.mounted) nav.pop();
            },
          ),
        ) as Widget,
      ),
    ),
  );
}
