import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/seller/seller_commerce.dart';

void main() {
  test(
    'Earnings exclude pending orders and shipping and reconcile settlement',
    () async {
      final data = SellerCommerce();
      addTearDown(data.dispose);
      expect(data.grossSales, 125000);
      expect(data.fees, 6250);
      expect(data.netEarnings, 118750);
      expect(data.awaitingSettlement + data.paidOut, data.netEarnings);
      expect(data.pendingSales, 170000);
      await data.prepare(data.orders.first);
      expect(data.netEarnings, 118750);
      expect(data.pendingSales, 170000);
    },
  );

  test(
    'Cancellation restores reserved stock exactly once and requires a reason',
    () async {
      final data = SellerCommerce();
      addTearDown(data.dispose);
      final order = data.orders.first;
      final stock = data.products.first.stock;
      await expectLater(data.cancel(order, ''), throwsStateError);
      await data.cancel(order, 'Item damaged');
      expect(data.products.first.stock, stock + order.quantity);
      expect(data.pendingSales, 80000);
      await expectLater(data.cancel(order, 'Again'), throwsStateError);
      expect(data.products.first.stock, stock + order.quantity);
      await expectLater(data.prepare(order), throwsStateError);
    },
  );

  test(
    'Preparing an order does not allow another seller status transition',
    () async {
      final data = SellerCommerce();
      addTearDown(data.dispose);
      final order = data.orders.first;
      await data.prepare(order);
      expect(order.status, SellerOrderStatus.ready);
      await expectLater(data.cancel(order, 'Unavailable'), throwsStateError);
      await expectLater(data.prepare(order), throwsStateError);
    },
  );
}
