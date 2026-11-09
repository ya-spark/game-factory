/// Per-child progress, daily release of built-in content, which items are open, and the item
/// selector. Pure Dart; the clock (as a day number) and the `Random` are passed in.
library;

import 'dart:math';

import 'models.dart';

/// A pack ready to play: [previewOnly] is true for the free part of an extra pack.
class LoadedPack {
  const LoadedPack(this.pack, {this.previewOnly = false});
  final ContentPack pack;
  final bool previewOnly;
}

/// One item with the pack facts the selector needs.
class PoolItem {
  const PoolItem({
    required this.item,
    required this.packId,
    required this.subject,
    required this.year,
    required this.topic,
  });
  final ContentItem item;
  final String packId;
  final String subject;
  final int year;
  final String topic;
  String get id => item.id;
}

/// `content.daily_release` in `app.config.yaml`.
class ReleaseConfig {
  const ReleaseConfig({
    this.initialPerSubject = 10,
    this.perDayPerSubject = 2,
    this.requirePassed = true,
  });
  final int initialPerSubject;
  final int perDayPerSubject;
  final bool requirePassed;
}

/// What one child has opened for one subject and year.
class ReleaseState {
  const ReleaseState({this.openIds = const {}, this.lastReleaseDay = -1});
  final Set<String> openIds;

  /// Day number (local date) of the last release; -1 before the first.
  final int lastReleaseDay;

  Map<String, Object?> toJson() => {
    'open': openIds.toList()..sort(),
    'day': lastReleaseDay,
  };
  factory ReleaseState.fromJson(Map<String, Object?> j) => ReleaseState(
    openIds: {...?(j['open'] as List?)?.cast<String>()},
    lastReleaseDay: (j['day'] as num?)?.toInt() ?? -1,
  );
}

/// Result of one item for one child.
class ItemResult {
  const ItemResult({
    this.attempts = 0,
    this.passes = 0,
    this.lastCorrect = false,
  });
  final int attempts;
  final int passes;
  final bool lastCorrect;
  bool get passed => passes > 0;

  Map<String, Object?> toJson() => {
    'a': attempts,
    'p': passes,
    'ok': lastCorrect,
  };
  factory ItemResult.fromJson(Map<String, Object?> j) => ItemResult(
    attempts: (j['a'] as num?)?.toInt() ?? 0,
    passes: (j['p'] as num?)?.toInt() ?? 0,
    lastCorrect: j['ok'] as bool? ?? false,
  );
}

/// Items attempted and passed (distinct items) in one topic.
class TopicResult {
  const TopicResult({this.attempted = 0, this.passed = 0});
  final int attempted;
  final int passed;

  Map<String, Object?> toJson() => {'a': attempted, 'p': passed};
  factory TopicResult.fromJson(Map<String, Object?> j) => TopicResult(
    attempted: (j['a'] as num?)?.toInt() ?? 0,
    passed: (j['p'] as num?)?.toInt() ?? 0,
  );
}

String releaseKey(String subject, int year) => '$subject/$year';
String topicKey(String subject, int year, String topic) =>
    '$subject/$year/$topic';

/// Everything learned about one child.
class ChildProgress {
  const ChildProgress({
    this.items = const {},
    this.topics = const {},
    this.release = const {},
    this.recent = const [],
  });

  final Map<String, ItemResult> items;
  final Map<String, TopicResult> topics;
  final Map<String, ReleaseState> release;

  /// Item ids seen lately, oldest first; the selector avoids them.
  final List<String> recent;

  static const int recentLimit = 40;

  Set<String> get passedIds => {
    for (final e in items.entries)
      if (e.value.passed) e.key,
  };

  /// Items last answered wrongly: the "revise mistakes" list (Study mode).
  List<String> get mistakeIds => [
    for (final e in items.entries)
      if (!e.value.lastCorrect) e.key,
  ]..sort();

  ChildProgress copyWith({
    Map<String, ItemResult>? items,
    Map<String, TopicResult>? topics,
    Map<String, ReleaseState>? release,
    List<String>? recent,
  }) => ChildProgress(
    items: items ?? this.items,
    topics: topics ?? this.topics,
    release: release ?? this.release,
    recent: recent ?? this.recent,
  );

  /// Records one answer.
  ChildProgress record(PoolItem p, {required bool correct}) {
    final before = items[p.id];
    final now = ItemResult(
      attempts: (before?.attempts ?? 0) + 1,
      passes: (before?.passes ?? 0) + (correct ? 1 : 0),
      lastCorrect: correct,
    );
    final tk = topicKey(p.subject, p.year, p.topic);
    final t = topics[tk] ?? const TopicResult();
    final newTopic = TopicResult(
      attempted: t.attempted + (before == null ? 1 : 0),
      passed: t.passed + ((before?.passed ?? false) || !correct ? 0 : 1),
    );
    final rec = [...recent.where((i) => i != p.id), p.id];
    return copyWith(
      items: {...items, p.id: now},
      topics: {...topics, tk: newTopic},
      recent: rec.length > recentLimit
          ? rec.sublist(rec.length - recentLimit)
          : rec,
    );
  }

  Map<String, Object?> toJson() => {
    'items': {for (final e in items.entries) e.key: e.value.toJson()},
    'topics': {for (final e in topics.entries) e.key: e.value.toJson()},
    'release': {for (final e in release.entries) e.key: e.value.toJson()},
    'recent': recent,
  };

  factory ChildProgress.fromJson(Map<String, Object?>? j) {
    if (j == null) return const ChildProgress();
    Map<String, T> read<T>(Object? o, T Function(Map<String, Object?>) f) => {
      if (o is Map)
        for (final e in o.entries)
          if (e.value is Map) '${e.key}': f((e.value as Map).cast()),
    };
    return ChildProgress(
      items: read(j['items'], ItemResult.fromJson),
      topics: read(j['topics'], TopicResult.fromJson),
      release: read(j['release'], ReleaseState.fromJson),
      recent: [...?(j['recent'] as List?)?.cast<String>()],
    );
  }
}

/// Daily release of the built-in content, per subject and year.
abstract final class ReleaseEngine {
  /// Items of one subject and year in release order: `seq`, then pack id, then item id.
  static List<PoolItem> ordered(
    Iterable<LoadedPack> packs,
    String subject,
    int year,
  ) {
    final out = <PoolItem>[
      for (final lp in packs)
        if (!lp.pack.isExtra &&
            lp.pack.subject == subject &&
            lp.pack.year == year)
          for (final it in lp.pack.items) _pool(lp.pack, it),
    ];
    out.sort((a, b) {
      final c = a.item.seq.compareTo(b.item.seq);
      if (c != 0) return c;
      final p = a.packId.compareTo(b.packId);
      return p != 0 ? p : a.id.compareTo(b.id);
    });
    return out;
  }

  static PoolItem _pool(ContentPack p, ContentItem it) => PoolItem(
    item: it,
    packId: p.id,
    subject: p.subject,
    year: p.year,
    topic: it.topicOr(p.topic) ?? p.topic,
  );

  /// The next state for one subject and year on day [today].
  ///
  /// First call: the first [ReleaseConfig.initialPerSubject] items open. Later: on a new day,
  /// the next [ReleaseConfig.perDayPerSubject] open, but only when every open item has been
  /// passed (when `requirePassed`). Missed days are not caught up. A date that goes back changes
  /// nothing. Open items stay open.
  static ReleaseState advance(
    ReleaseState? state,
    List<PoolItem> ordered,
    Set<String> passed,
    int today,
    ReleaseConfig cfg,
  ) {
    List<String> next(Set<String> open, int n) => [
      for (final p in ordered)
        if (!open.contains(p.id)) p.id,
    ].take(n).toList();

    if (state == null || state.lastReleaseDay < 0) {
      return ReleaseState(
        openIds: {
          ...?state?.openIds,
          ...next(state?.openIds ?? {}, cfg.initialPerSubject),
        },
        lastReleaseDay: today,
      );
    }
    if (today <= state.lastReleaseDay) return state;
    final allPassed = state.openIds.every(passed.contains);
    if (cfg.requirePassed && !allPassed) return state;
    return ReleaseState(
      openIds: {...state.openIds, ...next(state.openIds, cfg.perDayPerSubject)},
      lastReleaseDay: today,
    );
  }

  /// Advances the release of every subject that has built-in content for [year].
  static ChildProgress refresh(
    ChildProgress progress,
    Iterable<LoadedPack> packs,
    int year,
    int today,
    ReleaseConfig cfg,
  ) {
    final subjects = {
      for (final lp in packs)
        if (!lp.pack.isExtra && lp.pack.year == year) lp.pack.subject,
    };
    var release = progress.release;
    for (final s in subjects) {
      final key = releaseKey(s, year);
      release = {
        ...release,
        key: advance(
          release[key],
          ordered(packs, s, year),
          progress.passedIds,
          today,
          cfg,
        ),
      };
    }
    return progress.copyWith(release: release);
  }

  /// Number of items still to pass among the open ones, and how many are not open yet.
  static ({int toPass, int notYetOpen}) counts(
    ChildProgress progress,
    Iterable<LoadedPack> packs,
    String subject,
    int year,
  ) {
    final all = ordered(packs, subject, year);
    final open = progress.release[releaseKey(subject, year)]?.openIds ?? {};
    final passed = progress.passedIds;
    return (
      toPass: open.where((i) => !passed.contains(i)).length,
      notYetOpen: all.where((p) => !open.contains(p.id)).length,
    );
  }
}

/// What a child can open right now.
abstract final class OpenItems {
  /// Built-in items: all of them with Full Unlock, else those the release opened. Extra packs:
  /// every item when the full part is loaded (it only loads once bought), else only the
  /// preview items.
  static List<PoolItem> compute(
    Iterable<LoadedPack> packs,
    ChildProgress progress, {
    required bool fullUnlock,
  }) {
    final open = <String>{
      for (final r in progress.release.values) ...r.openIds,
    };
    final out = <PoolItem>[];
    for (final lp in packs) {
      final p = lp.pack;
      final preview = p.previewItemIds.toSet();
      for (final it in p.items) {
        final ok = p.isExtra
            ? (!lp.previewOnly || preview.contains(it.id))
            : (fullUnlock || open.contains(it.id));
        if (ok) out.add(ReleaseEngine._pool(p, it));
      }
    }
    return out;
  }
}

/// Picks items for a round. Deterministic for a given [Random].
abstract final class ItemSelector {
  /// Picks up to [count] items from [open] (items open to this child) that match the filters.
  /// Items in [recent] are used last. Pass a seeded `Random` for a repeatable result.
  static List<PoolItem> select({
    required List<PoolItem> open,
    required String subject,
    required int year,
    String? topic,
    ItemType? type,
    int? difficulty,
    required int count,
    required Random random,
    List<String> recent = const [],
  }) {
    final pool = [
      for (final p in open)
        if (p.subject == subject &&
            p.year == year &&
            (topic == null || p.topic == topic) &&
            (type == null || p.item.type == type) &&
            (difficulty == null || p.item.difficulty == difficulty))
          p,
    ]..sort((a, b) => a.id.compareTo(b.id));
    final recentSet = recent.toSet();
    final fresh = [
      for (final p in pool)
        if (!recentSet.contains(p.id)) p,
    ]..shuffle(random);
    final out = fresh.take(count).toList();
    if (out.length < count) {
      // Not enough unseen items: reuse the least recently seen first.
      final age = {for (var i = 0; i < recent.length; i++) recent[i]: i};
      final old = [
        for (final p in pool)
          if (recentSet.contains(p.id)) p,
      ]..sort((a, b) => age[a.id]!.compareTo(age[b.id]!));
      out.addAll(old.take(count - out.length));
    }
    return out;
  }

  /// A minigame needs at least [needed] open items matching the filters before it appears.
  static bool hasMinimumPool({
    required List<PoolItem> open,
    required String subject,
    required int year,
    required int needed,
    String? topic,
    ItemType? type,
  }) =>
      open
          .where(
            (p) =>
                p.subject == subject &&
                p.year == year &&
                (topic == null || p.topic == topic) &&
                (type == null || p.item.type == type),
          )
          .length >=
      needed;
}
