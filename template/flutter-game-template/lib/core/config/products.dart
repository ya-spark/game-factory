import 'package:yaml/yaml.dart';

enum ProductType { consumable, nonConsumable }

/// One entry of `products.yaml`.
class ProductDef {
  const ProductDef({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.coins = 0,
    this.grants,
  });

  final String id;
  final ProductType type;
  final String title;
  final String description;
  final int coins;

  /// Special entitlement, e.g. `remove_ads`.
  final String? grants;

  static const String removeAdsGrant = 'remove_ads';
}

class ProductCatalog {
  const ProductCatalog(this.products);

  final List<ProductDef> products;

  ProductDef? byId(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Set<String> get ids => {for (final p in products) p.id};

  factory ProductCatalog.fromYamlString(String source) {
    final root = loadYaml(source) as YamlMap;
    final list = (root['products'] as YamlList?) ?? YamlList();
    return ProductCatalog([
      for (final e in list.cast<YamlMap>())
        ProductDef(
          id: e['id'] as String,
          type: switch (e['type']) {
            'consumable' => ProductType.consumable,
            'non_consumable' => ProductType.nonConsumable,
            final t => throw FormatException('Unknown product type: $t'),
          },
          title: e['title'] as String,
          description: (e['description'] as String?) ?? '',
          coins: (e['coins'] as int?) ?? 0,
          grants: e['grants'] as String?,
        ),
    ]);
  }
}
