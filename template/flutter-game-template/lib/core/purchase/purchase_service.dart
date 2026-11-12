import 'dart:async';

import '../config/products.dart';

class StoreProduct {
  const StoreProduct({required this.def, required this.price});
  final ProductDef def;

  /// Localised price string from the store, e.g. "$2.99".
  final String price;
}

enum PurchaseStatus { purchased, restored, canceled, failed }

class PurchaseUpdate {
  const PurchaseUpdate(this.productId, this.status, {this.purchaseId});
  final String productId;
  final PurchaseStatus status;

  /// Store order/purchase identifier, used to avoid granting twice.
  final String? purchaseId;
}

/// In-app purchases. UI depends on this interface only.
abstract interface class PurchaseService {
  Future<void> initialize();

  /// Billing is reachable and products loaded.
  bool get available;

  List<StoreProduct> get products;

  /// Delivery events (new purchases and restores). Grant entitlements from here.
  Stream<PurchaseUpdate> get updates;

  /// Loads store details of extra-pack products (`pack_<id>`, non-consumable) named by the
  /// content index. They are not in products.yaml.
  Future<void> registerExtraProducts(Set<String> productIds);

  /// Localised price of any loaded product (also extra packs), or null.
  String? priceOf(String productId);

  Future<void> buy(String productId);
  Future<void> restore();
  void dispose();

  /// Non-null when purchases cannot work in this build (the web copy): a parent-friendly sentence
  /// the UI shows instead of a buy flow.
  String? get unavailableMessage;
}

/// Shown in the web copy wherever a purchase would start.
const String webPurchasesMessage =
    'Purchases are not available in this web version. They work in the Android app.';

/// Web build: there is no store in a browser. Nothing can be bought or restored, and no product
/// is listed. It never pretends a purchase happened.
class UnavailablePurchaseService implements PurchaseService {
  @override
  Future<void> initialize() async {}
  @override
  bool get available => false;
  @override
  List<StoreProduct> get products => const [];
  @override
  Stream<PurchaseUpdate> get updates => const Stream.empty();
  @override
  Future<void> registerExtraProducts(Set<String> productIds) async {}
  @override
  String? priceOf(String productId) => null;
  @override
  Future<void> buy(String productId) async {}
  @override
  Future<void> restore() async {}
  @override
  void dispose() {}
  @override
  String? get unavailableMessage => webPurchasesMessage;
}

/// In-memory fake for tests: `buy` immediately emits a purchase.
class FakePurchaseService implements PurchaseService {
  FakePurchaseService(this.catalog);
  final ProductCatalog catalog;
  final _controller = StreamController<PurchaseUpdate>.broadcast();
  int _n = 0;

  @override
  Future<void> initialize() async {}
  @override
  bool get available => true;
  @override
  List<StoreProduct> get products => [
    for (final p in catalog.products) StoreProduct(def: p, price: '\$0.99'),
  ];
  @override
  Stream<PurchaseUpdate> get updates => _controller.stream;
  @override
  Future<void> buy(String productId) async {
    _controller.add(
      PurchaseUpdate(
        productId,
        PurchaseStatus.purchased,
        purchaseId: 'fake-${_n++}',
      ),
    );
  }

  @override
  Future<void> registerExtraProducts(Set<String> productIds) async {}
  @override
  String? priceOf(String productId) => '\$0.99';

  @override
  Future<void> restore() async {}
  @override
  void dispose() => _controller.close();
  @override
  String? get unavailableMessage => null;
}
