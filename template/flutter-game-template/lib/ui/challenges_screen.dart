import 'package:flutter/material.dart';

import '../core/retention/achievements.dart';
import '../core/services.dart';
import 'test_ids.dart';

class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final profile = s.profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Challenges')),
      body: ListenableBuilder(
        listenable: profile,
        builder: (context, _) {
          final stats = profile.data.stats;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (s.config.retention.dailyChallenges) ...[
                Text(
                  'Daily challenges',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final (i, c) in profile.challenges.indexed)
                  Card(
                    key: TestIds.challengeTile(i),
                    child: ListTile(
                      title: Text(c.description),
                      subtitle: LinearProgressIndicator(
                        value: (c.progress / c.target).clamp(0, 1).toDouble(),
                      ),
                      trailing: c.claimed
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : FilledButton(
                              key: TestIds.challengeClaim(c.id),
                              onPressed: c.claimable
                                  ? () => profile.claimChallenge(c.id)
                                  : null,
                              child: Text('+${c.reward}'),
                            ),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              if (s.config.retention.achievements) ...[
                Text(
                  'Achievements',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final a in AchievementEngine.all)
                  ListTile(
                    key: TestIds.achievementTile(a.id),
                    leading: Icon(
                      profile.data.unlockedAchievements.contains(a.id)
                          ? Icons.emoji_events
                          : Icons.lock_outline,
                      color: profile.data.unlockedAchievements.contains(a.id)
                          ? Colors.amber
                          : null,
                    ),
                    title: Text(a.title),
                    subtitle: Text(
                      '${a.description}  (${a.valueIn(stats).clamp(0, a.target)}/${a.target})',
                    ),
                    trailing: Text('+${a.reward}'),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
