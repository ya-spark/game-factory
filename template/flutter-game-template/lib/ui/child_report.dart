import 'package:flutter/material.dart';

import '../core/profile/child_profile.dart';
import '../core/services.dart';
import '../engine/engine.dart';
import 'test_ids.dart';

/// Weekly time played, topics practised and accuracy by topic for one player. Read from the
/// device only; nothing is sent anywhere. Used by the grown-ups' area and the Progress page.
class ChildReport extends StatelessWidget {
  const ChildReport({super.key, required this.child});
  final ChildProfile child;

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final style = Theme.of(context).textTheme;
    final week = child.playTime.weekSeconds(s.profile.today);
    final topics = ProgressReport.topics(child.progress);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('This week', style: style.titleMedium),
        Text(
          'Time played: ${PlayTimeLog.describe(week)}',
          key: TestIds.reportPlayTime,
        ),
        const SizedBox(height: 12),
        Text('Topics practised', style: style.titleMedium),
        Text(
          topics.isEmpty
              ? 'None yet.'
              : '${topics.length} ${topics.length == 1 ? 'topic' : 'topics'}',
          key: TestIds.reportTopicsCount,
        ),
        const SizedBox(height: 12),
        Text('Accuracy by topic', style: style.titleMedium),
        if (topics.isEmpty) const Text('Answers will show here.'),
        for (final t in topics)
          Padding(
            key: TestIds.reportTopic(t.key),
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '${t.name}: ${t.accuracyPercent ?? 0}% right '
              '(${t.answers} ${t.answers == 1 ? 'answer' : 'answers'})',
            ),
          ),
      ],
    );
  }
}
