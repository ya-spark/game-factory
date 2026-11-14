import 'package:flutter/material.dart';

import '../core/services.dart';
import '../engine/engine.dart';
import 'kit/ds_cards.dart';
import 'minigames/flash_review_screen.dart';
import 'quick_quiz_screen.dart';
import 'test_ids.dart';
import 'theme/app_theme.dart';
import 'theme/design_scope.dart';

/// Everything "Today's review" could draw from, in round order: open mistakes first, then due
/// items (when [spaced]), most overdue first. Quick quiz plays multiple choice only, so the quiz
/// skips other item types; Flash review (Scout) plays any type.
List<PoolItem> reviewCandidates(
  ChildProgress progress,
  List<PoolItem> open, {
  required bool flash,
  required int today,
  required bool spaced,
}) => progress.reviewItems(
  [
    for (final p in open)
      if (flash || quickQuizPlays(p)) p,
  ],
  today: today,
  spaced: spaced,
);

/// The number on the Home entry: the candidates, never more than [reviewCountCap].
int reviewCount(
  ChildProgress progress,
  List<PoolItem> open, {
  required bool flash,
  required int today,
  required bool spaced,
}) => reviewCandidates(
  progress,
  open,
  flash: flash,
  today: today,
  spaced: spaced,
).length.clamp(0, reviewCountCap);

/// Home entry "Today's review" (Game mode and Study mode): shown only when at least one item is
/// due or needs revising. It names the count (capped at 20) and never a coin price. Otherwise
/// nothing is drawn.
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
        eyebrow: "Today's review",
        title: count == 1 ? '1 to say hello to' : '$count to say hello to',
        subtitle: 'Time to say hello to these again',
        actionLabel: 'Start',
        onTap: onStart,
      ),
    );
  }
}

/// Empty state for the Revise page: nothing due and nothing to practise.
class MistakesEmpty extends StatelessWidget {
  const MistakesEmpty({super.key});

  @override
  Widget build(BuildContext context) => Text(
    'Nothing due today. Great work!',
    key: TestIds.mistakesEmpty,
    style: ThemeTokens.of(context).styles['body']!,
  );
}

/// Starts one "Today's review" round (up to 10 items: mistakes first, then due items, across topics) and returns when
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
  final items = reviewCandidates(
    child.progress,
    open,
    flash: flash,
    today: s.profile.today,
    spaced: s.profile.spacedReview,
  ).take(mistakeRoundSize).toList();
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
