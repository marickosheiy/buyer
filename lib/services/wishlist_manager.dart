import 'package:flutter/foundation.dart';

import '../product_model.dart';
import 'api_service.dart';

/// Session-only, matching the existing cart/address managers. No database writes.
class WishlistManager extends ChangeNotifier {
  WishlistManager._();
  static final instance = WishlistManager._();
  final Map<String, LumearProduct> _products = {};
  Future<void> Function()? reload;
  void replace(List<dynamic> rows) {
    _products.clear();
    for (final r in rows) {
      final p = lumearProducts
          .where((p) => p.id == r['id'].toString())
          .firstOrNull;
      if (p != null) _products[p.id] = p;
    }
    notifyListeners();
  }

  List<LumearProduct> get items => List.unmodifiable(_products.values);
  bool contains(String id) => _products.containsKey(id);
  void clear() {
    _products.clear();
    notifyListeners();
  }

  Future<void> toggle(LumearProduct product) async {
    if (reload != null) {
      if (contains(product.id)) {
        await ApiService.delete('/wishlist/${product.id}');
      } else {
        await ApiService.post('/wishlist/${product.id}', body: {});
      }
      await reload!();
      return;
    }
    if (contains(product.id)) {
      _products.remove(product.id);
    } else {
      _products[product.id] = product;
    }
    notifyListeners();
  }
}
