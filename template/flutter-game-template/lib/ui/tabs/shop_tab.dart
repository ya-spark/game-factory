import 'package:flutter/material.dart';

import '../../core/profile/child_profile.dart';
import '../../core/services.dart';
import '../../engine/engine.dart';
import '../kit/ds_buttons.dart';
import '../kit/ds_bars.dart';
import '../kit/ds_chips.dart';
import '../parent_area_screen.dart';
import '../parent_gate.dart';
import '../kit/ds_art.dart';
import '../shop_screen.dart';
import '../test_ids.dart';
import '../theme/app_theme.dart';
import 'play_tab.dart';
import 'tab_data.dart';

/// Shop (Game mode): avatars (shapes, never people), colour themes and coin-locked games, all
/// bought with coins. Coin packs, Remove Ads and Full Unlock are behind the parent gate; no
/// money price is shown on this page.
class ShopTab extends StatelessWidget {
  const ShopTab({super.key, required this.child, this.registry, this.loaders});
  final ChildProfile child;

  /// Games listed in the shop (default: the app's own, via the shell).
  final MiniGameRegistry? registry;
  final TabLoaders? loaders;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    final s = ServicesScope.of(context);
    final p = s.profile;
    Widget section(String title) => Padding(
      padding: EdgeInsets.only(top: t.sp('lg'), bottom: t.sp('sm')),
      child: Semantics(
        header: true,
        child: Text(title, style: t.styles['subheading']!),
      ),
    );

    Widget itemCard(ShopItem i, {required Key key}) {
      final owned = p.ownsItem(i);
      final used = i.kind == ShopKind.avatar
          ? child.avatar == i.id
          : child.colorTheme == i.id;
      return SizedBox(
        width: 150,
        child: DsCard(
          id: 'shop.${i.id}',
          child: Column(
            key: key,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (i.kind == ShopKind.avatar)
                DsAvatarArt(i.id, size: t.size('icon_lg'), color: t.text),
              Text(i.title, style: t.styles['body']!),
              SizedBox(height: t.sp('xs')),
              if (!owned) DsCoinChip(id: 'shop.${i.id}', coins: i.price),
              SizedBox(height: t.sp('xs')),
              DsButton(
                id: 'shop.use.${i.id}',
                label: used ? 'In use' : (owned ? 'Use' : 'Buy'),
                kind: owned ? DsButtonKind.secondary : DsButtonKind.primary,
                semanticLabel: used
                    ? '${i.title}, in use'
                    : (owned
                          ? 'Use ${i.title}'
                          : 'Buy ${i.title} for ${i.price} coins'),
                onPressed: used
                    ? null
                    : () async {
                        if (await p.buyItem(i)) await p.equipItem(child.id, i);
                      },
              ),
            ],
          ),
        ),
      );
    }

    Future<void> gated(Widget screen) async {
      if (await showParentGate(context, s.parentGate) && context.mounted) {
        await Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => screen));
      }
    }

    final loaders = this.loaders ?? TabLoaders.of(context);
    return ListView(
      key: TestIds.shopTab,
      padding: EdgeInsets.all(t.sp('lg')),
      children: [
        Semantics(header: true, child: Text('Shop', style: t.styles['title']!)),
        section('Avatars'),
        Wrap(
          spacing: t.sp('md'),
          runSpacing: t.sp('md'),
          children: [
            for (final i in shopItems.where((i) => i.kind == ShopKind.avatar))
              itemCard(i, key: TestIds.shopAvatar(i.id)),
          ],
        ),
        section('Colour themes'),
        Wrap(
          spacing: t.sp('md'),
          runSpacing: t.sp('md'),
          children: [
            for (final i in shopItems.where((i) => i.kind == ShopKind.theme))
              itemCard(i, key: TestIds.shopTheme(i.id)),
          ],
        ),
        FutureBuilder<List<PoolItem>>(
          future: loaders.openItems(child.id),
          builder: (context, snap) {
            final reg = registry ?? const MiniGameRegistry([]);
            final locked = [
              for (final e in playEntries(
                registry: reg,
                open: snap.data ?? const [],
                year: child.year ?? 0,
                unlocked: p.data.unlockedGames,
              ))
                if (e.offer.locked) e,
            ];
            if (locked.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                section('Games'),
                for (final e in locked)
                  Padding(
                    padding: EdgeInsets.only(bottom: t.sp('sm')),
                    child: DsCard(
                      id: 'shop.game.${e.game.id}',
                      child: Row(
                        key: TestIds.shopGame(e.game.id),
                        children: [
                          Expanded(
                            child: Text(e.game.title, style: t.styles['body']!),
                          ),
                          DsCoinChip(
                            id: 'shop.game.${e.game.id}',
                            coins: e.offer.price,
                          ),
                          SizedBox(width: t.sp('sm')),
                          DsButton(
                            id: 'shop.game.buy.${e.game.id}',
                            label: 'Buy',
                            semanticLabel:
                                'Buy ${e.game.title} for ${e.offer.price} coins',
                            onPressed: () =>
                                p.unlockGame(e.game.id, e.offer.price),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (!s.webShell) section('For grown-ups'),
        if (!s.webShell)
          DsCard(
            id: 'shop.grownups',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coin packs, Remove Ads and the full pack are for a grown-up.',
                  style: t.styles['body']!,
                ),
                SizedBox(height: t.sp('sm')),
                DsButton(
                  id: 'shop.parentArea',
                  label: 'Ask a grown-up',
                  icon: 'lock',
                  kind: DsButtonKind.secondary,
                  onPressed: () => gated(
                    s.config.content.enabled
                        ? const ParentAreaScreen()
                        : const ShopScreen(),
                  ),
                ),
                SizedBox(height: t.sp('xs')),
                DsButton(
                  id: 'shop.coins',
                  label: 'Coins and Remove Ads',
                  icon: 'lock',
                  kind: DsButtonKind.ghost,
                  onPressed: () => gated(const ShopScreen()),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
