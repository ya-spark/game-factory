import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart' as iap;

import '../config/products.dart';
import 'purchase_service.dart';

/// Google Play Billing via the `in_app_purchase` plugin, driven by products.yaml.
class PlayPurchaseService implements PurchaseService {
  PlayPurchaseService(this.catalog, {iap.InAppPurchase? plugin})
    : _iap = plugin ?? iap.InAppPurchase.instance;

  final ProductCatalog catalog;
  final iap.InAppPurchase _iap;
  final _updates = StreamController<PurchaseUpdate>.broadcast();
  final Map<String, iap.ProductDetails> _details = {};
  StreamSubscription<List<iap.PurchaseDetails>>? _sub;
  bool _available = false;

  @override
  bool get available => _available;

  @override
  Stream<PurchaseUpdate> get updates => _updates.stream;

  @override
  List<StoreProduct> get products => [
    for (final def in catalog.products)
      if (_details[def.id] != null)
        StoreProduct(def: def, price: _details[def.id]!.price),
  ];

  @override
  Future<void> initialize() async {
    _sub ??= _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) {
        debugPrint('purchaseStream error: $e');
      },
    );
    try {
      _available = await _iap.isAvailable();
      if (!_available) return;
      final response = await _iap.queryProductDetails(catalog.ids);
      for (final d in response.productDetails) {
        _details[d.id] = d;
      }
    } on Object catch (e) {
      debugPrint('Billing init failed: $e');
      _available = false;
    }
  }

  Future<void> _onPurchases(List<iap.PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case iap.PurchaseStatus.pending:
          break;
        case iap.PurchaseStatus.purchased:
        case iap.PurchaseStatus.restored:
          _updates.add(
            PurchaseUpdate(
              p.productID,
              p.status == iap.PurchaseStatus.restored
                  ? PurchaseStatus.restored
                  : PurchaseStatus.purchased,
              purchaseId: p.purchaseID,
            ),
          );
        case iap.PurchaseStatus.canceled:
          _updates.add(PurchaseUpdate(p.productID, PurchaseStatus.canceled));
        case iap.PurchaseStatus.error:
          _updates.add(PurchaseUpdate(p.productID, PurchaseStatus.failed));
      }
      // Acknowledge/finish so Play does not refund the purchase after 3 days.
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
  }

  @override
  Future<void> buy(String productId) async {
    final details = _details[productId];
    final def = catalog.byId(productId);
    if (details == null || def == null) {
      _updates.add(PurchaseUpdate(productId, PurchaseStatus.failed));
      return;
    }
    final param = iap.PurchaseParam(productDetails: details);
    if (def.type == ProductType.consumable) {
      await _iap.buyConsumable(purchaseParam: param);
    } else {
      await _iap.buyNonConsumable(purchaseParam: param);
    }
  }

  @override
  Future<void> restore() => _iap.restorePurchases();

  @override
  void dispose() {
    _sub?.cancel();
    _updates.close();
  }
}
