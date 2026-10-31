import 'product_media.dart';

import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../services/marketplace_policy.dart';

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
    this.subcategory = '',
    this.variety = 'Default',
    this.description = '',
    this.active = true,
    this.editable = true,
    this.media = const [],
  });
  final String id;
  final String name, category, description;
  final String subcategory;
  final String variety;
  final int price, stock;
  final bool active;
  final bool editable;
  final List<ProductMedia> media;
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
    int? fee,
    this.refund = 0,
    this.shipping = MarketplacePolicy.shippingCentavos,
    this.paidOut = false,
    this.itemsSubtotal,
    this.paymentMethod = 'COD',
    this.cancellable = true,
    this.completedAt,
    this.rawStatus,
  }) : _recordedFee = fee;
  final String id, buyer, productId, productName, address;
  final int quantity, unitPrice, refund, shipping;
  final int? _recordedFee;
  final DateTime placedAt;
  final DateTime? completedAt;
  final bool paidOut;
  final String paymentMethod;
  bool cancellable;
  final int? itemsSubtotal;
  SellerOrderStatus status;
  String? rawStatus;
  String? cancellationReason;
  int get subtotal => itemsSubtotal ?? unitPrice * quantity;
  int get fee => _recordedFee ?? MarketplacePolicy.commissionFor(subtotal);
  int get net => subtotal - fee - refund;
  DateTime get incomeDate => completedAt ?? placedAt;
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
        category: "Women's Apparel",
        subcategory: 'Shoes & Accessories',
        description: 'A reusable everyday market bag.',
      ),
      SellerProduct(
        id: 'SP2',
        name: 'Rattan fruit basket',
        price: 35000,
        stock: 3,
        category: 'Home and Garden',
        subcategory: 'Furniture & Decor',
      ),
      SellerProduct(
        id: 'SP3',
        name: 'Woven table runner',
        price: 28000,
        stock: 0,
        category: 'Home and Garden',
        subcategory: 'Bedding & Bath',
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
        9000,
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
        3500,
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
          completedAt: status == SellerOrderStatus.completed
              ? now.subtract(Duration(days: entry.$1))
              : null,
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
  final Set<String> pausedPromotions = {};
  final Set<String> readNotifications = {};

  Future<Map<String, dynamic>> load() async {
    final result = Map<String, dynamic>.from(
      await ApiService.get('/seller/workspace'),
    );
    if (_disposed) return {};
    _products.clear();
    for (final p in result['products']) {
      final variants = p['variants'] as List? ?? [];
      _products.add(
        SellerProduct(
          id: p['id'],
          name: p['name'],
          price: p['price'],
          stock: p['stock'],
          category: p['category'],
          subcategory: p['subcategory'] as String? ?? '',
          description: p['description'],
          active: p['active'],
          variety:
              (p['variant_label'] as String?) ??
              (variants.length == 1
                  ? variants.first['label'] as String?
                  : null) ??
              'Default',
          editable: variants.length <= 1,
          media: ProductMedia.fromProduct(p),
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
          refund: (o['refund'] as num?)?.toInt() ?? 0,
          completedAt: _optionalDate(o['completed_at']),
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
          rawStatus: o['raw_status'] as String?,
        ),
      );
    }
    earnings = Map<String, dynamic>.from(result['earnings']);
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
  List<SellerProduct> get lowStockProducts => _products
      .where((p) => p.stock <= MarketplacePolicy.lowStockThreshold)
      .toList(growable: false);
  int get lowStock => lowStockProducts.length;
  int get toPack =>
      _orders.where((o) => o.status == SellerOrderStatus.toPack).length;

  Future<void> saveProduct(SellerProduct product) async {
    final existing = _products.where((p) => p.id == product.id).firstOrNull;
    if (!product.editable || existing?.editable == false) {
      throw StateError(
        'Each product must have one variety. Create separate products for existing varieties before editing this listing.',
      );
    }
    if (product.name.trim().isEmpty ||
        product.price <= 0 ||
        product.stock < 0 ||
        product.category.trim().isEmpty ||
        product.variety.trim().isEmpty ||
        product.variety.trim().length > 100) {
      throw ArgumentError(
        'Enter a name, category, one variety (up to 100 characters), positive price and valid stock.',
      );
    }
    if (connected) {
      final body = {
        'name': product.name,
        'price': product.price,
        'stock': product.stock,
        'category': product.category,
        'subcategory': product.subcategory,
        'variant_label': product.variety.trim(),
        'description': product.description,
        'active': product.active,
        'media': product.media.map((m) => m.toJson()).toList(),
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
    order.rawStatus = 'ready_to_ship';
    order.cancellable = false;
    notifyListeners();
  }

  Future<void> markPacked(SellerOrder order) async {
    if (!_orders.contains(order) ||
        order.status != SellerOrderStatus.toPack ||
        order.rawStatus == 'packed') {
      throw StateError('Only new orders can be marked packed.');
    }
    if (connected) {
      await ApiService.post(
        '/seller/orders/${Uri.encodeComponent(order.id)}/pack',
        body: {},
      );
      await load();
    } else {
      order.rawStatus = 'packed';
      order.cancellable = false;
      notifyListeners();
    }
  }

  Future<void> markShipped(SellerOrder order) async {
    if (!_orders.contains(order) ||
        (order.status != SellerOrderStatus.ready &&
            order.rawStatus != 'packed')) {
      throw StateError('Pack the order before marking it shipped.');
    }
    if (connected) {
      await ApiService.post(
        '/seller/orders/${Uri.encodeComponent(order.id)}/ship',
        body: {},
      );
      await load();
    } else {
      order.rawStatus = 'in_transit';
      order.status = SellerOrderStatus.inTransit;
      notifyListeners();
    }
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
        !order.cancellable ||
        reason.trim().isEmpty) {
      throw StateError('Only unpacked orders can be cancelled, with a reason.');
    }
    order.status = SellerOrderStatus.cancelled;
    order.rawStatus = 'cancelled';
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
        subcategory: p.subcategory,
        variety: p.variety,
        editable: p.editable,
        description: p.description,
        active: p.active,
        media: p.media,
      );
    }
    notifyListeners();
  }
}

DateTime? _optionalDate(dynamic value) {
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(
      value.toInt() * 1000,
      isUtc: true,
    );
  }
  return value is String ? DateTime.tryParse(value) : null;
}
