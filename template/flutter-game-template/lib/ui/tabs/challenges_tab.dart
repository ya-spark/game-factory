import 'package:flutter/material.dart';

import '../../core/profile/child_profile.dart';
import '../../core/services.dart';
import '../../engine/engine.dart';
import '../kit/ds_bars.dart';
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
    // Learning goals only: the puzzle challenges (combos, lines, score) are not part of the
    // learning profile. The streak goal is the next streak milestone the rewards engine pays.
    final streak = s.profile.displayStreak;
    final milestones = cfg.streakMilestones.keys.toList()..sort();
    final nextMilestone = milestones.firstWhere(
      (m) => m > streak,
      orElse: () => milestones.isEmpty ? 1 : milestones.last,
    );
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
        if (s.config.content.enabled) ...[
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
        ],
        SizedBox(height: t.sp('md')),
        goal(
          'streak',
          'Keep your streak going',
          streak,
          nextMilestone,
          cfg.streakMilestones[nextMilestone] ?? 0,
        ),
      ],
    );
  }
}
