import 'dart:math';

import 'package:flutter/material.dart';

import '../core/profile/child_profile.dart';
import '../core/services.dart';
import '../engine/engine.dart';
import 'quick_quiz_screen.dart';
import 'tabs/tab_data.dart';
import 'test_ids.dart';

/// Whether "Include nickname" starts on in the shared summary. Off by default; a game for
/// older players turns it on.
const bool shareNicknameDefault = false;

/// Weekly report for one player: this week against last week, strongest topics, topics that
/// need attention (with a practice button) and a plain-text summary to share. Read from the
/// device only; nothing is sent anywhere except through the system share sheet the grown-up
/// opens. Used by the grown-ups' area and the Progress page.
class ChildReport extends StatefulWidget {
  const ChildReport({super.key, required this.child});
  final ChildProfile child;

  @override
  State<ChildReport> createState() => _ChildReportState();
}

class _ChildReportState extends State<ChildReport> {
  Future<List<LoadedPack>>? _packs;
  bool _name = shareNicknameDefault;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _packs ??= TabLoaders.of(context).packs();
  }

  Widget _week(BuildContext context, String title, WeekFigures w, Key key) {
    final style = Theme.of(context).textTheme;
    final acc = w.accuracyPercent;
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title (${ProgressReport.dayLabel(w.firstDay)} to '
          '${ProgressReport.dayLabel(w.lastDay)})',
          style: style.titleMedium,
        ),
        if (key == TestIds.reportThisWeek)
          Text(
            'Time played: ${PlayTimeLog.describe(w.playSeconds)}',
            key: TestIds.reportPlayTime,
          )
        else
          Text('Time played: ${PlayTimeLog.describe(w.playSeconds)}'),
        Text('Answers: ${w.answers}${acc == null ? '' : ' ($acc% right)'}'),
        Text('Newly passed: ${w.newlyPassed}'),
        Text('Days played: ${w.daysPlayed} of 7 (${w.longestRun} in a row)'),
      ],
    );
  }

  Future<void> _practise(String topicKey) async {
    final s = ServicesScope.of(context);
    final nav = Navigator.of(context);
    final id = widget.child.id;
    final learning = s.learning;
    if (learning == null) return;
    final open = await learning.openItems(id);
    final packs = await learning.loadedPacks();
    if (!mounted) return;
    final t = splitTopicKey(topicKey);
    final child = s.profile.children.firstWhere((c) => c.id == id);
    final session = QuizSession.start(
      open: open,
      progress: child.progress,
      packs: packs,
      rewardsConfig: s.config.rewards,
      subject: t.subject,
      year: t.year,
      today: s.profile.today,
      random: Random(),
      types: quickQuizGame.itemTypes,
      topic: t.topic,
      minPool: 1,
      streakDays: s.profile.displayStreak,
      gameId: quickQuizGame.id,
    );
    if (session == null) return;
    await nav.push(
      MaterialPageRoute<void>(
        builder: (_) => quickQuizGame.build(
          MiniGameContext(
            session: session,
            mode: MiniGameMode.study,
            onAnswered: (r, sess) async =>
                s.profile.setChildProgress(id, sess.progress),
            onExit: () {
              if (nav.mounted) nav.pop();
            },
          ),
        ) as Widget,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final style = Theme.of(context).textTheme;
    final child = widget.child;
    final today = s.profile.today;
    final topics = ProgressReport.topics(child.progress);
    final thisWeek = ProgressReport.week(child.activity, child.playTime, today);
    final lastWeek = ProgressReport.week(
      child.activity,
      child.playTime,
      today,
      weeksAgo: 1,
    );
    return FutureBuilder<List<LoadedPack>>(
      future: _packs,
      builder: (context, snap) {
        final packs = snap.data ?? const <LoadedPack>[];
        final strongest = ProgressReport.strongest(
          child.progress,
          ProgressReport.topicSizes(packs),
        );
        final attention = ProgressReport.needsAttention(
          child.progress,
          ProgressReport.itemTopics(packs),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _week(context, 'This week', thisWeek, TestIds.reportThisWeek),
            const SizedBox(height: 12),
            _week(context, 'Last week', lastWeek, TestIds.reportLastWeek),
            const SizedBox(height: 12),
            Column(
              key: TestIds.reportStrongest,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Strongest topics', style: style.titleMedium),
                Text(
                  strongest.isEmpty
                      ? 'None yet. They show here once a topic is mastered.'
                      : strongest.map((t) => t.name).join(', '),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              key: TestIds.reportAttention,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Needs attention', style: style.titleMedium),
                if (attention.isEmpty)
                  const Text('Nothing right now.')
                else
                  for (final a in attention)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${a.topic.name}: ${a.mistakes} '
                            '${a.mistakes == 1 ? 'item' : 'items'} to revisit',
                          ),
                        ),
                        TextButton(
                          key: TestIds.reportPractise(a.topic.key),
                          onPressed: () => _practise(a.topic.key),
                          child: const Text('Practise'),
                        ),
                      ],
                    ),
              ],
            ),
            SwitchListTile(
              key: TestIds.reportShareName,
              contentPadding: EdgeInsets.zero,
              title: const Text('Include nickname in the summary'),
              value: _name,
              onChanged: (v) => setState(() => _name = v),
            ),
            FilledButton.icon(
              key: TestIds.reportShare,
              icon: const Icon(Icons.ios_share),
              label: const Text("Share this week's summary"),
              onPressed: () async {
                final text = ProgressReport.shareText(
                  gameName: s.config.displayName,
                  thisWeek: thisWeek,
                  lastWeek: lastWeek,
                  strongest: strongest,
                  attention: attention,
                  nickname: _name ? child.nickname : null,
                );
                try {
                  await s.share.shareText(text);
                } on Object {
                  // no share sheet here (for example some browsers): nothing to do
                }
              },
            ),
            const SizedBox(height: 12),
            Text('Topics practised (all time)', style: style.titleMedium),
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
      },
    );
  }
}
