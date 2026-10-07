import 'package:flutter/material.dart';

import 'cart_manager.dart';

class PlacedOrder {
  final String orderId;
  final List<CartItem> items;
  final String name;
  final String phone;
  final String address;
  final String paymentMethod;
  final DateTime date;
  final double total;
  String status;

  PlacedOrder({
    required this.orderId,
    required this.items,
    required this.name,
    required this.phone,
    required this.address,
    required this.paymentMethod,
    required this.date,
    required this.total,
    this.status = 'To Ship',
  });
}

class OrderManager {
  OrderManager._();

  static final OrderManager instance = OrderManager._();

  final ValueNotifier<List<PlacedOrder>> orders =
      ValueNotifier<List<PlacedOrder>>([]);

  void addOrder({
    required List<CartItem> items,
    required String name,
    required String phone,
    required String address,
    required String paymentMethod,
    required double total,
  }) {
    final copiedItems = items
        .map(
          (item) => CartItem(
            name: item.name,
            price: item.price,
            icon: item.icon,
            quantity: item.quantity,
          ),
        )
        .toList();

    final newOrder = PlacedOrder(
      orderId: 'LM${DateTime.now().millisecondsSinceEpoch}',
      items: copiedItems,
      name: name,
      phone: phone,
      address: address,
      paymentMethod: paymentMethod,
      date: DateTime.now(),
      total: total,
    );

    final updatedOrders =
        List<PlacedOrder>.from(orders.value);

    updatedOrders.insert(0, newOrder);

    orders.value = updatedOrders;
  }
}