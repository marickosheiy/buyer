import 'package:flutter/material.dart';

import 'cart_manager.dart';

class PlacedOrder {
  final String orderId;

  // Products purchased in this order
  final List<CartItem> items;

  // Customer information
  final String name;
  final String phone;
  final String address;

  // Payment
  final String paymentMethod;

  // Order information
  final DateTime date;
  final double subtotal;
  final double shippingFee;
  final double total;

  // Order status
  String status;
  final String storeName;
  final List<Map<String, dynamic>> timeline;

  PlacedOrder({
    required this.orderId,
    required this.items,
    required this.name,
    required this.phone,
    required this.address,
    required this.paymentMethod,
    required this.date,
    required this.subtotal,
    required this.shippingFee,
    required this.total,
    this.status = 'To Ship',
    this.storeName = '',
    this.timeline = const [],
  });

  int get itemCount {
    int count = 0;

    for (final item in items) {
      count += item.quantity;
    }

    return count;
  }

  String get formattedSubtotal {
    return '₱${subtotal.toStringAsFixed(2)}';
  }

  String get formattedShippingFee {
    if (shippingFee == 0) {
      return 'FREE';
    }

    return '₱${shippingFee.toStringAsFixed(2)}';
  }

  String get formattedTotal {
    return '₱${total.toStringAsFixed(2)}';
  }

  String get formattedDate {
    return '${date.month}/${date.day}/${date.year}';
  }

  String get formattedDateTime {
    final hour = date.hour > 12
        ? date.hour - 12
        : date.hour == 0
        ? 12
        : date.hour;

    final minute = date.minute.toString().padLeft(2, '0');

    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '${date.month}/${date.day}/${date.year} '
        '$hour:$minute $period';
  }
}

class OrderManager extends ChangeNotifier {
  OrderManager._();

  static final OrderManager instance = OrderManager._();

  final List<PlacedOrder> _orders = [];
  bool connected = false;
  void replace(List<dynamic> rows) {
    connected = true;
    _orders.clear();
    _orders.addAll(
      rows.map(
        (o) => PlacedOrder(
          orderId: o['id'].toString(),
          items: [
            for (final i in o['items'])
              CartItem(
                id: i['product_id'].toString(),
                name: i['name'],
                price: (i['price'] as num) / 100,
                icon: Icons.shopping_bag_outlined,
                quantity: i['quantity'],
                selectedVariants: {'Option': i['variant'] ?? ''},
              ),
          ],
          name: o['address']['name'] ?? '',
          phone: o['address']['phone'] ?? '',
          address:
              '${o['address']['street']}, ${o['address']['city']}, ${o['address']['province']}',
          paymentMethod: o['payment_method'],
          date: DateTime.fromMillisecondsSinceEpoch(
            (o['date'] as num).toInt() * 1000,
          ),
          subtotal: (o['subtotal'] as num) / 100,
          shippingFee: (o['shipping'] as num) / 100,
          total: (o['total'] as num) / 100,
          status: o['raw_status'] == 'delivered' ? 'Delivered' : o['status'],
          storeName: o['store'],
          timeline: [
            for (final e in o['timeline']) Map<String, dynamic>.from(e),
          ],
        ),
      ),
    );
    notifyListeners();
  }

  // Read-only list for screens
  List<PlacedOrder> get orders {
    return List.unmodifiable(_orders);
  }

  // Number of orders
  int get orderCount {
    return _orders.length;
  }

  // Latest order
  PlacedOrder? get latestOrder {
    if (_orders.isEmpty) {
      return null;
    }

    return _orders.first;
  }

  // Get order by ID
  PlacedOrder? getOrderById(String orderId) {
    try {
      return _orders.firstWhere((order) => order.orderId == orderId);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // ADD ORDER
  // ============================================================

  void addOrder({
    required List<CartItem> items,
    required String name,
    required String phone,
    required String address,
    required String paymentMethod,
    required double subtotal,
    required double shippingFee,
    required double total,
  }) {
    // Create a complete copy of every cart item.
    //
    // This is important because the cart will be cleared
    // after checkout. The order must keep its own copy.
    final copiedItems = items.map((item) {
      return CartItem(
        id: item.id,
        name: item.name,
        price: item.price,
        icon: item.icon,
        imageUrl: item.imageUrl,
        selectedVariants: Map<String, String>.from(item.selectedVariants),
        quantity: item.quantity,
      );
    }).toList();

    final newOrder = PlacedOrder(
      orderId: 'LM${DateTime.now().millisecondsSinceEpoch}',
      items: copiedItems,
      name: name,
      phone: phone,
      address: address,
      paymentMethod: paymentMethod,
      date: DateTime.now(),
      subtotal: subtotal,
      shippingFee: shippingFee,
      total: total,
      status: 'To Ship',
    );

    // Newest orders appear first.
    _orders.insert(0, newOrder);

    // Tell OrdersScreen and other listeners to update.
    notifyListeners();
  }

  // ============================================================
  // UPDATE ORDER STATUS
  // ============================================================

  void updateOrderStatus({required String orderId, required String status}) {
    final order = getOrderById(orderId);

    if (order == null) {
      return;
    }

    order.status = status;

    notifyListeners();
  }

  // ============================================================
  // CANCEL ORDER
  // ============================================================

  void cancelOrder(String orderId) {
    final order = getOrderById(orderId);

    if (order == null) {
      return;
    }

    order.status = 'Cancelled';

    notifyListeners();
  }

  // ============================================================
  // MARK AS TO SHIP
  // ============================================================

  void markToShip(String orderId) {
    updateOrderStatus(orderId: orderId, status: 'To Ship');
  }

  // ============================================================
  // MARK AS TO RECEIVE
  // ============================================================

  void markToReceive(String orderId) {
    updateOrderStatus(orderId: orderId, status: 'To Receive');
  }

  // ============================================================
  // MARK AS DELIVERED
  // ============================================================

  void markDelivered(String orderId) {
    updateOrderStatus(orderId: orderId, status: 'Delivered');
  }

  // ============================================================
  // CLEAR ALL ORDERS
  // ============================================================

  void clearOrders() {
    _orders.clear();

    notifyListeners();
  }
}
