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

  Future<void> buy(String productId);
  Future<void> restore();
  void dispose();
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
  Future<void> restore() async {}
  @override
  void dispose() => _controller.close();
}
