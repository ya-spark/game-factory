import 'package:flutter/material.dart';

import '../core/profile/child_profile.dart';
import '../core/services.dart';
import '../engine/engine.dart';
import 'game_registry.dart';
import 'kit/ds_bars.dart';
import 'mode_toggle.dart';
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

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  LearnMode? _lastMode;

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
          _ => StudyTab(child: child, page: id),
        };
        return Scaffold(
          key: TestIds.shell,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                DsTopBar(
                  coins: s.profile.data.coins,
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
