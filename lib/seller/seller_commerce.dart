import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

String sellerMoney(int cents) => '₱${(cents / 100).toStringAsFixed(2)}';

enum SellerOrderStatus {
  toPack,
  ready,
  inTransit,
  delivered,
  completed,
  cancelled,
}

extension SellerOrderLabel on SellerOrderStatus {
  String get label => switch (this) {
    SellerOrderStatus.toPack => 'To pack',
    SellerOrderStatus.ready => 'Ready for pickup',
    SellerOrderStatus.inTransit => 'In transit',
    SellerOrderStatus.delivered => 'Delivered',
    SellerOrderStatus.completed => 'Completed',
    SellerOrderStatus.cancelled => 'Cancelled',
  };
}

class SellerProduct {
  SellerProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.category,
    this.description = '',
    this.active = true,
    this.editable = true,
  });
  final String id;
  final String name, category, description;
  final int price, stock;
  final bool active;
  final bool editable;
}

class SellerOrder {
  SellerOrder({
    required this.id,
    required this.buyer,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.address,
    required this.placedAt,
    required this.status,
    this.fee = 0,
    this.refund = 0,
    this.shipping = 5000,
    this.paidOut = false,
    this.itemsSubtotal,
    this.paymentMethod = 'COD',
    this.cancellable = true,
  });
  final String id, buyer, productId, productName, address;
  final int quantity, unitPrice, fee, refund, shipping;
  final DateTime placedAt;
  final bool paidOut;
  final String paymentMethod;
  final bool cancellable;
  final int? itemsSubtotal;
  SellerOrderStatus status;
  String? cancellationReason;
  int get subtotal => itemsSubtotal ?? unitPrice * quantity;
  int get net => subtotal - fee - refund;
}

/// Seller state backed by the API when connected; sample records otherwise.
class SellerCommerce extends ChangeNotifier {
  SellerCommerce({this.connected = false}) {
    if (connected) return;
    final now = DateTime.now();
    _products.addAll([
      SellerProduct(
        id: 'SP1',
        name: 'Handwoven market tote',
        price: 45000,
        stock: 12,
        category: 'Bags',
        description: 'A reusable everyday market bag.',
      ),
      SellerProduct(
        id: 'SP2',
        name: 'Rattan fruit basket',
        price: 35000,
        stock: 3,
        category: 'Home & Living',
      ),
      SellerProduct(
        id: 'SP3',
        name: 'Woven table runner',
        price: 28000,
        stock: 0,
        category: 'Home & Living',
        active: false,
      ),
    ]);
    for (final entry in [
      (
        'SO-1001',
        'Ana Reyes',
        'SP1',
        'Handwoven market tote',
        2,
        45000,
        SellerOrderStatus.toPack,
        0,
        false,
      ),
      (
        'SO-1002',
        'Juan Dela Cruz',
        'SP2',
        'Rattan fruit basket',
        1,
        35000,
        SellerOrderStatus.ready,
        0,
        false,
      ),
      (
        'SO-1003',
        'Mia Santos',
        'SP1',
        'Handwoven market tote',
        1,
        45000,
        SellerOrderStatus.inTransit,
        0,
        false,
      ),
      (
        'SO-1004',
        'Liza Ramos',
        'SP1',
        'Handwoven market tote',
        2,
        45000,
        SellerOrderStatus.completed,
        4500,
        false,
      ),
      (
        'SO-1005',
        'Carlo Cruz',
        'SP2',
        'Rattan fruit basket',
        1,
        35000,
        SellerOrderStatus.completed,
        1750,
        true,
      ),
    ].indexed) {
      final (id, buyer, productId, name, qty, price, status, fee, paid) =
          entry.$2;
      _orders.add(
        SellerOrder(
          id: id,
          buyer: buyer,
          productId: productId,
          productName: name,
          quantity: qty,
          unitPrice: price,
          address: 'Sample delivery address · Quezon City, NCR',
          placedAt: now.subtract(Duration(days: entry.$1)),
          status: status,
          fee: fee,
          paidOut: paid,
        ),
      );
    }
  }

  final List<SellerProduct> _products = [];
  final bool connected;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Map<String, dynamic> earnings = {};
  List<String> categories = [];

  Future<Map<String, dynamic>> load() async {
    final result = Map<String, dynamic>.from(
      await ApiService.get('/seller/workspace'),
    );
    if (_disposed) return {};
    _products.clear();
    for (final p in result['products']) {
      _products.add(
        SellerProduct(
          id: p['id'],
          name: p['name'],
          price: p['price'],
          stock: p['stock'],
          category: p['category'],
          description: p['description'],
          active: p['active'],
          editable: (p['variants'] as List).length == 1,
        ),
      );
    }
    _orders.clear();
    for (final o in result['orders']) {
      final items = o['items'] as List;
      _orders.add(
        SellerOrder(
          id: o['id'],
          buyer: o['buyer'],
          productId: items.isEmpty ? '' : items.first['product_id'],
          productName: items
              .map((i) => '${i['quantity']} × ${i['name']} (${i['variant']})')
              .join('\n'),
          quantity: 1,
          unitPrice: o['subtotal'],
          itemsSubtotal: o['subtotal'],
          address:
              '${o['address']['street']}, ${o['address']['city']}, ${o['address']['province']}',
          placedAt: DateTime.fromMillisecondsSinceEpoch(
            (o['date'] as num).toInt() * 1000,
          ),
          fee: o['commission'],
          paymentMethod: o['payment_method'],
          cancellable: ['pending', 'accepted'].contains(o['raw_status']),
          shipping: o['shipping'],
          status: switch (o['raw_status']) {
            'pending' || 'accepted' || 'packed' => SellerOrderStatus.toPack,
            'ready_to_ship' => SellerOrderStatus.ready,
            'completed' => SellerOrderStatus.completed,
            'delivered' => SellerOrderStatus.delivered,
            'cancelled' => SellerOrderStatus.cancelled,
            _ => SellerOrderStatus.inTransit,
          },
        ),
      );
    }
    earnings = Map<String, dynamic>.from(result['earnings']);
    categories = (result['categories'] as List)
        .map((c) => c['name'] as String)
        .toList();
    notifyListeners();
    return Map<String, dynamic>.from(result['shop']);
  }

  final List<SellerOrder> _orders = [];
  List<SellerProduct> get products => List.unmodifiable(_products);
  List<SellerOrder> get orders => List.unmodifiable(_orders);
  Iterable<SellerOrder> get completed =>
      _orders.where((o) => o.status == SellerOrderStatus.completed);
  int get grossSales => connected
      ? earnings['gross_sales'] ?? 0
      : completed.fold(0, (sum, o) => sum + o.subtotal);
  int get fees => connected
      ? earnings['fees'] ?? 0
      : completed.fold(0, (sum, o) => sum + o.fee);
  int get refunds => completed.fold(0, (sum, o) => sum + o.refund);
  int get netEarnings => connected
      ? earnings['net_sales'] ?? 0
      : completed.fold(0, (sum, o) => sum + o.net);
  int get awaitingSettlement =>
      completed.where((o) => !o.paidOut).fold(0, (sum, o) => sum + o.net);
  int get paidOut =>
      completed.where((o) => o.paidOut).fold(0, (sum, o) => sum + o.net);
  int get pendingSales => _orders
      .where(
        (o) =>
            o.status != SellerOrderStatus.completed &&
            o.status != SellerOrderStatus.cancelled,
      )
      .fold(0, (sum, o) => sum + o.subtotal);
  int get lowStock => _products.where((p) => p.stock <= 5).length;
  int get toPack =>
      _orders.where((o) => o.status == SellerOrderStatus.toPack).length;

  Future<void> saveProduct(SellerProduct product) async {
    if (product.name.trim().isEmpty ||
        product.price <= 0 ||
        product.stock < 0 ||
        product.category.trim().isEmpty) {
      throw ArgumentError(
        'Enter a name, category, positive price and valid stock.',
      );
    }
    if (connected) {
      final body = {
        'name': product.name,
        'price': product.price,
        'stock': product.stock,
        'category': product.category,
        'description': product.description,
        'active': product.active,
      };
      if (_products.any((p) => p.id == product.id)) {
        await ApiService.patch('/seller/products/${product.id}', body: body);
      } else {
        await ApiService.post('/seller/products', body: body);
      }
      await load();
      return;
    }
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index < 0) {
      _products.insert(0, product);
    } else {
      _products[index] = product;
    }
    notifyListeners();
  }

  Future<void> prepare(SellerOrder order) async {
    if (connected) {
      await ApiService.post('/seller/orders/${order.id}/prepare', body: {});
      await load();
      return;
    }
    if (!_orders.contains(order) || order.status != SellerOrderStatus.toPack) {
      throw StateError('Only orders waiting to be packed can be prepared.');
    }
    order.status = SellerOrderStatus.ready;
    notifyListeners();
  }

  Future<void> cancel(SellerOrder order, String reason) async {
    if (connected) {
      await ApiService.post(
        '/seller/orders/${order.id}/cancel',
        body: {'reason': reason},
      );
      await load();
      return;
    }
    if (!_orders.contains(order) ||
        order.status != SellerOrderStatus.toPack ||
        reason.trim().isEmpty) {
      throw StateError('Only unpacked orders can be cancelled, with a reason.');
    }
    order.status = SellerOrderStatus.cancelled;
    order.cancellationReason = reason.trim();
    final index = _products.indexWhere((p) => p.id == order.productId);
    if (index >= 0) {
      final p = _products[index];
      _products[index] = SellerProduct(
        id: p.id,
        name: p.name,
        price: p.price,
        stock: p.stock + order.quantity,
        category: p.category,
        description: p.description,
        active: p.active,
      );
    }
    notifyListeners();
  }
}
