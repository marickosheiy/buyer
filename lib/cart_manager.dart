import 'package:flutter/material.dart';

import 'services/api_service.dart';
import 'product_model.dart';

class CartItem {
  final String id;
  final String name;
  final double price;
  final IconData icon;

  // Product information
  final String? imageUrl;

  // Selected variants
  final Map<String, String> selectedVariants;
  final String? serverId;
  final String? variantId;

  // Quantity
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.icon,
    this.imageUrl,
    this.selectedVariants = const {},
    this.quantity = 1,
    this.serverId,
    this.variantId,
  });

  // ==========================================================
  // FORMATTED PRICE
  // ==========================================================

  String get formattedPrice {
    return '₱${price.toStringAsFixed(2)}';
  }

  // ==========================================================
  // TOTAL PRICE
  // ==========================================================

  double get totalPrice {
    return price * quantity;
  }

  String get formattedTotalPrice {
    return '₱${totalPrice.toStringAsFixed(2)}';
  }

  // ==========================================================
  // VARIANT DISPLAY
  // ==========================================================

  String get variantText {
    if (selectedVariants.isEmpty) {
      return '';
    }

    return selectedVariants.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' • ');
  }
}

// ============================================================
// CART MANAGER
// ============================================================

class CartManager extends ChangeNotifier {
  CartManager._();

  static final CartManager instance = CartManager._();

  final List<CartItem> _items = [];
  Future<void> Function()? reload;
  bool get connected => reload != null;
  void replace(List<dynamic> rows) {
    _items.clear();
    _items.addAll(
      rows.map(
        (i) => CartItem(
          id: i['product_id'].toString(),
          serverId: i['id'].toString(),
          variantId: i['variant_id'].toString(),
          name: i['name'],
          price: (i['price'] as num) / 100,
          quantity: i['quantity'],
          icon: Icons.shopping_bag_outlined,
          imageUrl: lumearProducts
              .where((p) => p.id == i['product_id'].toString())
              .firstOrNull
              ?.imageUrl,
          selectedVariants: {'Option': i['variant'] ?? ''},
        ),
      ),
    );
    notifyListeners();
  }

  // ==========================================================
  // GET ITEMS
  // ==========================================================

  List<CartItem> get items {
    return List.unmodifiable(_items);
  }

  // ==========================================================
  // ITEM COUNT
  // ==========================================================

  int get itemCount {
    int total = 0;

    for (final item in _items) {
      total += item.quantity;
    }

    return total;
  }

  // ==========================================================
  // TOTAL PRICE
  // ==========================================================

  double get totalPrice {
    double total = 0;

    for (final item in _items) {
      total += item.totalPrice;
    }

    return total;
  }

  String get formattedTotalPrice {
    return '₱${totalPrice.toStringAsFixed(2)}';
  }

  // ==========================================================
  // ADD TO CART
  // ==========================================================

  Future<void> addToCart({
    required String name,
    required String price,
    required IconData icon,
    String? imageUrl,
    String? productId,
    Map<String, String>? selectedVariants,
    int quantity = 1,
  }) async {
    if (connected) {
      final product = lumearProducts.firstWhere((p) => p.id == productId);
      final selected = selectedVariants ?? {};
      final variant = product.variants.first;
      final vid = variant.idsByOption[selected[variant.name]];
      if (vid == null) throw const ApiException('Choose a product option.');
      await ApiService.post(
        '/cart',
        body: {
          'product_id': productId,
          'variant_id': vid,
          'quantity': quantity,
        },
      );
      await reload!();
      return;
    }
    // Convert:
    // "₱499"
    // "₱1,299"
    // "499"
    // "1,299"
    //
    // into a double.

    final cleanedPrice = price.replaceAll('₱', '').replaceAll(',', '').trim();

    final parsedPrice = double.tryParse(cleanedPrice) ?? 0;

    final actualProductId = productId ?? name.toLowerCase();

    final variants = selectedVariants ?? {};

    // ========================================================
    // CHECK IF SAME PRODUCT + SAME VARIANT ALREADY EXISTS
    // ========================================================

    final existingIndex = _items.indexWhere((item) {
      return item.id == actualProductId &&
          _mapsAreEqual(item.selectedVariants, variants);
    });

    if (existingIndex != -1) {
      _items[existingIndex].quantity += quantity;

      notifyListeners();
      return;
    }

    // ========================================================
    // ADD NEW ITEM
    // ========================================================

    _items.add(
      CartItem(
        id: actualProductId,
        name: name,
        price: parsedPrice,
        icon: icon,
        imageUrl: imageUrl,
        selectedVariants: Map<String, String>.from(variants),
        quantity: quantity,
      ),
    );

    notifyListeners();
  }

  // ==========================================================
  // CHECK IF MAPS ARE EQUAL
  // ==========================================================

  bool _mapsAreEqual(Map<String, String> first, Map<String, String> second) {
    if (first.length != second.length) {
      return false;
    }

    for (final key in first.keys) {
      if (first[key] != second[key]) {
        return false;
      }
    }

    return true;
  }

  // ==========================================================
  // INCREASE QUANTITY
  // ==========================================================

  Future<void> increaseQuantity(int index) async {
    if (connected) {
      await setQuantity(index, _items[index].quantity + 1);
      return;
    }
    if (index < 0 || index >= _items.length) {
      return;
    }

    _items[index].quantity++;

    notifyListeners();
  }

  // ==========================================================
  // DECREASE QUANTITY
  // ==========================================================

  Future<void> decreaseQuantity(int index) async {
    if (connected) {
      await setQuantity(index, _items[index].quantity - 1);
      return;
    }
    if (index < 0 || index >= _items.length) {
      return;
    }

    if (_items[index].quantity > 1) {
      _items[index].quantity--;
    } else {
      _items.removeAt(index);
    }

    notifyListeners();
  }

  // ==========================================================
  // SET QUANTITY
  // ==========================================================

  Future<void> setQuantity(int index, int quantity) async {
    if (connected) {
      final id = _items[index].serverId;
      if (quantity <= 0) {
        await ApiService.delete('/cart/$id');
      } else {
        await ApiService.patch('/cart/$id', body: {'quantity': quantity});
      }
      await reload!();
      return;
    }
    if (index < 0 || index >= _items.length) {
      return;
    }

    if (quantity <= 0) {
      _items.removeAt(index);
    } else {
      _items[index].quantity = quantity;
    }

    notifyListeners();
  }

  // ==========================================================
  // REMOVE ITEM
  // ==========================================================

  Future<void> removeFromCart(int index) async {
    if (connected) {
      await setQuantity(index, 0);
      return;
    }
    if (index < 0 || index >= _items.length) {
      return;
    }

    _items.removeAt(index);

    notifyListeners();
  }

  // ==========================================================
  // CLEAR CART
  // ==========================================================

  void clearCart() {
    _items.clear();

    notifyListeners();
  }

  // ==========================================================
  // CHECK IF CART IS EMPTY
  // ==========================================================

  bool get isEmpty {
    return _items.isEmpty;
  }

  bool get isNotEmpty {
    return _items.isNotEmpty;
  }
}
