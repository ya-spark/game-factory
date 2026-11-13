import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/profile/child_profile.dart';
import '../../core/services.dart';
import '../../engine/engine.dart';
import '../kit/ds_art.dart';
import '../kit/ds_cards.dart';
import '../kit/ds_chips.dart';
import '../mistakes_round.dart';
import '../test_ids.dart';
import '../theme/app_theme.dart';
import '../theme/design_scope.dart';
import '../theme/design_tokens.dart';
import 'tab_data.dart';

/// A game the child can see on Play, with the subject it will be played in.
class PlayEntry {
  const PlayEntry(this.offer, this.subject, this.pool);
  final MiniGameOffer offer;
  final String subject;

  /// Open items of that subject and year this game can play.
  final int pool;
  MiniGame get game => offer.game;
}

/// The games to list for a child: only games with enough open items, in registry order, each
/// once (in the first subject that has enough items). Locked games are marked.
List<PlayEntry> playEntries({
  required MiniGameRegistry registry,
  required List<PoolItem> open,
  required int year,
  required Set<String> unlocked,
  MiniGameMode mode = MiniGameMode.game,
}) {
  final subjects = {
    for (final p in open)
      if (p.year == year) p.subject,
  }.toList()..sort();
  final out = <PlayEntry>[];
  final seen = <String>{};
  for (final subject in subjects) {
    final offers = registry.offers(
      open: open,
      subject: subject,
      year: year,
      mode: mode,
      unlocked: unlocked,
    );
    for (final o in offers) {
      if (!seen.add(o.game.id)) continue;
      final pool = open
          .where(
            (p) =>
                p.subject == subject &&
                p.year == year &&
                o.game.itemTypes.contains(p.item.type),
          )
          .length;
      out.add(PlayEntry(o, subject, pool));
    }
  }
  final order = [for (final e in registry.entries) e.game.id];
  out.sort((a, b) => order.indexOf(a.game.id) - order.indexOf(b.game.id));
  return out;
}

/// 0 to 3 stars for a game from the share of its open items the child has passed in it.
int gameStars(GameStat? stat, int pool) {
  if (stat == null || pool <= 0) return 0;
  final share = (stat.passed / pool).clamp(0.0, 1.0);
  return share >= 0.9 ? 3 : (share >= 0.6 ? 2 : (share >= 0.25 ? 1 : 0));
}

/// Game mode home: hero, "try next", the daily challenge and the game tiles.
class PlayTab extends StatefulWidget {
  const PlayTab({
    super.key,
    required this.child,
    required this.registry,
    this.loaders,
  });
  final ChildProfile child;
  final MiniGameRegistry registry;
  final TabLoaders? loaders;

  @override
  State<PlayTab> createState() => _PlayTabState();
}

class _PlayTabState extends State<PlayTab> {
  Future<List<PoolItem>>? _open;
  List<LoadedPack>? _packs;

  TabLoaders get _loaders => widget.loaders ?? TabLoaders.of(context);

  void _loadPacks() => _loaders.packs().then((p) {
    if (mounted) setState(() => _packs = p);
  });

  void _reload() {
    setState(() => _open = _loaders.openItems(widget.child.id));
    _loadPacks();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_open == null) {
      _open = _loaders.openItems(widget.child.id);
      _loadPacks();
    }
  }

  Future<void> _play(PlayEntry e, {String? topic}) async {
    final s = ServicesScope.of(context);
    final nav = Navigator.of(context);
    if (e.offer.locked) return _unlock(e);
    final open = await _open!;
    final packs = await _loaders.packs();
    final child = s.profile.children.firstWhere((c) => c.id == widget.child.id);
    final session = QuizSession.start(
      open: open,
      progress: child.progress,
      packs: packs,
      rewardsConfig: s.config.rewards,
      subject: e.subject,
      year: child.year ?? 0,
      today: s.profile.today,
      random: Random(),
      types: e.game.itemTypes,
      topic: topic,
      minPool: e.game.minPool,
      streakDays: s.profile.displayStreak,
      gameId: e.game.id,
    );
    if (session == null) return;
    int? gameScore;
    await nav.push(
      MaterialPageRoute<void>(
        builder: (_) => e.game.build(
          MiniGameContext(
            session: session,
            mode: MiniGameMode.game,
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
                  e.game.id,
                  gameScore ?? session.report.correct * 10,
                ),
              );
              if (nav.mounted) nav.pop();
            },
          ),
        ) as Widget,
      ),
    );
    if (mounted) _reload();
  }

  /// A locked game opens with coins (never with money).
  Future<void> _unlock(PlayEntry e) async {
    final s = ServicesScope.of(context);
    final price = e.offer.price;
    final enough = s.profile.data.coins >= price;
    final yes = await showDsDialog(
      context,
      id: 'unlock.${e.game.id}',
      title: e.game.title,
      body: enough
          ? 'Open this game for $price coins?'
          : 'You need $price coins to open this game. Keep learning to earn more.',
      primaryLabel: enough ? 'Open it' : 'OK',
      secondaryLabel: enough ? 'Not now' : null,
    );
    if (yes == true && enough) {
      await s.profile.unlockGame(e.game.id, price);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    final s = ServicesScope.of(context);
    final design = DesignScope.bundleOf(context);
    final child = widget.child;
    // The Mind hubs have no modes: a "Continue" card and tiles with the best score.
    final mind = design != null && design.app.modes.length <= 1;
    return FutureBuilder<List<PoolItem>>(
      future: _open,
      builder: (context, snap) {
        final open = snap.data ?? const <PoolItem>[];
        final entries = playEntries(
          registry: widget.registry,
          open: open,
          year: child.year ?? 0,
          unlocked: s.profile.data.unlockedGames,
        );
        final playable = [
          for (final e in entries)
            if (!e.offer.locked) e,
        ];
        final reviseKey = child.progress.topicToRevise(pool: open);
        final tryNext = playable.isEmpty || mind
            ? null
            : (reviseKey == null ? null : splitTopicKey(reviseKey));
        final daily = playable.isEmpty
            ? null
            : playable[s.profile.today % playable.length];
        final rewards = child.progress.rewards;
        return ListView(
          key: TestIds.playTab,
          padding: EdgeInsets.only(bottom: t.sp('lg')),
          children: [
            DsHeroHeader(
              id: 'play',
              sceneAsset: design?.sceneFor(DesignMode.game) ?? '',
              mascotAsset: design?.mascotFor(DesignMode.game),
              title: 'Hi, ${child.nickname}!',
              subtitle: mind ? 'Pick a game' : 'Ready to play?',
              chips: [
                if (s.config.rewards.starsEnabled)
                  DsStatChip(
                    id: 'stars',
                    icon: 'star',
                    value: '${rewards.stars}',
                    semanticLabel: '${rewards.stars} stars',
                  ),
                if (s.config.retention.streaks)
                  DsStatChip(
                    id: 'streak',
                    icon: 'flame',
                    value: '${s.profile.displayStreak}',
                    semanticLabel: '${s.profile.displayStreak} day streak',
                  ),
              ],
            ),
            Padding(
              padding: EdgeInsets.all(t.sp('lg')),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: t.sp('lg'),
                children: [
                  if (playable.isNotEmpty)
                    DsSuggestedCard(
                      id: 'next',
                      eyebrow: mind ? 'Continue' : 'Try next',
                      title: tryNext != null
                          ? topicDisplayName(
                              _packs ?? const <LoadedPack>[],
                              tryNext.subject,
                              tryNext.year,
                              tryNext.topic,
                            )
                          : playable.first.game.title,
                      subtitle: tryNext != null
                          ? 'A few to practise again'
                          : 'Pick up where you left off',
                      actionLabel: 'Play',
                      onTap: () {
                        final e = playable.firstWhere(
                          (p) =>
                              tryNext == null || p.subject == tryNext.subject,
                          orElse: () => playable.first,
                        );
                        _play(e, topic: tryNext?.topic);
                      },
                    ),
                  if (!mind)
                    MistakesEntry(
                      count: [
                        for (final id in child.progress.mistakeIds)
                          if (open.any((p) => p.id == id)) id,
                      ].length,
                      onStart: () async {
                        final packs = await _loaders.packs();
                        if (!context.mounted) return;
                        await startMistakesRound(
                          context,
                          childId: child.id,
                          open: open,
                          packs: packs,
                          mode: MiniGameMode.game,
                        );
                        if (mounted) _reload();
                      },
                    ),
                  if (entries.isEmpty)
                    Text(
                      snap.connectionState == ConnectionState.done
                          ? 'Games open up as you learn.'
                          : '',
                      style: t.styles['body']!,
                    ),
                  LayoutBuilder(
                    builder: (context, box) {
                      final gap = t.sp('md');
                      final w = (box.maxWidth - gap) / 2;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          // Each game shows once; the daily game is marked with a badge.
                          for (final e in entries)
                            SizedBox(
                              width: w,
                              child: daily != null && e.game.id == daily.game.id
                                  ? KeyedSubtree(
                                      key: TestIds.playDaily,
                                      child: _tile(
                                        e,
                                        t,
                                        id: e.game.id,
                                        badge: 'Daily',
                                        key: TestIds.playGame(e.game.id),
                                      ),
                                    )
                                  : _tile(
                                      e,
                                      t,
                                      id: e.game.id,
                                      key: TestIds.playGame(e.game.id),
                                    ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tile(
    PlayEntry e,
    ThemeTokens t, {
    required String id,
    required Key key,
    String? badge,
  }) {
    final stat = widget.child.progress.games[e.game.id];
    final locked = e.offer.locked;
    return KeyedSubtree(
      key: key,
      child: DsGameTile(
        id: id,
        title: e.game.title,
        art: Center(
          child: DsGameArt(e.game.id, size: t.size('icon_lg'), color: t.text),
        ),
        badge: badge,
        stars: locked ? null : gameStars(stat, e.pool),
        progress: locked
            ? null
            : ((stat?.passed ?? 0) / max(e.pool, 1)).clamp(0, 1).toDouble(),
        note: locked
            ? null
            : (stat != null && stat.best > 0
                  ? 'Best ${stat.best}'
                  : '${e.pool} questions open'),
        lockedPrice: locked ? e.offer.price : null,
        onTap: () => _play(e),
      ),
    );
  }
}
