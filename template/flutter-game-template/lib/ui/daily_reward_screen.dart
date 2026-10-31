import 'package:flutter/material.dart';

import '../core/retention/daily_reward.dart';
import '../core/services.dart';
import 'test_ids.dart';

class DailyRewardScreen extends StatelessWidget {
  const DailyRewardScreen({super.key});

  static double _cardWidth(BuildContext context) =>
      ((MediaQuery.sizeOf(context).width - 32 - 24) / 4).clamp(60.0, 110.0);

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final profile = s.profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Daily reward')),
      body: ListenableBuilder(
        listenable: profile,
        builder: (context, _) {
          final today = profile.dailyRewardDayToClaim;
          final available = profile.dailyRewardAvailable;
          // Days before `today` in the cycle are done if the reward was claimed on that streak.
          final claimedThrough = available
              ? today
              : (today == 0 ? DailyRewardEngine.cycleLength : today);
          final inset = MediaQuery.viewPaddingOf(context).bottom;
          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + inset),
              child: Column(
                children: [
                  if (s.config.retention.streaks)
                    Text(
                      'Streak: ${profile.displayStreak} days  •  Freezes: ${profile.data.streak.freezes}',
                      key: TestIds.dailyStreak,
                    ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 0; i < DailyRewardEngine.cycleLength; i++)
                        SizedBox(
                          width: _cardWidth(context),
                          height: _cardWidth(context) / 0.8,
                          child: Card(
                            key: TestIds.dailyDay(i),
                            color: i < claimedThrough
                                ? Theme.of(context).colorScheme.primaryContainer
                                : (i == today && available
                                      ? Theme.of(context)
                                            .colorScheme
                                            .tertiaryContainer
                                      : null),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Day ${i + 1}'),
                                const Icon(
                                  Icons.monetization_on,
                                  color: Colors.amber,
                                ),
                                Text('${DailyRewardEngine.coinsByDay[i]}'),
                                if (i < claimedThrough)
                                  const Icon(Icons.check, size: 16),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: FilledButton(
                      key: TestIds.dailyClaim,
                      onPressed: available
                          ? () async {
                              final coins = await profile.claimDailyReward();
                              if (coins != null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('+$coins coins')),
                                );
                              }
                            }
                          : null,
                      child: Text(available ? 'Claim' : 'Come back tomorrow'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
