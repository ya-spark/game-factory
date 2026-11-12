import 'package:flutter/material.dart';

import '../core/profile/child_profile.dart';
import '../core/services.dart';
import '../engine/engine.dart';
import 'game_registry.dart';
import 'kit/ds_bars.dart';
import 'mode_toggle.dart';
import 'settings_screen.dart';
import 'tabs/challenges_tab.dart';
import 'tabs/play_tab.dart';
import 'tabs/shop_tab.dart';
import 'tabs/study_tab.dart';
import 'tabs/tab_data.dart';
import 'test_ids.dart';
import 'theme/design_scope.dart';

/// The tab set for a mode. Game: Play, Challenges, Shop. Study: Learn, Progress, Revise.
/// Apps without modes (the Mind hubs): Games, Challenges, Shop.
List<DsTab> tabsFor({required bool hasModes, required LearnMode mode}) {
  if (hasModes && mode == LearnMode.study) {
    return const [
      DsTab(id: 'learn', label: 'Learn', icon: 'book'),
      DsTab(id: 'progress', label: 'Progress', icon: 'bars'),
      DsTab(id: 'revise', label: 'Revise', icon: 'revise'),
    ];
  }
  return [
    DsTab(id: 'play', label: hasModes ? 'Play' : 'Games', icon: 'gamepad'),
    const DsTab(id: 'challenges', label: 'Challenges', icon: 'star'),
    const DsTab(id: 'shop', label: 'Shop', icon: 'bag'),
  ];
}

/// Main screen of a learning game: top bar (mode toggle, coins), the page of the selected tab
/// and the bottom bar, which changes with the mode.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.registry, this.loaders});

  /// Where the tabs read open items and packs (tests pass their own).
  final TabLoaders? loaders;

  /// The minigames to list (default: the app's own registry).
  final MiniGameRegistry? registry;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _tab = 0;
  LearnMode? _lastMode;

  /// Day number of the last release refresh per "player/year".
  final Map<String, int> _released = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Time played for the grown-ups' weekly total: the store starts counting when a player is
  /// selected; here it stops when the app goes to the background and restarts on return (no
  /// timers, only start and stop stamps).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final profile = ServicesScope.of(context).profile;
    if (state == AppLifecycleState.resumed) {
      profile.resumePlay();
      if (mounted) setState(() {}); // a new day opens the day's items
    } else {
      profile.pausePlay();
    }
  }

  /// Opens today's items once per player, year and day (the daily release of built-in
  /// content). Without it a new player would see no topics and no games.
  void _ensureRelease(ChildProfile child) {
    final learning = ServicesScope.of(context).learning;
    final year = child.year;
    if (learning == null || year == null) return;
    final key = '${child.id}/$year';
    final day = learning.today;
    if (_released[key] == day) return;
    _released[key] = day;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) learning.refreshRelease(child.id).ignore();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final design = DesignScope.bundleOf(context);
    final hasModes = design == null || design.app.modes.length > 1;
    return ListenableBuilder(
      listenable: s.profile,
      builder: (context, _) {
        final child = s.profile.activeChild;
        if (child == null) return const SizedBox.shrink();
        _ensureRelease(child);
        final mode = child.effectiveMode;
        if (_lastMode != mode) {
          _tab = 0; // a new mode starts on its first tab
          _lastMode = mode;
        }
        final tabs = tabsFor(hasModes: hasModes, mode: mode);
        final id = tabs[_tab].id;
        final registry = widget.registry ?? appGames;
        final Widget page = switch (id) {
          'play' => PlayTab(
            child: child,
            registry: registry,
            loaders: widget.loaders,
          ),
          'challenges' => ChallengesTab(child: child),
          'shop' => ShopTab(
            child: child,
            registry: registry,
            loaders: widget.loaders,
          ),
          _ => StudyTab(
            key: ValueKey(id),
            child: child,
            page: id,
            loaders: widget.loaders,
          ),
        };
        return Scaffold(
          key: TestIds.shell,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                DsTopBar(
                  coins: s.profile.data.coins,
                  onSettings: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  ),
                  modeToggle: hasModes ? ModeToggle(child: child) : null,
                ),
                Expanded(child: page),
              ],
            ),
          ),
          bottomNavigationBar: DsBottomBar(
            id: TestIds.shellBottomBar,
            tabs: tabs,
            selected: _tab,
            onSelect: (i) => setState(() => _tab = i),
          ),
        );
      },
    );
  }
}
