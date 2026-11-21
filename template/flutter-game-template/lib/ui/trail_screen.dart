import 'dart:math';

import 'package:flutter/material.dart';

import '../core/profile/child_profile.dart';
import '../core/services.dart';

import 'package:game_core/engine/engine.dart';

import 'quick_quiz_screen.dart';
import 'rules_dialog.dart';
import 'tabs/tab_data.dart';
import 'test_ids.dart';
import 'theme/app_theme.dart';

/// The skill trail: the rungs of the child's subject and year, in the order to learn them, with
/// stars for progress. "Continue" lets the app choose the rung and the game; a rung can also be
/// practised with a game the child picks, or skipped ahead to with a short check.
///
/// Games are the interface; only the answers move a rung (see `docs/VISION-education.md`).
class TrailScreen extends StatefulWidget {
  const TrailScreen({
    super.key,
    required this.child,
    required this.registry,
    required this.mode,
    this.autoOnly = false,
    this.showAccuracy = true,
    this.loader,
  });
  final ChildProfile child;
  final MiniGameRegistry registry;
  final MiniGameMode mode;

  /// A grown-up locked the app to Auto: no game or rung picking, no skipping ahead.
  final bool autoOnly;

  /// Whether a rung's accuracy is shown (not in Scout).
  final bool showAccuracy;

  /// Replaces loading from the learning service (tests).
  final Future<TrailData> Function()? loader;

  @override
  State<TrailScreen> createState() => _TrailScreenState();
}

/// What the trail needs: the rungs, the open items (with skill keys) and the packs.
class TrailData {
  TrailData(this.skills, this.open, this.packs);
  final SkillMap skills;
  final List<PoolItem> open;
  final List<LoadedPack> packs;
}

class _TrailScreenState extends State<TrailScreen> {
  Future<TrailData>? _data;
  String? _subject;

  Future<TrailData> _load() async {
    final custom = widget.loader;
    if (custom != null) return custom();
    final learning = ServicesScope.of(context).learning;
    if (learning == null) return TrailData(SkillMap.empty, const [], const []);
    final skills = await learning.skills();
    final open = await learning.openItems(widget.child.id);
    return TrailData(skills, open, await learning.loadedPacks());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= _load();
  }

  void _reload() => setState(() => _data = _load());

  ChildProfile get _child => ServicesScope.of(context).profile.children
      .firstWhere((c) => c.id == widget.child.id, orElse: () => widget.child);

  SkillRules get _rules => SkillRules.forYear(_child.year);

  List<TrailNode> _nodes(TrailData d, String subject) => Trail.build(
    subject: subject,
    year: _child.year ?? 0,
    skills: d.skills,
    progress: _child.progress,
    open: d.open,
    rules: _rules,
    today: ServicesScope.of(context).profile.today,
  );

  Set<String> get _unlocked =>
      ServicesScope.of(context).profile.data.unlockedGames.toSet();

  Future<void> _continue(TrailData d, String subject) async {
    final s = ServicesScope.of(context);
    final round = NextStep.auto(
      nodes: _nodes(d, subject),
      registry: widget.registry,
      open: d.open,
      progress: _child.progress,
      mode: widget.mode,
      unlocked: _unlocked,
      today: s.profile.today,
      random: Random(),
    );
    if (round == null) return;
    await _play(d, round);
  }

  Future<void> _play(TrailData d, TrailRound round) async {
    final s = ServicesScope.of(context);
    final nav = Navigator.of(context);
    final child = _child;
    final session = QuizSession(
      items: round.items,
      progress: child.progress,
      packs: d.packs,
      rewardsConfig: s.rewardsFor(child),
      today: s.profile.today,
      streakDays: s.profile.displayStreak,
      gameId: round.game.id,
      rules: _rules,
    );
    int? gameScore;
    await nav.push(
      MaterialPageRoute<void>(
        builder: (_) => RulesGate(
          gameId: round.game.id,
          childId: child.id,
          child: round.game.build(
            MiniGameContext(
              session: session,
              mode: widget.mode,
              onAnswered: (r, sess) async {
                await s.profile.setChildProgress(child.id, sess.progress);
                if (r.coins > 0) await s.profile.addCoins(r.coins);
              },
              onScore: (v) => gameScore = v,
              onExit: () async {
                final cur = s.profile.children.firstWhere(
                  (c) => c.id == child.id,
                );
                await s.profile.setChildProgress(
                  child.id,
                  cur.progress.recordScore(
                    round.game.id,
                    gameScore ?? session.report.correct * 10,
                  ),
                );
                if (nav.mounted) nav.pop();
              },
            ),
          ) as Widget,
        ),
      ),
    );
    if (mounted) _reload();
  }

  /// The skip-ahead check: five answers on the rung, four right to pass.
  Future<void> _skipAhead(TrailData d, TrailNode node) async {
    final s = ServicesScope.of(context);
    final nav = Navigator.of(context);
    final child = _child;
    final items = NextStep.checkItems(node, d.open, _rules, Random());
    if (items == null) return;
    final session = QuizSession(
      items: items,
      progress: child.progress,
      packs: d.packs,
      rewardsConfig: s.rewardsFor(child),
      today: s.profile.today,
      streakDays: s.profile.displayStreak,
      gameId: quickQuizGame.id,
      rules: _rules,
    );
    await nav.push(
      MaterialPageRoute<void>(
        builder: (_) => RulesGate(
          gameId: quickQuizId,
          childId: child.id,
          child: quickQuizGame.build(
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
      ),
    );
    final passed = SkipCheck.passed(session.report.correct, _rules);
    final cur = s.profile.children.firstWhere((c) => c.id == child.id);
    await s.profile.setChildProgress(
      child.id,
      SkipCheck.apply(
        cur.progress,
        node.skill,
        d.skills,
        passed: passed,
        day: s.profile.today,
        rules: _rules,
      ),
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: TestIds.trailCheckResult,
        title: Text(passed ? 'You jumped ahead' : 'Not this time'),
        content: Text(
          passed
              ? 'You already know this one. The steps before it are done too.'
              : 'Have a go at the steps in order, then try again tomorrow.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _sheet(TrailData d, TrailNode node, String subject) async {
    final t = ThemeTokens.of(context);
    final s = ServicesScope.of(context);
    final rungItems = [
      for (final p in d.open)
        if (p.skillKey == node.key) p,
    ];
    final games = widget.autoOnly
        ? const <MiniGame>[]
        : NextStep.gamesFor(
            registry: widget.registry,
            rungItems: rungItems,
            year: node.skill.year,
            mode: widget.mode,
            unlocked: _unlocked,
          );
    final canCheck =
        !widget.autoOnly &&
        node.state != SkillState.secure &&
        node.state != SkillState.mastered &&
        NextStep.checkItems(node, d.open, _rules, Random()) != null &&
        SkipCheck.canTry(_child.progress, node.skill, s.profile.today, _rules);
    final choice = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(t.sp('lg')),
          child: Column(
            key: TestIds.trailSheet,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(node.skill.name, style: t.styles['title']!),
              SizedBox(height: t.sp('xs')),
              Text(_stateLabel(node), style: t.styles['body']!),
              SizedBox(height: t.sp('md')),
              FilledButton(
                key: TestIds.trailPractise,
                onPressed: node.canPractise
                    ? () => Navigator.of(sheet).pop('practise')
                    : null,
                child: const Text('Practise'),
              ),
              if (games.length > 1) ...[
                SizedBox(height: t.sp('sm')),
                Text('Or choose a game', style: t.styles['subheading']!),
                for (final g in games)
                  OutlinedButton(
                    key: TestIds.trailGame(g.id),
                    onPressed: MiniGameRegistry.isPlayable(g, _unlocked)
                        ? () => Navigator.of(sheet).pop(g)
                        : null,
                    child: Text(g.title),
                  ),
              ],
              if (canCheck) ...[
                SizedBox(height: t.sp('sm')),
                OutlinedButton(
                  key: TestIds.trailSkip,
                  onPressed: () => Navigator.of(sheet).pop('skip'),
                  child: const Text('I already know this'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'skip') return _skipAhead(d, node);
    final game = choice is MiniGame
        ? choice
        : NextStep.autoGame(
            NextStep.gamesFor(
              registry: widget.registry,
              rungItems: rungItems,
              year: node.skill.year,
              mode: widget.mode,
              unlocked: _unlocked,
            ),
            _child.progress,
            _unlocked,
            Random(),
          );
    if (game == null) return;
    final round = NextStep.round(
      node: node,
      game: game,
      open: d.open,
      progress: _child.progress,
      today: s.profile.today,
      random: Random(),
    );
    if (round != null) await _play(d, round);
  }

  String _stateLabel(TrailNode n) {
    if (n.isLocked) return 'Opens when the step before is done';
    if (n.opensAsYouGo) return 'Opens as you go';
    return switch (n.state) {
      SkillState.unseen => 'Ready to start',
      SkillState.practising => 'Getting there',
      SkillState.secure => 'Secure',
      SkillState.mastered => 'Mastered',
      SkillState.locked => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    return Scaffold(
      key: TestIds.trailScreen,
      appBar: AppBar(title: const Text('Your trail')),
      body: SafeArea(
        child: FutureBuilder<TrailData>(
          future: _data,
          builder: (context, snap) {
            final d = snap.data;
            if (d == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final year = _child.year ?? 0;
            final subjects = [
              for (final sub in ['maths', 'english'])
                if (d.skills.skillsFor(sub, year).isNotEmpty) sub,
            ];
            if (subjects.isEmpty) {
              return Center(
                key: TestIds.trailEmpty,
                child: const Text('Your trail will show here.'),
              );
            }
            final subject = subjects.contains(_subject)
                ? _subject!
                : subjects.first;
            final nodes = _nodes(d, subject);
            final topicsInOrder = <String>[];
            for (final n in nodes) {
              if (!topicsInOrder.contains(n.skill.topic)) {
                topicsInOrder.add(n.skill.topic);
              }
            }
            return ListView(
              padding: EdgeInsets.all(t.sp('lg')),
              children: [
                Wrap(
                  spacing: t.sp('sm'),
                  children: [
                    for (final sub in subjects)
                      ChoiceChip(
                        key: TestIds.trailSubject(sub),
                        label: Text(sub == 'maths' ? 'Maths' : 'English'),
                        selected: sub == subject,
                        onSelected: (_) => setState(() => _subject = sub),
                      ),
                  ],
                ),
                SizedBox(height: t.sp('md')),
                FilledButton.icon(
                  key: TestIds.trailContinue,
                  onPressed: Trail.autoRung(nodes) == null
                      ? null
                      : () => _continue(d, subject),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Continue'),
                ),
                SizedBox(height: t.sp('lg')),
                for (final topic in topicsInOrder) ...[
                  Text(
                    topicDisplayName(d.packs, subject, year, topic),
                    style: t.styles['subheading']!,
                  ),
                  SizedBox(height: t.sp('xs')),
                  Wrap(
                    spacing: t.sp('sm'),
                    runSpacing: t.sp('sm'),
                    children: [
                      for (final n in nodes.where(
                        (x) => x.skill.topic == topic,
                      ))
                        _RungTile(
                          node: n,
                          label: _stateLabel(n),
                          showAccuracy: widget.showAccuracy,
                          onTap: () => _sheet(d, n, subject),
                        ),
                    ],
                  ),
                  SizedBox(height: t.sp('lg')),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RungTile extends StatelessWidget {
  const _RungTile({
    required this.node,
    required this.label,
    required this.showAccuracy,
    required this.onTap,
  });
  final TrailNode node;
  final String label;
  final bool showAccuracy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    final locked = node.isLocked;
    final acc = node.accuracy;
    return Semantics(
      button: true,
      label:
          '${node.skill.name}, $label, ${node.stars} of 3 stars'
          '${showAccuracy && acc != null ? ', ${(acc * 100).round()} percent right' : ''}',
      child: InkWell(
        key: TestIds.trailNode(node.key),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 150,
          constraints: BoxConstraints(minHeight: t.minTouch),
          padding: EdgeInsets.all(t.sp('sm')),
          decoration: BoxDecoration(
            color: locked ? t.surfaceAlt : t.surface,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(node.skill.name, style: t.styles['body']!),
                    ),
                    if (locked) const Icon(Icons.lock_outline, size: 16),
                  ],
                ),
                SizedBox(height: t.sp('xs')),
                Row(
                  key: TestIds.trailStars(node.key),
                  children: [
                    for (var i = 0; i < 3; i++)
                      Icon(
                        i < node.stars ? Icons.star : Icons.star_border,
                        size: 18,
                      ),
                  ],
                ),
                SizedBox(height: t.sp('xs')),
                Text(label, style: t.styles['caption'] ?? t.styles['body']!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
