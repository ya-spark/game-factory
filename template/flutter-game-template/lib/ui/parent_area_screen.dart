import 'package:flutter/material.dart';

import '../core/content/learning_service.dart';
import '../core/profile/child_profile.dart';
import '../core/save/save_data.dart';
import '../core/services.dart';
import '../engine/engine.dart';
import 'child_report.dart';
import 'test_ids.dart';
import 'year_choices.dart';

/// Grown-ups only: reached through the "Ask a grown-up" gate. Per child: year level, mode lock,
/// progress report, delete. For the device: extra packs, purchases, download settings.
/// Calm wording: no pressure, no timers.
class ParentAreaScreen extends StatefulWidget {
  const ParentAreaScreen({super.key});

  @override
  State<ParentAreaScreen> createState() => _ParentAreaScreenState();
}

class _ParentAreaScreenState extends State<ParentAreaScreen> {
  String? _childId;
  bool _allYears = false;
  String? _message;
  bool _notificationsDenied = false;
  Future<List<int>>? _years;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _years ??=
        ServicesScope.of(context).learning?.contentYears() ??
        Future.value(const <int>[]);
  }

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    return ListenableBuilder(
      listenable: s.profile,
      builder: (context, _) {
        final kids = s.profile.children;
        final child =
            kids.where((c) => c.id == _childId).firstOrNull ??
            (kids.isEmpty ? null : kids.first);
        return Scaffold(
          key: TestIds.parentArea,
          appBar: AppBar(title: const Text('Grown-ups')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_message!),
                ),
              Text('Players', style: Theme.of(context).textTheme.titleMedium),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in kids)
                    ChoiceChip(
                      key: TestIds.parentChild(c.id),
                      label: Text(c.nickname),
                      selected: c.id == child?.id,
                      onSelected: (_) => setState(() => _childId = c.id),
                    ),
                ],
              ),
              if (child != null) ..._childSection(context, s, child),
              const Divider(height: 32),
              ..._deviceSection(context, s, child),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _childSection(
    BuildContext context,
    Services s,
    ChildProfile child,
  ) {
    return [
      const SizedBox(height: 12),
      FutureBuilder<List<int>>(
        future: _years,
        builder: (context, snap) {
          final years = yearChoices(snap.data, current: child.year);
          return DropdownButton<int>(
            key: TestIds.parentYear,
            value: child.year,
            hint: const Text('Year level'),
            items: [
              for (final y in years)
                DropdownMenuItem(
                  key: TestIds.parentYearOption(y),
                  value: y,
                  child: Text(y == 0 ? 'Foundation' : 'Year $y'),
                ),
            ],
            onChanged: (y) {
              if (y != null) s.profile.setChildYear(child.id, y);
            },
          );
        },
      ),
      if (s.config.goalsReminders.parentArea) ..._goals(s, child),
      const Text('Mode'),
      Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            key: TestIds.parentLockNone,
            label: const Text('Child chooses'),
            selected: child.lockedMode == null,
            onSelected: (_) => s.profile.setChildLockedMode(child.id, null),
          ),
          ChoiceChip(
            key: TestIds.parentLockGame,
            label: const Text('Game only'),
            selected: child.lockedMode == LearnMode.game,
            onSelected: (_) =>
                s.profile.setChildLockedMode(child.id, LearnMode.game),
          ),
          ChoiceChip(
            key: TestIds.parentLockStudy,
            label: const Text('Study only'),
            selected: child.lockedMode == LearnMode.study,
            onSelected: (_) =>
                s.profile.setChildLockedMode(child.id, LearnMode.study),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _Report(key: TestIds.parentReport, child: child),
      TextButton.icon(
        key: TestIds.parentReset,
        icon: const Icon(Icons.restart_alt),
        label: Text('Reset progress for ${child.nickname}'),
        onPressed: () => _confirmReset(context, s, child),
      ),
      TextButton.icon(
        key: TestIds.parentDelete,
        icon: const Icon(Icons.delete_outline),
        label: Text('Delete ${child.nickname} and their progress'),
        onPressed: () => _confirmDelete(context, s, child),
      ),
    ];
  }

  Future<void> _confirmReset(
    BuildContext context,
    Services s,
    ChildProfile child,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset progress for ${child.nickname}?'),
        content: const Text(
          'This clears their answers, topics and time played. The player, coins and '
          'purchases stay. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            key: TestIds.parentResetConfirm,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await s.profile.resetChildProgress(child.id);
      if (mounted) {
        setState(() => _message = 'Progress reset for ${child.nickname}.');
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Services s,
    ChildProfile child,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${child.nickname}?'),
        content: const Text(
          'This removes this player and their progress. Coins and purchases stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            key: TestIds.parentDeleteConfirm,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await s.profile.deleteChild(child.id);
      setState(() => _childId = null);
    }
  }

  /// Goal size for one child: Light, Steady or Big (items only; coins do not change).
  List<Widget> _goals(Services s, ChildProfile child) => [
    const SizedBox(height: 8),
    const Text('Goals', key: TestIds.parentGoalsSection),
    Wrap(
      spacing: 8,
      children: [
        for (final p in GoalPreset.values)
          ChoiceChip(
            key: TestIds.parentGoalPreset(p.name),
            label: Text(p.label),
            selected: child.goalPreset == p,
            onSelected: (_) => s.profile.setGoalPreset(child.id, p),
          ),
      ],
    ),
    Text(
      '${child.goalPreset.dailyItems} items a day, '
      '${child.goalPreset.weeklyItems} a week. Coins stay the same.',
      key: TestIds.parentGoalSummary,
    ),
    const SizedBox(height: 8),
  ];

  /// Reminders for this device: switch, time (07:00 to 20:00) and days of the week.
  List<Widget> _reminders(BuildContext context, Services s, SaveData d) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final times = [
      for (
        var m = ReminderPlan.earliestHour * 60;
        m <= ReminderPlan.latestHour * 60;
        m += 30
      )
        m,
    ];
    final current =
        ReminderPlan.clampHour(d.reminderHour) * 60 +
        (d.reminderMinute >= 30 ? 30 : 0);
    String clock(int m) =>
        '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
    return [
      Text(
        'Goals and reminders',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      SwitchListTile(
        key: TestIds.parentRemindersSwitch,
        title: const Text('Reminders on this device'),
        subtitle: const Text(
          'A gentle nudge at the time you choose. Never on a day the goal is met, '
          'and it stops after 3 days without opening the app.',
        ),
        value: d.remindersOn,
        onChanged: (v) async {
          if (v) {
            final ok = await s.notifications.requestPermission();
            if (!ok) {
              if (mounted) setState(() => _notificationsDenied = true);
              return;
            }
          }
          if (mounted) setState(() => _notificationsDenied = false);
          await s.profile.setReminders(v);
        },
      ),
      if (_notificationsDenied)
        const Padding(
          key: TestIds.parentRemindersDenied,
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Notifications are off in system settings.'),
        ),
      if (d.remindersOn) ...[
        Row(
          children: [
            const Text('Time'),
            const SizedBox(width: 12),
            DropdownButton<int>(
              key: TestIds.parentReminderTime,
              value: current,
              items: [
                for (final m in times)
                  DropdownMenuItem(
                    key: TestIds.parentReminderTimeOption(m),
                    value: m,
                    child: Text(clock(m)),
                  ),
              ],
              onChanged: (m) {
                if (m != null) s.profile.setReminderTime(m ~/ 60, m % 60);
              },
            ),
          ],
        ),
        Wrap(
          spacing: 6,
          children: [
            for (var w = 1; w <= 7; w++)
              FilterChip(
                key: TestIds.parentReminderDay(w),
                label: Text(names[w - 1]),
                selected: d.reminderDays.contains(w),
                onSelected: (on) => s.profile.setReminderDays({
                  ...d.reminderDays.where((x) => x != w),
                  if (on) w,
                }),
              ),
          ],
        ),
      ],
      const SizedBox(height: 8),
    ];
  }

  List<Widget> _deviceSection(
    BuildContext context,
    Services s,
    ChildProfile? child,
  ) {
    final learning = s.learning;
    final d = s.profile.data;
    return [
      if (s.config.goalsReminders.parentArea) ..._reminders(context, s, d),
      Text('Learning', style: Theme.of(context).textTheme.titleMedium),
      SwitchListTile(
        key: TestIds.parentSpacedReview,
        title: const Text('Spaced review'),
        subtitle: const Text(
          'Brings back answered questions after a few days, in Today\'s review.',
        ),
        value: d.spacedReview,
        onChanged: s.profile.setSpacedReview,
      ),
      const SizedBox(height: 8),
      Text('Downloads', style: Theme.of(context).textTheme.titleMedium),
      SwitchListTile(
        key: TestIds.parentWifiOnly,
        title: const Text('Download full packs on Wi-Fi only'),
        subtitle: const Text(
          'Off: we ask you first before a large download on mobile data.',
        ),
        value: d.downloadWifiOnly,
        onChanged: s.profile.setDownloadWifiOnly,
      ),
      const SizedBox(height: 8),
      if (!s.webShell) ...[
        Text('Purchases', style: Theme.of(context).textTheme.titleMedium),
        ListTile(
          title: const Text('Remove Ads'),
          subtitle: const Text(
            'One purchase. No ads, now and in later updates.',
          ),
          trailing: d.adsRemoved
              ? const Text('Owned')
              : FilledButton(
                  key: TestIds.parentRemoveAds,
                  onPressed: () => _buy(context, s, 'remove_ads_all'),
                  child: Text(s.purchases.priceOf('remove_ads_all') ?? 'Buy'),
                ),
        ),
        ListTile(
          title: const Text('Full Unlock'),
          subtitle: const Text(
            'Opens all built-in content, including updates.',
          ),
          trailing: d.fullUnlock
              ? const Text('Owned')
              : FilledButton(
                  key: TestIds.parentBuyFull,
                  onPressed: () => _buy(context, s, 'unlock_full'),
                  child: Text(s.purchases.priceOf('unlock_full') ?? 'Buy'),
                ),
        ),
        TextButton(
          key: TestIds.parentRestore,
          onPressed: () => learning != null
              ? learning.restorePurchases()
              : s.purchases.restore(),
          child: const Text('Restore purchases'),
        ),
      ],
      if (learning != null && !s.webShell) ...[
        const SizedBox(height: 8),
        Text('Extra packs', style: Theme.of(context).textTheme.titleMedium),
        SwitchListTile(
          key: TestIds.parentAllYears,
          title: const Text('Show all year levels'),
          value: _allYears,
          onChanged: (v) => setState(() => _allYears = v),
        ),
        FutureBuilder<List<BundleEntry>>(
          future: learning.bundlesFor(child?.year, allYears: _allYears),
          builder: (context, snap) => Column(
            children: [
              for (final b in snap.data ?? const <BundleEntry>[])
                ListTile(
                  title: Text(b.title),
                  subtitle: Text(
                    'All ${b.packs.length} packs of year ${b.year}',
                  ),
                  trailing: learning.ownsBundle(b)
                      ? const Text('Owned')
                      : FilledButton(
                          key: TestIds.parentBundleBuy(b.productId),
                          onPressed: () => _buy(context, s, b.productId),
                          child: Text(
                            s.purchases.priceOf(b.productId) ?? 'Buy',
                          ),
                        ),
                ),
            ],
          ),
        ),
        FutureBuilder<List<CatalogPack>>(
          future: learning.packsFor(child?.year, allYears: _allYears),
          builder: (context, snap) {
            final packs = snap.data ?? const <CatalogPack>[];
            if (packs.isEmpty) {
              return const Text('No extra packs for this year level yet.');
            }
            return Column(
              children: [
                for (final c in packs) _packTile(context, s, learning, c),
              ],
            );
          },
        ),
      ],
    ];
  }

  /// A purchase, or the "not available in this web version" note where there is no store.
  Future<void> _buy(BuildContext context, Services s, String productId) async {
    final note = s.purchases.unavailableMessage;
    if (note != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(note)));
      return;
    }
    await s.purchases.buy(productId);
  }

  Widget _packTile(
    BuildContext context,
    Services s,
    LearningService learning,
    CatalogPack c,
  ) {
    final owned = learning.owns(c);
    final mb = (c.entry.sizeOf(PackPart.full) / (1024 * 1024)).toStringAsFixed(
      1,
    );
    final pid = c.entry.productId!;
    return ListTile(
      title: Text(c.entry.title),
      subtitle: Text('${c.entry.items} items, $mb MB'),
      trailing: Wrap(
        spacing: 4,
        children: [
          if (!c.cachedPreview && c.entry.previewFile != null && !owned)
            TextButton(
              key: TestIds.parentPackPreview(c.id),
              onPressed: () => _run(learning.downloadPreview(c)),
              child: const Text('Try a preview'),
            ),
          if (!owned)
            FilledButton(
              key: TestIds.parentPackBuy(c.id),
              onPressed: () => _buy(context, s, pid),
              child: Text(s.purchases.priceOf(pid) ?? 'Buy'),
            ),
          if (owned && !c.cachedFull)
            FilledButton(
              key: TestIds.parentPackDownload(c.id),
              onPressed: () => _downloadFull(learning, c),
              child: const Text('Download'),
            ),
          if (owned && c.cachedFull) const Text('Ready'),
        ],
      ),
    );
  }

  Future<void> _downloadFull(LearningService learning, CatalogPack c) async {
    var r = await learning.downloadFull(c);
    if (r.status == DownloadStatus.needsParentApproval && mounted) {
      final mb = (c.entry.sizeOf(PackPart.full) / (1024 * 1024))
          .toStringAsFixed(0);
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Download on mobile data?'),
          content: Text('This pack is about $mb MB and you are not on Wi-Fi.'),
          actions: [
            TextButton(
              key: TestIds.parentMobileCancel,
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              key: TestIds.parentMobileConfirm,
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Download'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      r = await learning.downloadFull(c, parentApproved: true);
    }
    _report(r);
  }

  Future<void> _run(Future<DownloadResult> f) async => _report(await f);

  void _report(DownloadResult r) {
    if (!mounted) return;
    setState(
      () => _message = switch (r.status) {
        DownloadStatus.done => 'Downloaded.',
        DownloadStatus.offline => 'No connection right now.',
        DownloadStatus.blockedWifiOnly => 'Waiting for Wi-Fi (see settings).',
        DownloadStatus.notPurchased => 'This pack needs a purchase first.',
        DownloadStatus.needsParentApproval => 'Not downloaded.',
        DownloadStatus.failed => 'The download did not work. Try again later.',
      },
    );
  }
}

/// The weekly report for one child, then the daily release status (items open, still to pass).
class _Report extends StatelessWidget {
  const _Report({super.key, required this.child});
  final ChildProfile child;

  @override
  Widget build(BuildContext context) {
    final p = child.progress;
    final passed = p.passedIds;
    final rows = <Widget>[];
    for (final e in p.release.entries) {
      final open = e.value.openIds;
      final toPass = open.where((i) => !passed.contains(i)).length;
      rows.add(
        Text(
          '${e.key}: ${open.length} open, $toPass still to pass'
          '${toPass == 0 ? '. The next ones open tomorrow.' : '.'}',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Progress', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ChildReport(child: child),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Daily release', style: Theme.of(context).textTheme.titleMedium),
          ...rows,
        ],
      ],
    );
  }
}
