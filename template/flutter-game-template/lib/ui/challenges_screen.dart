import 'package:flutter/material.dart';

import '../core/retention/achievements.dart';
import '../core/services.dart';
import 'test_ids.dart';
import 'widgets.dart';

class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final profile = s.profile;
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: const Text(
          '🏆 Challenges',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: KidColors.grape,
      ),
      body: Container(
        decoration: KidColors.background,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: profile,
            builder: (context, _) {
              final stats = profile.data.stats;
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  24 + MediaQuery.viewPaddingOf(context).bottom,
                ),
                children: [
                  if (s.config.retention.dailyChallenges) ...[
                    const _Heading('🎯 Daily challenges'),
                    for (final (i, c) in profile.challenges.indexed)
                      Card(
                        key: TestIds.challengeTile(i),
                        color: Colors.white,
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(
                            color: c.claimable ? KidColors.sun : Colors.white,
                            width: 3,
                          ),
                        ),
                        child: ListTile(
                          minVerticalPadding: 14,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          title: Text(
                            c.description,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: KidColors.ink,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                minHeight: 12,
                                color: KidColors.mint,
                                backgroundColor: const Color(0xFFE6E6F2),
                                value: (c.progress / c.target)
                                    .clamp(0, 1)
                                    .toDouble(),
                              ),
                            ),
                          ),
                          trailing: c.claimed
                              ? const Icon(
                                  Icons.check_circle,
                                  color: KidColors.mint,
                                  size: 36,
                                )
                              : FilledButton(
                                  key: TestIds.challengeClaim(c.id),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(72, 52),
                                    backgroundColor: KidColors.sun,
                                    foregroundColor: KidColors.ink,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(26),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  onPressed: c.claimable
                                      ? () => profile.claimChallenge(c.id)
                                      : null,
                                  child: Text('+${c.reward} 🪙'),
                                ),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                  if (s.config.retention.achievements) ...[
                    const _Heading('🌟 Achievements'),
                    for (final a in AchievementEngine.all)
                      ListTile(
                        key: TestIds.achievementTile(a.id),
                        tileColor: Colors.white70,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        minVerticalPadding: 12,
                        leading: Icon(
                          profile.data.unlockedAchievements.contains(a.id)
                              ? Icons.emoji_events
                              : Icons.lock_outline,
                          color:
                              profile.data.unlockedAchievements.contains(a.id)
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
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4, top: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w900,
        color: KidColors.ink,
      ),
    ),
  );
}
