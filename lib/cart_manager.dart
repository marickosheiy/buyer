import 'package:flutter/material.dart';

class CartItem {
  final String name;
  final String price;
  final IconData icon;
  int quantity;

  CartItem({
    required this.name,
    required this.price,
    required this.icon,
    this.quantity = 1,
  });
}

class CartManager {
  CartManager._();

  static final CartManager instance = CartManager._();

  final ValueNotifier<List<CartItem>> items =
      ValueNotifier<List<CartItem>>([]);

  void addToCart({
    required String name,
    required String price,
    required IconData icon,
  }) {
    final updatedItems = List<CartItem>.from(items.value);

    final index = updatedItems.indexWhere(
      (item) => item.name == name,
    );

    if (index != -1) {
      updatedItems[index].quantity++;
    } else {
      updatedItems.add(
        CartItem(
          name: name,
          price: price,
          icon: icon,
        ),
      );
    }

    items.value = updatedItems;
  }

  void increaseQuantity(CartItem item) {
    item.quantity++;

    items.value = List<CartItem>.from(items.value);
  }

  void decreaseQuantity(CartItem item) {
    if (item.quantity > 1) {
      item.quantity--;
    } else {
      removeFromCart(item);
      return;
    }

    items.value = List<CartItem>.from(items.value);
  }

  void removeFromCart(CartItem item) {
    final updatedItems = List<CartItem>.from(items.value);

    updatedItems.remove(item);

    items.value = updatedItems;
  }

  void clearCart() {
    items.value = [];
  }

  int get totalItems {
    return items.value.fold(
      0,
      (total, item) => total + item.quantity,
    );
  }
}