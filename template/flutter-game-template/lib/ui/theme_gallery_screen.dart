import 'package:flutter/material.dart';

import 'kit/ds_bars.dart';
import 'kit/ds_buttons.dart';
import 'kit/ds_cards.dart';
import 'kit/ds_chips.dart';
import 'test_ids.dart';
import 'theme/app_theme.dart';
import 'theme/design_loader.dart';
import 'theme/design_scope.dart';
import 'theme/design_tokens.dart';

/// Debug-only: every shared widget in every mode of the app's theme, for review on a device.
/// Opened from Settings when `kDebugMode` is true and the app has a design id; never in release.
class ThemeGalleryScreen extends StatefulWidget {
  const ThemeGalleryScreen({super.key, required this.design});
  final DesignBundle design;

  @override
  State<ThemeGalleryScreen> createState() => _ThemeGalleryScreenState();
}

class _ThemeGalleryScreenState extends State<ThemeGalleryScreen> {
  late DesignMode _mode = widget.design.app.modes.keys.first;
  late InterfaceLevel? _level = widget.design.app.levels.isEmpty
      ? null
      : InterfaceLevel.younger;
  DesignPrefs _prefs = const DesignPrefs();
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final app = widget.design.app;
    return DesignScope(
      design: widget.design,
      mode: _mode,
      level: _level,
      prefs: _prefs,
      child: Builder(
        builder: (context) => Scaffold(
          key: TestIds.themeGallery,
          appBar: AppBar(
            title: Text('Theme gallery: ${app.name}'),
            backgroundColor: ThemeTokens.of(context).surface,
          ),
          body: ListView(
            padding: EdgeInsets.all(ThemeTokens.of(context).sp('lg')),
            children: [
              _controls(context, app),
              _section(context, 'Buttons', [_buttons(context)]),
              _section(context, 'Chips', [_chips(context)]),
              _section(context, 'Progress', [_progress()]),
              _section(context, 'Hero header', [_hero(context)]),
              _section(context, 'Suggested next', [
                DsSuggestedCard(
                  id: 'g',
                  eyebrow: 'Try next',
                  title: 'Number sprint',
                  subtitle: 'A short one to warm up',
                  actionLabel: 'Start',
                  onTap: () {},
                ),
              ]),
              _section(context, 'Game tiles', [_tiles()]),
              _section(context, 'Topic cards', [_topics()]),
              _section(context, 'Pack card', [
                DsPackCard(
                  id: 'g',
                  title: 'Spelling pack',
                  subtitle: 'Years 3 to 4',
                  onTap: () {},
                ),
              ]),
              _section(context, 'Card', [
                DsCard(id: 'g', child: const Text('A plain card')),
              ]),
              _section(context, 'Dialog', [
                DsButton(
                  id: 'gallery.dialog',
                  label: 'Open dialog',
                  kind: DsButtonKind.secondary,
                  onPressed: () => showDsDialog(
                    context,
                    id: 'gallery',
                    title: 'A friendly dialog',
                    body: 'Dialogs use the same radius, colours and buttons.',
                    primaryLabel: 'OK',
                    secondaryLabel: 'Not now',
                  ),
                ),
              ]),
              _section(context, 'Top bar and bottom bar', [
                DsTopBar(
                  id: 'g',
                  title: 'Title',
                  modeToggle: const DsLabelChip(label: 'Toggle slot'),
                  coins: 120,
                ),
                SizedBox(height: ThemeTokens.of(context).sp('md')),
                DsBottomBar(
                  id: 'g',
                  selected: _tab,
                  onSelect: (i) => setState(() => _tab = i),
                  tabs: const [
                    DsTab(id: 'one', label: 'Play', icon: 'gamepad'),
                    DsTab(id: 'two', label: 'Challenges', icon: 'star'),
                    DsTab(id: 'three', label: 'Shop', icon: 'bag'),
                  ],
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls(BuildContext context, AppTokens app) {
    final t = ThemeTokens.of(context);
    return Wrap(
      spacing: t.sp('sm'),
      runSpacing: t.sp('sm'),
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final m in app.modes.keys)
          ChoiceChip(
            key: TestIds.galleryMode(m.key),
            label: Text('Mode: ${m.key}'),
            selected: _mode == m,
            onSelected: (_) => setState(() => _mode = m),
          ),
        if (app.levels.isNotEmpty)
          for (final l in InterfaceLevel.values)
            ChoiceChip(
              label: Text('Level: ${l.name}'),
              selected: _level == l,
              onSelected: (_) => setState(() => _level = l),
            ),
        FilterChip(
          key: TestIds.galleryLargeText,
          label: const Text('Large text'),
          selected: _prefs.largeText,
          onSelected: (v) =>
              setState(() => _prefs = _prefs.copyWith(largeText: v)),
        ),
        FilterChip(
          key: TestIds.galleryReduceMotion,
          label: const Text('Reduce motion'),
          selected: _prefs.reduceMotion,
          onSelected: (v) =>
              setState(() => _prefs = _prefs.copyWith(reduceMotion: v)),
        ),
      ],
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    final t = ThemeTokens.of(context);
    return Padding(
      padding: EdgeInsets.only(top: t.sp('xl')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: t.styles['heading']!),
          SizedBox(height: t.sp('sm')),
          ...children,
        ],
      ),
    );
  }

  Widget _buttons(BuildContext context) {
    final t = ThemeTokens.of(context);
    return Wrap(
      spacing: t.sp('sm'),
      runSpacing: t.sp('sm'),
      children: [
        DsButton(id: 'primary', label: 'Primary', onPressed: () {}),
        DsButton(
          id: 'secondary',
          label: 'Secondary',
          kind: DsButtonKind.secondary,
          onPressed: () {},
        ),
        DsButton(
          id: 'ghost',
          label: 'Ghost',
          kind: DsButtonKind.ghost,
          onPressed: () {},
        ),
        const DsButton(id: 'disabled', label: 'Disabled', onPressed: null),
        DsButton(
          id: 'icon',
          label: 'With icon',
          icon: 'check',
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _chips(BuildContext context) {
    final t = ThemeTokens.of(context);
    return Wrap(
      spacing: t.sp('sm'),
      runSpacing: t.sp('sm'),
      children: [
        const DsCoinChip(coins: 240),
        const DsStatChip(
          id: 'streak',
          icon: 'flame',
          value: '5',
          semanticLabel: '5 day streak',
        ),
        const DsStatChip(
          id: 'stars',
          icon: 'star',
          value: '12',
          semanticLabel: '12 stars',
        ),
        for (final m in Mastery.values)
          DsMasteryChip(id: 'g.${m.name}', mastery: m),
        const DsLabelChip(label: 'to revise', icon: 'revise'),
      ],
    );
  }

  Widget _progress() => const Column(
    children: [
      DsProgressBar(id: 'thick', value: 0.6),
      SizedBox(height: 12),
      DsProgressBar(id: 'thin', value: 0.3, thin: true),
    ],
  );

  Widget _hero(BuildContext context) {
    final d = widget.design;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ThemeTokens.of(context).cardRadius),
      child: DsHeroHeader(
        id: 'g',
        sceneAsset: d.sceneFor(_mode),
        mascotAsset: d.mascotFor(_mode),
        title: 'Good morning',
        subtitle: 'Ready for something fun?',
        overlay: const DsTopBar(
          id: 'hero',
          transparent: true,
          coins: 120,
          modeToggle: DsLabelChip(label: 'Toggle slot'),
        ),
        chips: const [
          DsStatChip(
            id: 'hero.streak',
            icon: 'flame',
            value: '5',
            semanticLabel: '5 day streak',
          ),
          DsStatChip(
            id: 'hero.stars',
            icon: 'star',
            value: '12',
            semanticLabel: '12 stars',
          ),
        ],
      ),
    );
  }

  Widget _tiles() => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
    childAspectRatio: 0.62,
    children: [
      DsGameTile(
        id: 'open',
        title: 'Number sprint',
        art: const SizedBox.shrink(),
        badge: 'Daily',
        stars: 2,
        progress: 0.5,
        note: '12 of 24 passed',
        onTap: () {},
      ),
      DsGameTile(
        id: 'locked',
        title: 'Word hunt',
        art: const SizedBox.shrink(),
        badge: 'New',
        lockedPrice: 200,
        onTap: () {},
      ),
    ],
  );

  Widget _topics() => Column(
    children: [
      DsTopicCard(
        id: 'a',
        title: 'Fractions',
        subject: 'Maths',
        passed: 14,
        total: 20,
        mastery: Mastery.gettingThere,
        toRevise: 3,
        accuracyPercent: 74,
        showAccuracy: true,
        onTap: () {},
      ),
      const SizedBox(height: 12),
      DsTopicCard(
        id: 'b',
        title: 'Spelling',
        subject: 'English',
        passed: 4,
        total: 20,
        mastery: Mastery.learning,
        accuracyPercent: 61,
        onTap: () {},
      ),
    ],
  );
}
