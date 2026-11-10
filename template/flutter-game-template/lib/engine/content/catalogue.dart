/// Pack catalogue: price tiers, product-id rules, year bundles, and the product list that the
/// Play sync and the Play Console import are generated from (issue 1D). Pure Dart.
///
/// Products are never typed by hand: a pack names a `tier` in its manifest (never a price), the
/// catalogue maps tiers to prices, and [buildProducts] derives every Play product from that.
library;

import 'dart:convert';

/// Longest product id Play accepts.
const int maxProductIdLength = 40;

final RegExp _packIdRe = RegExp(
  r'^pack_([a-z]+)_(0|[1-9]|1[0-2])_([a-z0-9]+(?:_[a-z0-9]+)*)$',
);
final RegExp _bundleIdRe = RegExp(
  r'^bundle_(0|[1-9]|1[0-2])_([a-z0-9]+(?:_[a-z0-9]+)*)$',
);
final RegExp _priceRe = RegExp(r'^\d{1,4}\.\d{2}$');
final RegExp _tierRe = RegExp(r'^[a-z][a-z0-9_]*$');

/// The reason [id] is not a valid pack product id, or null when it is valid.
///
/// Rule: `pack_<subject>_<year>_<slug>`, lower case, digits and underscores, at most
/// [maxProductIdLength] characters. Year `0` is Foundation. Pass [subject] and [year] to
/// check that the id matches the pack it belongs to.
String? packProductIdProblem(String id, {String? subject, int? year}) {
  final m = _packIdRe.firstMatch(id);
  if (m == null) {
    return '"$id" is not a pack product id (pack_<subject>_<year>_<slug>, '
        'lower case letters, digits and underscores)';
  }
  if (id.length > maxProductIdLength) {
    return '"$id" is longer than $maxProductIdLength characters';
  }
  if (subject != null && m.group(1) != subject) {
    return '"$id" names subject "${m.group(1)}" but the pack is "$subject"';
  }
  if (year != null && int.parse(m.group(2)!) != year) {
    return '"$id" names year ${m.group(2)} but the pack is year $year';
  }
  return null;
}

/// The reason [id] is not a valid bundle product id (`bundle_<year>_<slug>`), or null.
String? bundleProductIdProblem(String id, {int? year}) {
  final m = _bundleIdRe.firstMatch(id);
  if (m == null) {
    return '"$id" is not a bundle product id (bundle_<year>_<slug>, '
        'lower case letters, digits and underscores)';
  }
  if (id.length > maxProductIdLength) {
    return '"$id" is longer than $maxProductIdLength characters';
  }
  if (year != null && int.parse(m.group(1)!) != year) {
    return '"$id" names year ${m.group(1)} but the bundle is year $year';
  }
  return null;
}

/// A year bundle: one product that unlocks every pack of [year] (and of [subject] when set).
class BundleDef {
  const BundleDef({
    required this.productId,
    required this.title,
    required this.description,
    required this.year,
    required this.tier,
    this.subject,
    this.status = 'draft',
  });

  final String productId;
  final String title;
  final String description;
  final int year;
  final String tier;
  final String? subject;
  final String status;
}

/// The catalogue file (`content/catalogue.json`): currency, price tiers, bundles and the
/// product ids that were retired and can never be used again.
class Catalogue {
  const Catalogue({
    required this.currency,
    required this.region,
    required this.tiers,
    required this.bundles,
    required this.retiredIds,
  });

  /// ISO currency code of every tier price.
  final String currency;

  /// Region the price applies to in the Play Console import (for example `AU`).
  final String region;

  /// Tier id to price text (`1.99`). Text, not a double: no rounding.
  final Map<String, String> tiers;
  final List<BundleDef> bundles;

  /// Ids that were once created and are gone. A deleted Play id cannot be reused.
  final Set<String> retiredIds;

  /// Price text of [tier], or null when the tier does not exist.
  String? priceOf(String tier) => tiers[tier];

  /// Parses and checks the catalogue. Throws [FormatException] with every problem found.
  factory Catalogue.parse(String text) {
    final Object? j;
    try {
      j = jsonDecode(text);
    } on FormatException catch (e) {
      throw FormatException('catalogue is not valid JSON (${e.message})');
    }
    final problems = <String>[];
    if (j is! Map) {
      throw const FormatException('catalogue must be a JSON object');
    }
    final currency = j['currency'];
    if (currency is! String || !RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      problems.add('"currency" must be an ISO code such as AUD');
    }
    final region = j['region'];
    if (region is! String || !RegExp(r'^[A-Z]{2}$').hasMatch(region)) {
      problems.add('"region" must be a two letter code such as AU');
    }
    final tiers = <String, String>{};
    final rawTiers = j['tiers'];
    if (rawTiers is! Map || rawTiers.isEmpty) {
      problems.add('"tiers" must be a non-empty object of tier id to price');
    } else {
      for (final e in rawTiers.entries) {
        final id = '${e.key}';
        final price = e.value;
        if (!_tierRe.hasMatch(id)) {
          problems.add('tier id "$id" must be lower case letters and digits');
        } else if (price is! String || !_priceRe.hasMatch(price)) {
          problems.add('tier "$id": price must be text like "1.99"');
        } else {
          tiers[id] = price;
        }
      }
    }
    final bundles = <BundleDef>[];
    for (final b in (j['bundles'] as List? ?? const [])) {
      if (b is! Map) {
        problems.add('a bundle must be an object');
        continue;
      }
      final pid = b['product_id'];
      final year = b['year'];
      final tier = b['tier'];
      final title = b['title'];
      final status = b['status'] ?? 'draft';
      if (pid is! String || year is! int) {
        problems.add('a bundle needs "product_id" and "year"');
        continue;
      }
      final p = bundleProductIdProblem(pid, year: year);
      if (p != null) problems.add(p);
      if (tier is! String || !tiers.containsKey(tier)) {
        problems.add('bundle $pid: unknown tier "$tier"');
      }
      if (title is! String || title.trim().isEmpty) {
        problems.add('bundle $pid: "title" is missing');
      }
      if (status != 'draft' && status != 'live') {
        problems.add('bundle $pid: "status" must be draft or live');
      }
      bundles.add(
        BundleDef(
          productId: pid,
          title: title is String ? title : '',
          description: b['description'] is String
              ? b['description'] as String
              : '',
          year: year,
          tier: tier is String ? tier : '',
          subject: b['subject'] as String?,
          status: '$status',
        ),
      );
    }
    final retired = {
      for (final r in (j['retired_ids'] as List? ?? const [])) '$r',
    };
    if (problems.isNotEmpty) throw FormatException(problems.join('; '));
    return Catalogue(
      currency: currency! as String,
      region: region! as String,
      tiers: tiers,
      bundles: bundles,
      retiredIds: retired,
    );
  }
}

/// One Play product derived from a pack or a bundle.
class ProductSpec {
  const ProductSpec({
    required this.productId,
    required this.kind,
    required this.title,
    required this.description,
    required this.tier,
    required this.price,
    required this.status,
    required this.packs,
  });

  final String productId;

  /// `pack` or `bundle`.
  final String kind;
  final String title;
  final String description;
  final String tier;
  final String price;
  final String status;

  /// Pack ids the product unlocks (one for a pack).
  final List<String> packs;

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'kind': kind,
    'title': title,
    'description': description,
    'tier': tier,
    'price': price,
    'status': status,
    'packs': packs,
  };
}

/// Result of [buildProducts].
class ProductPlan {
  const ProductPlan(this.products, this.problems, this.catalogue);
  final List<ProductSpec> products;
  final List<String> problems;
  final Catalogue catalogue;
  bool get ok => problems.isEmpty;

  /// The list the sync workflow reads. Deterministic: sorted by product id, no timestamps.
  String toJsonText() =>
      '${const JsonEncoder.withIndent('  ').convert({
        'format': 1,
        'currency': catalogue.currency,
        'region': catalogue.region,
        'products': [for (final p in products) p.toJson()],
      })}\n';

  /// The Play Console one-time-products import file (same columns as
  /// `docs/play-import/one_time_products_sample.csv`), a fallback to the API sync.
  String toPlayCsv() {
    final buf = StringBuffer()..writeln(_csvColumns.join(','));
    for (final p in products) {
      // Row 1: the listing text. Row 2: the purchase option (a non-consumable, one quantity).
      buf.writeln(
        _csvRow(_csvColumns, {
          'productId': p.productId,
          'languageCode': 'en-AU',
          'name': p.title,
          'description': p.description,
          'productTaxCategory': 'Digital app sales',
        }),
      );
      buf.writeln(
        _csvRow(_csvColumns, {
          'productId': p.productId,
          'purchaseOptionId': 'buy',
          'purchaseOptionState': 'active',
          'purchaseOptionType': 'buy',
          'backwardsCompatible': 'true',
          'multiQuantityEnabled': 'false',
          'region': catalogue.region,
          'price': '${catalogue.currency} ${p.price}',
          'availability': 'available',
          'digitalContentOrServiceClassification': 'digitalContent',
        }),
      );
    }
    return buf.toString();
  }
}

const List<String> _csvColumns = [
  'productId',
  'languageCode',
  'name',
  'description',
  'productTaxCategory',
  'isTokenizedDigitalAsset',
  'ageRating',
  'paymentLocationRestrictionRegions',
  'purchaseOptionId',
  'purchaseOptionState',
  'purchaseOptionType',
  'backwardsCompatible',
  'multiQuantityEnabled',
  'rentalPeriod',
  'rentalInitiationPeriod',
  'region',
  'price',
  'availability',
  'purchaseOptionTags',
  'digitalContentOrServiceClassification',
  'offerId',
  'offerState',
  'preOrderStartTime',
  'preOrderEndTime',
  'preOrderReleaseTime',
  'preOrderPriceChangeBehavior',
  'discountedStartTime',
  'discountedEndTime',
  'discountedPurchaseLimit',
  'gameRewardRedemptionLimit',
  'offerRegion',
  'noOverride',
  'offerRelativeDiscount',
  'offerAbsoluteDiscount',
  'offerAvailability',
  'offerTags',
  'productTags',
  'lastUpdatedTime',
  'icon',
];

String _csvCell(String v) =>
    v.contains(RegExp(r'[",\n]')) ? '"${v.replaceAll('"', '""')}"' : v;

String _csvRow(List<String> columns, Map<String, String> values) =>
    columns.map((c) => _csvCell(values[c] ?? '')).join(',');

/// Derives the product list from the pack manifests (decoded pack JSON) and the [catalogue].
///
/// Checks: the product-id rule and that the id matches the pack's subject and year, a known
/// tier on every extra pack, no id used twice, no retired id reused, Play's text limits, and
/// that every bundle covers at least one pack. Built-in packs (no `product_id`) make no product.
ProductPlan buildProducts(
  Catalogue catalogue,
  List<Map<String, dynamic>> packs,
) {
  final problems = <String>[];
  final byId = <String, ProductSpec>{};
  final owner = <String, String>{};

  void add(ProductSpec p, String from) {
    if (owner.containsKey(p.productId)) {
      problems.add(
        'product id "${p.productId}" is used by both ${owner[p.productId]} and $from',
      );
      return;
    }
    if (catalogue.retiredIds.contains(p.productId)) {
      problems.add(
        'product id "${p.productId}" ($from) is retired and can never be reused',
      );
    }
    if (p.title.length > 55) {
      problems.add('${p.productId}: title is longer than 55 characters');
    }
    if (p.description.length > 200) {
      problems.add('${p.productId}: description is longer than 200 characters');
    }
    owner[p.productId] = from;
    byId[p.productId] = p;
  }

  final extras = <Map<String, dynamic>>[];
  for (final pack in packs) {
    final pid = pack['product_id'];
    if (pid == null) continue;
    extras.add(pack);
    final id = '${pack['id']}';
    final idProblem = pid is String
        ? packProductIdProblem(
            pid,
            subject: pack['subject'] as String?,
            year: pack['year'] as int?,
          )
        : 'pack $id: "product_id" must be text';
    if (idProblem != null) {
      problems.add('pack $id: $idProblem');
      continue;
    }
    final tier = pack['tier'];
    final price = tier is String ? catalogue.priceOf(tier) : null;
    if (price == null) {
      problems.add(
        'pack $id: needs a "tier" from the catalogue '
        '(${catalogue.tiers.keys.join(', ')}), got "$tier"',
      );
      continue;
    }
    final status = pack['status'] ?? 'draft';
    if (status != 'draft' && status != 'live') {
      problems.add('pack $id: "status" must be draft or live');
      continue;
    }
    final preview = pack['preview'];
    add(
      ProductSpec(
        productId: pid as String,
        kind: 'pack',
        title: '${pack['title']}',
        description: preview is Map && preview['description'] is String
            ? preview['description'] as String
            : '${pack['title']}',
        tier: tier as String,
        price: price,
        status: '$status',
        packs: [id],
      ),
      'pack $id',
    );
  }

  for (final b in catalogue.bundles) {
    final ids = bundlePackIds(b, extras);
    if (ids.isEmpty) {
      problems.add('bundle ${b.productId}: no pack of year ${b.year} yet');
    }
    add(
      ProductSpec(
        productId: b.productId,
        kind: 'bundle',
        title: b.title,
        description: b.description.isEmpty ? b.title : b.description,
        tier: b.tier,
        price: catalogue.priceOf(b.tier) ?? '',
        status: b.status,
        packs: ids,
      ),
      'bundle ${b.productId}',
    );
  }
  final list = byId.values.toList()
    ..sort((a, b) => a.productId.compareTo(b.productId));
  return ProductPlan(list, problems, catalogue);
}

/// Ids of the extra packs a bundle unlocks: every extra pack of its year (and subject).
List<String> bundlePackIds(BundleDef b, List<Map<String, dynamic>> packs) => [
  for (final p in packs)
    if (p['product_id'] != null &&
        p['year'] == b.year &&
        (b.subject == null || p['subject'] == b.subject))
      '${p['id']}',
]..sort();
