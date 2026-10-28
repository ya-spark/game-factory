import 'package:flutter/material.dart';

import '../core/config/products.dart';
import '../core/services.dart';
import 'test_ids.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: [
          TextButton(
            key: TestIds.shopRestore,
            onPressed: s.purchases.restore,
            child: const Text('Restore'),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: s.profile,
        builder: (context, _) {
          final products = s.purchases.products;
          if (!s.purchases.available || products.isEmpty) {
            return const Center(
              key: TestIds.shopUnavailable,
              child: Text('Store unavailable right now.'),
            );
          }
          return ListView(
            children: [
              for (final p in products)
                ListTile(
                  title: Text(p.def.title),
                  subtitle: Text(p.def.description),
                  trailing: _owned(s, p.def)
                      ? const Chip(label: Text('Owned'))
                      : FilledButton(
                          key: TestIds.shopBuy(p.def.id),
                          onPressed: () => s.purchases.buy(p.def.id),
                          child: Text(p.price),
                        ),
                ),
            ],
          );
        },
      ),
    );
  }

  bool _owned(Services s, ProductDef d) =>
      d.grants == ProductDef.removeAdsGrant && s.profile.data.adsRemoved;
}
