import 'package:flutter/material.dart';

import '../core/config/products.dart';
import '../core/services.dart';
import 'parent_gate.dart';
import 'test_ids.dart';
import 'widgets.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Shop',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: KidColors.ocean,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            key: TestIds.shopRestore,
            onPressed: s.purchases.restore,
            child: const Text('Restore'),
          ),
        ],
      ),
      body: KidPage(
        child: ListenableBuilder(
          listenable: s.profile,
          builder: (context, _) {
            final products = s.purchases.products;
            if (!s.purchases.available || products.isEmpty) {
              return const Center(
                key: TestIds.shopUnavailable,
                child: Text('Store unavailable right now.'),
              );
            }
            // Remove Ads first, then the coin packs in ascending size.
            final sorted = [...products]
              ..sort((a, b) {
                final ra = a.def.coins > 0 ? 1 : 0;
                final rb = b.def.coins > 0 ? 1 : 0;
                return ra != rb ? ra - rb : a.def.coins.compareTo(b.def.coins);
              });
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                for (final p in sorted)
                  KidPanel(
                    child: ListTile(
                      leading: p.def.coins > 0
                          ? const CoinIcon(size: 32)
                          : null,
                      title: Text(p.def.title),
                      subtitle: Text(p.def.description),
                      trailing: _owned(s, p.def)
                          ? const Chip(label: Text('Owned'))
                          : FilledButton(
                              key: TestIds.shopBuy(p.def.id),
                              onPressed: () => _buy(context, s, p.def.id),
                              child: Text(p.price),
                            ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Real-money purchases always go through the parent gate first.
  Future<void> _buy(BuildContext context, Services s, String id) async {
    if (await showParentGate(context, s.parentGate)) {
      await s.purchases.buy(id);
    }
  }

  bool _owned(Services s, ProductDef d) =>
      d.grants == ProductDef.removeAdsGrant && s.profile.data.adsRemoved;
}
