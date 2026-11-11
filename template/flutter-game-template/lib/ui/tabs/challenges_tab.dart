import 'package:flutter/material.dart';

import '../../core/profile/child_profile.dart';
import '../../core/services.dart';
import '../../engine/engine.dart';
import '../kit/ds_bars.dart';
import '../kit/ds_buttons.dart';
import '../test_ids.dart';
import '../theme/app_theme.dart';

/// Challenges (Game mode): learning goals that pay stars and a few coins (paid by the rewards
/// engine as items are passed, within the weekly coin cap), and the daily challenges to claim.
class ChallengesTab extends StatelessWidget {
  const ChallengesTab({super.key, required this.child});
  final ChildProfile child;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    final s = ServicesScope.of(context);
    final cfg = s.config.rewards;
    final r = child.progress.rewards;
    final today = s.profile.today;
    final todayPasses = r.todayDay == today ? r.todayPasses : 0;
    final weekPasses = r.weekIndex == weekOfDay(today) ? r.weekPasses : 0;
    final daily = s.profile.challenges;
    Widget goal(String id, String title, int done, int target, int coins) {
      final shown = done.clamp(0, target);
      return DsCard(
        id: 'goal.$id',
        child: Column(
          key: TestIds.challengeGoal(id),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: t.styles['subheading']!),
            SizedBox(height: t.sp('xs')),
            Text(
              '$shown of $target done'
              '${cfg.starsEnabled ? ', a star for each new one' : ''}'
              ', +$coins coins when you finish',
              style: t.styles['body']!,
            ),
            SizedBox(height: t.sp('sm')),
            DsProgressBar(
              id: 'goal.$id',
              value: shown / target,
              semanticLabel: title,
            ),
          ],
        ),
      );
    }

    return ListView(
      key: TestIds.challengesTab,
      padding: EdgeInsets.all(t.sp('lg')),
      children: [
        Semantics(
          header: true,
          child: Text('Challenges', style: t.styles['title']!),
        ),
        SizedBox(height: t.sp('md')),
        goal(
          'daily',
          'Today\'s goal',
          todayPasses,
          cfg.dailyGoalItems,
          cfg.dailyGoalCoins,
        ),
        SizedBox(height: t.sp('md')),
        goal(
          'weekly',
          'This week\'s goal',
          weekPasses,
          cfg.weeklyGoalItems,
          cfg.weeklyGoalCoins,
        ),
        for (final c in daily) ...[
          SizedBox(height: t.sp('md')),
          DsCard(
            id: 'challenge.${c.id}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.description, style: t.styles['subheading']!),
                SizedBox(height: t.sp('sm')),
                DsProgressBar(
                  id: 'challenge.${c.id}',
                  value: c.progress / c.target,
                  thin: true,
                  semanticLabel: c.description,
                ),
                SizedBox(height: t.sp('sm')),
                KeyedSubtree(
                  key: TestIds.challengeClaim(c.id),
                  child: DsButton(
                    id: 'claim.${c.id}',
                    label: c.claimed ? 'Done' : 'Claim +${c.reward} coins',
                    onPressed: c.claimable
                        ? () => s.profile.claimChallenge(c.id)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
