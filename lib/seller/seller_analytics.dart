import 'seller_commerce.dart';
import '../services/api_service.dart';

DateTime sellerToday([DateTime? now]) {
  final ph = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 8));
  return DateTime.utc(ph.year, ph.month, ph.day);
}

String analyticsDate(DateTime date) => date.toIso8601String().substring(0, 10);

class SellerAnalyticsRange {
  SellerAnalyticsRange(this.start, this.end);
  final DateTime start, end; // Philippine calendar dates; end is exclusive.
  factory SellerAnalyticsRange.period(String period, [DateTime? now]) {
    final today = sellerToday(now);
    return SellerAnalyticsRange(
      period == 'Today'
          ? today
          : period == 'This week'
          ? today.subtract(Duration(days: today.weekday - 1))
          : DateTime.utc(today.year, today.month),
      today.add(const Duration(days: 1)),
    );
  }
  SellerAnalyticsRange get previous =>
      SellerAnalyticsRange(start.subtract(end.difference(start)), start);
  bool contains(DateTime value) {
    final ph = value.toUtc().add(const Duration(hours: 8));
    final day = DateTime.utc(ph.year, ph.month, ph.day);
    return !day.isBefore(start) && day.isBefore(end);
  }

  String get label =>
      '${analyticsDate(start)} to ${analyticsDate(end.subtract(const Duration(days: 1)))}';
}

class SellerAnalyticsSnapshot {
  SellerAnalyticsSnapshot(Map<String, dynamic> json)
    : current = Map<String, num>.from(json['current']),
      previous = Map<String, num>.from(json['previous']),
      daily = _rows(json['daily']),
      products = _rows(json['products']),
      customers = Map<String, dynamic>.from(json['customers']),
      promotions = _rows(json['promotions']),
      operations = Map<String, num>.from(json['operations']),
      returns = _rows(json['returns'] ?? []),
      notifications = _rows(json['notifications']);
  final Map<String, num> current, previous, operations;
  final Map<String, dynamic> customers;
  final List<Map<String, dynamic>> daily,
      products,
      promotions,
      notifications,
      returns;
  static List<Map<String, dynamic>> _rows(dynamic rows) =>
      (rows as List).map((r) => Map<String, dynamic>.from(r)).toList();
}

class SellerAnalytics {
  SellerAnalytics(this.commerce);
  final SellerCommerce commerce;
  Set<String> get paused => commerce.pausedPromotions;
  Set<String> get read => commerce.readNotifications;
  Future<SellerAnalyticsSnapshot> load(SellerAnalyticsRange range) async {
    if (commerce.connected) {
      return SellerAnalyticsSnapshot(
        Map<String, dynamic>.from(
          await ApiService.get(
            '/seller/analytics?start=${analyticsDate(range.start)}&end=${analyticsDate(range.end)}',
          ),
        ),
      );
    }
    return demo(range);
  }

  Future<void> pause(String id) async {
    if (commerce.connected) {
      await ApiService.patch(
        '/seller/promotions/${Uri.encodeComponent(id)}',
        body: {'active': false},
      );
    } else {
      paused.add(id);
    }
  }

  Future<void> markRead(String id) async {
    if (commerce.connected) {
      await ApiService.patch(
        '/seller/notifications/${Uri.encodeComponent(id)}',
        body: {'read': true},
      );
    } else {
      read.add(id);
    }
  }

  SellerAnalyticsSnapshot demo(SellerAnalyticsRange range) {
    List<SellerOrder> orders(SellerAnalyticsRange r) =>
        commerce.orders.where((o) => r.contains(o.placedAt)).toList();
    bool sold(SellerOrder o) => o.status == SellerOrderStatus.completed;
    int views(SellerAnalyticsRange r) => r.end.difference(r.start).inDays * 120;
    Map<String, num> metrics(SellerAnalyticsRange r) {
      final all = orders(r), sales = all.where(sold).toList();
      final revenue = sales.fold(0, (s, o) => s + o.subtotal);
      return {
        'sales': revenue,
        'orders': all.length,
        'earnings': sales.fold(0, (s, o) => s + o.net),
        'conversion': views(r) == 0 ? 0 : sales.length / views(r) * 100,
        'units': sales.fold(0, (s, o) => s + o.quantity),
        'aov': sales.isEmpty ? 0 : revenue / sales.length,
        'cancelled': all
            .where((o) => o.status == SellerOrderStatus.cancelled)
            .length,
        'returned': sales.where((o) => o.refund > 0).length,
      };
    }

    final sales = orders(range).where(sold).toList();
    List<SellerOrder> attributed(String id) => sales
        .where((o) => o.productId == (id == 'demo-voucher' ? 'SP1' : 'SP2'))
        .toList();
    final counts = <String, int>{};
    for (final o in sales) {
      counts.update(o.buyer, (n) => n + 1, ifAbsent: () => 1);
    }
    final returning = counts.keys
        .where(
          (buyer) => commerce.orders.any(
            (o) =>
                o.buyer == buyer &&
                sold(o) &&
                o.placedAt
                    .toUtc()
                    .add(const Duration(hours: 8))
                    .isBefore(range.start),
          ),
        )
        .length;
    final productRows =
        commerce.products.map((p) {
            final purchases = sales.where((o) => o.productId == p.id).toList();
            final v = views(range);
            return <String, dynamic>{
              'id': p.id,
              'name': p.name,
              'views': v,
              'cart_rate': p.stock == 0 ? 0.0 : 8.0,
              'purchases': purchases.length,
              'units': purchases.fold(0, (s, o) => s + o.quantity),
              'revenue': purchases.fold(0, (s, o) => s + o.subtotal),
              'low_performing': purchases.isEmpty && v >= 100,
              'stock': p.stock,
            };
          }).toList()
          ..sort((a, b) => (b['units'] as int).compareTo(a['units'] as int));
    final notices = <Map<String, dynamic>>[
      for (final p in commerce.lowStockProducts)
        {
          'id': 'stock-${p.id}',
          'type': 'low_stock',
          'title': '${p.name}: ${p.stock} left',
        },
      for (final o in commerce.orders.where(
        (o) => o.status == SellerOrderStatus.toPack,
      ))
        {
          'id': 'order-${o.id}',
          'type': 'new_order',
          'title': '${o.id} needs packing',
        },
      {
        'id': 'message',
        'type': 'seller_message',
        'title': 'Buyer asks about delivery availability',
      },
      if (!paused.contains('demo-voucher'))
        {
          'id': 'promotion',
          'type': 'promotion_ending',
          'title': 'Weekend voucher ends in 12 hours',
        },
      {
        'id': 'payout',
        'type': 'payout_update',
        'title': 'Sample payout is being processed',
      },
      {
        'id': 'return',
        'type': 'return_dispute',
        'title': 'Sample return request needs review',
      },
    ];
    return SellerAnalyticsSnapshot({
      'current': metrics(range),
      'previous': metrics(range.previous),
      'daily': [
        for (
          var d = range.start;
          d.isBefore(range.end);
          d = d.add(const Duration(days: 1))
        )
          {
            'date': analyticsDate(d),
            'revenue': sales
                .where(
                  (o) => SellerAnalyticsRange(
                    d,
                    d.add(const Duration(days: 1)),
                  ).contains(o.placedAt),
                )
                .fold(0, (s, o) => s + o.subtotal),
          },
      ],
      'products': productRows,
      'customers': {
        'new': counts.length - returning,
        'returning': returning,
        'repeat': counts.values.where((n) => n > 1).length,
        'locations': [
          if (counts.isNotEmpty)
            {'name': 'Quezon City', 'buyers': counts.length},
        ],
      },
      'promotions': [
        for (final id in ['demo-voucher', 'demo-flash'])
          {
            'id': id,
            'name': id == 'demo-voucher'
                ? 'Weekend voucher'
                : 'Basket flash sale',
            'kind': id == 'demo-voucher' ? 'voucher' : 'flash_sale',
            'active': !paused.contains(id),
            'views': views(range),
            'claims': id == 'demo-voucher'
                ? range.end.difference(range.start).inDays * 2
                : 0,
            'redemptions': attributed(id).length,
            'revenue': attributed(id).fold(0, (s, o) => s + o.subtotal),
            'conversion': views(range) == 0
                ? 0
                : attributed(id).length / views(range) * 100,
            'warning': id == 'demo-voucher'
                ? 'Ends in 12 hours'
                : 'Only 3 units available',
          },
      ],
      'operations': {
        'new': commerce.orders
            .where(
              (o) =>
                  o.status == SellerOrderStatus.toPack &&
                  o.rawStatus != 'packed',
            )
            .length,
        'packing': commerce.orders
            .where(
              (o) =>
                  o.rawStatus == 'packed' ||
                  o.status == SellerOrderStatus.ready,
            )
            .length,
        'shipped': commerce.orders
            .where((o) => o.status == SellerOrderStatus.inTransit)
            .length,
        'delivered': commerce.orders
            .where(
              (o) => [
                SellerOrderStatus.delivered,
                SellerOrderStatus.completed,
              ].contains(o.status),
            )
            .length,
        'delayed': commerce.orders
            .where(
              (o) =>
                  [
                    SellerOrderStatus.toPack,
                    SellerOrderStatus.ready,
                    SellerOrderStatus.inTransit,
                  ].contains(o.status) &&
                  DateTime.now().difference(o.placedAt).inDays >= 3,
            )
            .length,
        'returns': 1,
      },
      'notifications': [
        for (final n in notices) {...n, 'read': read.contains(n['id'])},
      ],
      'returns': [
        {
          'id': 'demo-return',
          'order_id': 'SO-1004',
          'reason': 'Sample: damaged item',
          'status': 'requested',
          'amount': 45000,
        },
      ],
    });
  }
}

String analyticsValue(String key, num n) =>
    ['sales', 'earnings', 'aov', 'revenue'].contains(key)
    ? sellerMoney(n.round())
    : key == 'conversion'
    ? '${n.toStringAsFixed(2)}%'
    : '$n';
String analyticsChange(String key, SellerAnalyticsSnapshot snapshot) {
  final a = snapshot.current[key] ?? 0, b = snapshot.previous[key] ?? 0;
  if (key == 'conversion') {
    return '${(a - b).toStringAsFixed(2)} pp vs previous';
  }
  if (b == 0) {
    return a == 0 ? 'No change vs previous' : 'No previous baseline';
  }
  final delta = (a - b) / b * 100;
  return '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}% vs previous';
}
