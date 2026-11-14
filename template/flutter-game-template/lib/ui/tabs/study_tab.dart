import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/profile/child_profile.dart';
import '../../core/services.dart';
import '../../engine/engine.dart';
import '../kit/ds_bars.dart';
import '../kit/ds_cards.dart';
import '../kit/ds_chips.dart';
import '../mistakes_round.dart';
import '../quick_quiz_screen.dart';
import '../test_ids.dart';
import '../theme/app_theme.dart';
import '../theme/design_scope.dart';
import 'tab_data.dart';

/// Study mode pages: Learn, Progress and Revise (the bottom bar picks one with [page]).
/// Practice is untimed, uses the Quick quiz in study mode and shows the explanation after
/// every answer. Accuracy shows only in apps that allow it (not Scout).
class StudyTab extends StatefulWidget {
  const StudyTab({
    super.key,
    required this.child,
    required this.page,
    this.loaders,
  });
  final ChildProfile child;

  /// `learn`, `progress` or `revise`.
  final String page;
  final TabLoaders? loaders;

  @override
  State<StudyTab> createState() => _StudyTabState();
}

class _StudyData {
  const _StudyData(this.open, this.packs);
  final List<PoolItem> open;
  final List<LoadedPack> packs;
}

typedef _Topic = ({
  String subject,
  int year,
  String topic,
  List<PoolItem> items,
});

class _StudyTabState extends State<StudyTab> {
  Future<_StudyData>? _data;

  TabLoaders get _loaders => widget.loaders ?? TabLoaders.of(context);

  Future<_StudyData> _load() async => _StudyData(
    await _loaders.openItems(widget.child.id),
    await _loaders.packs(),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= _load();
  }

  void _reload() => setState(() => _data = _load());

  /// Starts an untimed practice round on [pool] (default: all open items).
  Future<void> _practice(
    _StudyData d, {
    required String subject,
    required int year,
    String? topic,
    List<PoolItem>? pool,
  }) async {
    final s = ServicesScope.of(context);
    final nav = Navigator.of(context);
    final child = s.profile.children.firstWhere((c) => c.id == widget.child.id);
    final session = QuizSession.start(
      open: pool ?? d.open,
      progress: child.progress,
      packs: d.packs,
      rewardsConfig: s.config.rewards,
      subject: subject,
      year: year,
      today: s.profile.today,
      random: Random(),
      types: quickQuizGame.itemTypes,
      topic: topic,
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
                s.profile.setChildProgress(child.id, sess.progress),
            onExit: () {
              if (nav.mounted) nav.pop();
            },
          ),
        ) as Widget,
      ),
    );
    if (mounted) _reload();
  }

  /// Items in "Today's review" (the same set the round draws from), capped for the screen.
  int _mistakeCount(_StudyData d) {
    final s = ServicesScope.of(context);
    return reviewCount(
      _progressData,
      d.open,
      flash:
          DesignScope.bundleOf(context)?.app.practisesWithFlashCards ?? false,
      today: s.profile.today,
      spaced: s.profile.spacedReview,
    );
  }

  Widget _mistakesEntry(_StudyData d) {
    final t = ThemeTokens.of(context);
    final count = _mistakeCount(d);
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: t.sp('md')),
      child: MistakesEntry(
        count: count,
        onStart: () async {
          await startMistakesRound(
            context,
            childId: widget.child.id,
            open: d.open,
            packs: d.packs,
            mode: MiniGameMode.study,
          );
          if (mounted) _reload();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    final title = switch (widget.page) {
      'progress' => 'Progress',
      'revise' => 'Revise',
      _ => 'Learn',
    };
    return FutureBuilder<_StudyData>(
      future: _data,
      builder: (context, snap) {
        final d = snap.data;
        return ListView(
          key: switch (widget.page) {
            'progress' => TestIds.progressTab,
            'revise' => TestIds.reviseTab,
            _ => TestIds.learnTab,
          },
          padding: EdgeInsets.all(t.sp('lg')),
          children: [
            Semantics(
              header: true,
              child: Text(title, style: t.styles['title']!),
            ),
            SizedBox(height: t.sp('md')),
            if (d != null)
              ...switch (widget.page) {
                'progress' => _progress(context, d),
                'revise' => _revise(context, d),
                _ => _learn(context, d),
              },
          ],
        );
      },
    );
  }

  // ---- shared helpers -------------------------------------------------------------------

  String _name(_StudyData d, String subject, int year, String topic) =>
      topicDisplayName(d.packs, subject, year, topic);

  String _keyName(_StudyData d, String key) {
    final k = splitTopicKey(key);
    return _name(d, k.subject, k.year, k.topic);
  }

  ChildProgress get _progressData {
    final s = ServicesScope.of(context);
    return s.profile.children
        .firstWhere((c) => c.id == widget.child.id, orElse: () => widget.child)
        .progress;
  }

  bool get _showAccuracy =>
      DesignScope.bundleOf(context)?.app.showsAccuracy ?? true;

  /// Topics of the open items, by year then subject then topic.
  List<_Topic> _topics(_StudyData d) {
    final by = <String, List<PoolItem>>{};
    for (final p in d.open) {
      by.putIfAbsent(topicKey(p.subject, p.year, p.topic), () => []).add(p);
    }
    final keys = by.keys.toList()
      ..sort((a, b) {
        final c = splitTopicKey(a).year.compareTo(splitTopicKey(b).year);
        return c != 0 ? c : a.compareTo(b);
      });
    return [
      for (final k in keys)
        (
          subject: splitTopicKey(k).subject,
          year: splitTopicKey(k).year,
          topic: splitTopicKey(k).topic,
          items: by[k]!,
        ),
    ];
  }

  Widget _section(String text) {
    final t = ThemeTokens.of(context);
    return Padding(
      padding: EdgeInsets.only(top: t.sp('lg'), bottom: t.sp('sm')),
      child: Semantics(
        header: true,
        child: Text(text, style: t.styles['subheading']!),
      ),
    );
  }

  Widget _empty(String text) =>
      Text(text, style: ThemeTokens.of(context).styles['body']!);

  // ---- Learn ----------------------------------------------------------------------------

  List<Widget> _learn(BuildContext context, _StudyData d) {
    final t = ThemeTokens.of(context);
    final s = ServicesScope.of(context);
    final cfg = s.config.rewards;
    final progress = _progressData;
    final r = progress.rewards;
    final todayPasses = r.todayDay == s.profile.today ? r.todayPasses : 0;
    final topics = _topics(d);
    final reviseKey = progress.topicToRevise(pool: d.open);
    final next = reviseKey != null
        ? splitTopicKey(reviseKey)
        : (topics.isEmpty
              ? null
              : (
                  subject: topics.first.subject,
                  year: topics.first.year,
                  topic: topics.first.topic,
                ));
    final extra = [
      for (final lp in d.packs)
        if (lp.pack.isExtra) lp,
    ];
    int? lastYear;
    return [
      _mistakesEntry(d),
      DsCard(
        id: 'goal.learn',
        child: Column(
          key: TestIds.learnGoal,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's goal", style: t.styles['subheading']!),
            SizedBox(height: t.sp('xs')),
            Text(
              '${todayPasses.clamp(0, cfg.dailyGoalItems)} of '
              '${cfg.dailyGoalItems} done',
              style: t.styles['body']!,
            ),
            SizedBox(height: t.sp('sm')),
            DsProgressBar(
              id: 'goal.learn',
              value: (todayPasses / cfg.dailyGoalItems).clamp(0, 1).toDouble(),
              thin: true,
              semanticLabel: "Today's goal",
            ),
          ],
        ),
      ),
      SizedBox(height: t.sp('md')),
      if (next != null)
        DsSuggestedCard(
          id: 'learn',
          eyebrow: 'Try next',
          title: _name(d, next.subject, next.year, next.topic),
          subtitle: reviseKey != null
              ? 'A few to practise again'
              : 'Pick up where you left off',
          actionLabel: 'Study',
          onTap: () => _practice(
            d,
            subject: next.subject,
            year: next.year,
            topic: next.topic,
          ),
        ),
      if (topics.isEmpty) _empty('Topics will show here.'),
      for (final tp in topics) ...[
        if (tp.year != lastYear) _section('Year ${lastYear = tp.year}'),
        Padding(
          padding: EdgeInsets.only(bottom: t.sp('md')),
          child: _topicCard(d, tp),
        ),
      ],
      if (extra.isNotEmpty) ...[
        _section('Extra packs'),
        for (final lp in extra)
          Padding(
            padding: EdgeInsets.only(bottom: t.sp('md')),
            child: DsPackCard(
              id: lp.pack.id,
              title: lp.pack.title,
              fullUnlocked: !lp.previewOnly,
              onTap: () => _practice(
                d,
                subject: lp.pack.subject,
                year: lp.pack.year,
                pool: [
                  for (final p in d.open)
                    if (p.packId == lp.pack.id) p,
                ],
              ),
            ),
          ),
      ],
    ];
  }

  Widget _topicCard(_StudyData d, _Topic tp) {
    final progress = _progressData;
    final key = topicKey(tp.subject, tp.year, tp.topic);
    final r = progress.topics[key] ?? const TopicResult();
    final ids = {for (final p in tp.items) p.id};
    final total = tp.items.length;
    final passed = min(r.passed, total);
    return DsTopicCard(
      id: key,
      title: _name(d, tp.subject, tp.year, tp.topic),
      subject: tp.subject,
      passed: passed,
      total: total,
      mastery: masteryOf(
        passed: passed,
        total: total,
        answers: r.answers,
        correct: r.correct,
      ),
      toRevise: progress.mistakeIds.where(ids.contains).length,
      accuracyPercent: r.accuracy == null ? null : (r.accuracy! * 100).round(),
      showAccuracy: _showAccuracy,
      onTap: () =>
          _practice(d, subject: tp.subject, year: tp.year, topic: tp.topic),
    );
  }

  // ---- Progress -------------------------------------------------------------------------

  List<Widget> _progress(BuildContext context, _StudyData d) {
    final t = ThemeTokens.of(context);
    final s = ServicesScope.of(context);
    final progress = _progressData;
    final topics = _topics(d);
    final stars = s.config.rewards.starsEnabled;
    return [
      if (stars)
        Row(
          children: [
            DsStatChip(
              id: 'progress.stars',
              icon: 'star',
              value: '${progress.rewards.stars}',
              semanticLabel: '${progress.rewards.stars} stars earned',
            ),
          ],
        ),
      if (topics.isEmpty) _empty('Your progress will show here.'),
      for (final tp in topics) ...[
        SizedBox(height: t.sp('md')),
        _progressCard(d, tp, stars),
      ],
    ];
  }

  Widget _progressCard(_StudyData d, _Topic tp, bool stars) {
    final t = ThemeTokens.of(context);
    final progress = _progressData;
    final key = topicKey(tp.subject, tp.year, tp.topic);
    final r = progress.topics[key] ?? const TopicResult();
    final total = tp.items.length;
    final passed = min(r.passed, total);
    final counts = ReleaseEngine.counts(progress, d.packs, tp.subject, tp.year);
    final earned = progress.rewards.paid.contains('topic:$key');
    final lines = [
      '$passed of $total passed',
      '${total - passed} still to pass',
      counts.notYetOpen > 0
          ? 'Next release: more questions open soon'
          : 'Everything is open',
    ];
    return DsCard(
      id: 'progress.$key',
      semanticLabel: [
        _name(d, tp.subject, tp.year, tp.topic),
        ...lines,
        if (stars && earned) 'star earned',
      ].join(', '),
      child: Column(
        key: TestIds.progressTopic(key),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _name(d, tp.subject, tp.year, tp.topic),
            style: t.styles['heading']!,
          ),
          SizedBox(height: t.sp('sm')),
          DsProgressBar(
            id: 'progress.$key',
            value: total == 0 ? 0 : passed / total,
            semanticLabel:
                '${_name(d, tp.subject, tp.year, tp.topic)} progress',
          ),
          SizedBox(height: t.sp('sm')),
          for (final l in lines)
            Text(l, style: t.styles['caption']!.copyWith(color: t.textMuted)),
          if (_showAccuracy && r.accuracy != null)
            Text(
              '${(r.accuracy! * 100).round()}% correct',
              style: t.styles['caption']!.copyWith(color: t.textMuted),
            ),
          if (stars)
            Padding(
              padding: EdgeInsets.only(top: t.sp('xs')),
              child: DsStatChip(
                id: 'progress.star.$key',
                icon: 'star',
                value: earned ? '1' : '0',
                semanticLabel: earned ? 'Star earned' : 'Star not earned yet',
              ),
            ),
        ],
      ),
    );
  }

  // ---- Revise ---------------------------------------------------------------------------

  List<Widget> _revise(BuildContext context, _StudyData d) {
    final t = ThemeTokens.of(context);
    final mistakes = _progressData.mistakeIds.toSet();
    final byTopic = <String, List<PoolItem>>{};
    for (final p in d.open) {
      if (mistakes.contains(p.id)) {
        byTopic
            .putIfAbsent(topicKey(p.subject, p.year, p.topic), () => [])
            .add(p);
      }
    }
    if (byTopic.isEmpty) {
      return [
        if (_mistakeCount(d) == 0) const MistakesEmpty() else _mistakesEntry(d),
      ];
    }
    final entries = byTopic.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return [
      _mistakesEntry(d),
      for (final e in entries)
        Padding(
          padding: EdgeInsets.only(bottom: t.sp('md')),
          child: DsCard(
            id: 'revise.${e.key}',
            onTap: () {
              final k = splitTopicKey(e.key);
              _practice(
                d,
                subject: k.subject,
                year: k.year,
                topic: k.topic,
                pool: e.value,
              );
            },
            semanticLabel: '${_keyName(d, e.key)}, ${e.value.length} to revise',
            child: Column(
              key: TestIds.reviseTopic(e.key),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_keyName(d, e.key), style: t.styles['heading']!),
                SizedBox(height: t.sp('xs')),
                DsLabelChip(label: '${e.value.length} to revise'),
              ],
            ),
          ),
        ),
    ];
  }
}
