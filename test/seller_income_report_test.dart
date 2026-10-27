import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/seller/seller_commerce.dart';
import 'package:flutter_application_1/seller/seller_income_pdf.dart';
import 'package:flutter_application_1/seller/seller_income_report.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/marketplace_policy.dart';

SellerOrder order(
  String id,
  int cents,
  DateTime date, {
  SellerOrderStatus status = SellerOrderStatus.completed,
  int refund = 0,
}) => SellerOrder(
  id: id,
  buyer: 'Buyer',
  productId: '1',
  productName: 'Product',
  quantity: 1,
  unitPrice: cents,
  address: 'Manila',
  placedAt: date,
  completedAt: status == SellerOrderStatus.completed ? date : null,
  status: status,
  refund: refund,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 10, 27, 4);
  final samples = [
    order('ORD-1001', 100000, DateTime.utc(2026, 10, 5)),
    order('ORD-1002', 200000, DateTime.utc(2026, 10, 12)),
    order('ORD-1003', 50000, DateTime.utc(2026, 10, 20)),
  ];
  SellerIncomeReport report(
    Iterable<SellerOrder> orders,
    EarningsPeriod period,
  ) => SellerIncomeReport(
    orders: orders,
    period: period,
    generatedAt: now,
    demo: true,
  );

  test('10% commission leaves 90%, excludes shipping and unfinished sales', () {
    final result = report([
      ...samples,
      order('pending', 999000, now, status: SellerOrderStatus.toPack),
      order('delivered', 999000, now, status: SellerOrderStatus.delivered),
      order('cancelled', 999000, now, status: SellerOrderStatus.cancelled),
    ], EarningsPeriod.month);
    expect(result.gross, 350000);
    expect(result.commission, 35000);
    expect(result.net, 315000);
    expect(incomeMoney(result.net), '₱3,150.00');
    expect(result.rows.length, 3);
    expect(result.rows.map((r) => r.net), [45000, 180000, 90000]);
    expect(samples.every((o) => o.shipping == 5000), isTrue);
    expect(result.hasLegacyCommission, isFalse);
  });

  test(
    'commission rounds half up per order; refunds are deducted separately',
    () {
      final result = report([
        order('a', 10004, now, refund: 500),
        order('b', 10005, now),
      ], EarningsPeriod.allTime);
      expect(result.commission, 2001);
      expect(result.refunds, 500);
      expect(result.net, 17508);
      expect(MarketplacePolicy.commissionFor(0), 0);
    },
  );

  test(
    'week starts Monday midnight in Manila; month uses Manila boundaries',
    () {
      final rows = [
        order('beforeMonth', 10000, DateTime.utc(2026, 9, 30, 15, 59)),
        order('monthStart', 10000, DateTime.utc(2026, 9, 30, 16)),
        order('beforeWeek', 10000, DateTime.utc(2026, 10, 25, 15, 59)),
        order('weekStart', 10000, DateTime.utc(2026, 10, 25, 16)),
        order('future', 10000, now.add(const Duration(hours: 1))),
      ];
      expect(report(rows, EarningsPeriod.week).rows.map((r) => r.id), [
        'weekStart',
      ]);
      expect(report(rows, EarningsPeriod.month).rows.length, 3);
      expect(report(rows, EarningsPeriod.allTime).rows.length, 4);
      expect(incomeDateLabel(rows[1].incomeDate), 'Oct 1, 2026');
    },
  );

  test(
    'year to date includes January onward and excludes the previous year',
    () {
      final result = report([
        order('previousYear', 10000, DateTime.utc(2025, 12, 31, 15, 59)),
        order('january', 10000, DateTime.utc(2025, 12, 31, 16)),
        ...samples,
      ], EarningsPeriod.yearToDate);
      expect(result.rows.length, 4);
      expect(result.gross, 360000);
      expect(result.net, 324000);
      expect(result.rangeLabel, 'Jan 1, 2026 – Oct 27, 2026');
    },
  );

  test(
    'custom history range includes complete start and end days in Manila',
    () {
      final result = SellerIncomeReport(
        orders: [
          order('before', 10000, DateTime.utc(2024, 12, 31, 15, 59, 59)),
          order('start', 10000, DateTime.utc(2024, 12, 31, 16)),
          order('end', 10000, DateTime.utc(2025, 5, 31, 15, 59, 59, 999)),
          order('after', 10000, DateTime.utc(2025, 5, 31, 16)),
        ],
        period: EarningsPeriod.custom,
        generatedAt: now,
        customStart: DateTime(2025, 1, 1),
        customEnd: DateTime(2025, 5, 31),
        demo: false,
      );
      expect(result.rows.map((r) => r.id), ['end', 'start']);
      expect(result.net, 18000);
      expect(result.rangeLabel, 'Jan 1, 2025 – May 31, 2025');
      expect(
        result.filename,
        'lumear-income-custom-2025-01-01-to-2025-05-31.pdf',
      );
      expect(
        () => SellerIncomeReport(
          orders: [],
          period: EarningsPeriod.custom,
          generatedAt: now,
          demo: false,
        ),
        throwsArgumentError,
      );
      expect(
        () => SellerIncomeReport(
          orders: [],
          period: EarningsPeriod.custom,
          generatedAt: now,
          demo: false,
          customStart: DateTime(2025, 6, 1),
          customEnd: DateTime(2025, 5, 31),
        ),
        throwsArgumentError,
      );
    },
  );

  test('a single selected day includes late orders and still excludes unfinished sales', () {
    final result = SellerIncomeReport(
      orders: [
        order('late', 10000, DateTime.utc(2025, 1, 1, 15, 59, 59)),
        order('next', 10000, DateTime.utc(2025, 1, 1, 16)),
        order(
          'pending',
          10000,
          DateTime.utc(2025, 1, 1),
          status: SellerOrderStatus.toPack,
        ),
      ],
      period: EarningsPeriod.custom,
      generatedAt: now,
      demo: true,
      customStart: DateTime(2025, 1, 1),
      customEnd: DateTime(2025, 1, 1),
    );
    expect(result.rows.map((r) => r.id), ['late']);
  });

  test('report snapshots do not change after order status changes', () {
    final mutable = order('a', 10000, now);
    final result = report([mutable], EarningsPeriod.month);
    mutable.status = SellerOrderStatus.cancelled;
    expect(result.net, 9000);
    expect(result.rows.length, 1);
    expect(report([mutable], EarningsPeriod.month).net, 0);
  });

  test('low stock includes exactly 5, zero, and inactive products', () async {
    final commerce = SellerCommerce();
    addTearDown(commerce.dispose);
    Future<void> save(int stock) => commerce.saveProduct(
      SellerProduct(
        id: 'boundary',
        name: 'Test',
        price: 10000,
        stock: stock,
        category: 'Home',
      ),
    );
    await save(6);
    expect(commerce.lowStockProducts.any((p) => p.id == 'boundary'), isFalse);
    await save(5);
    expect(commerce.lowStockProducts.any((p) => p.id == 'boundary'), isTrue);
    await save(0);
    expect(commerce.lowStockProducts.any((p) => p.id == 'boundary'), isTrue);
    expect(
      commerce.lowStockProducts.any((p) => !p.active && p.stock == 0),
      isTrue,
    );
    await save(7);
    expect(commerce.lowStockProducts.any((p) => p.id == 'boundary'), isFalse);
  });

  test('shipping is fixed per shop, including large orders', () {
    MarketplacePolicy.validateShippingQuote({
      'stores': [
        {'shipping': 5000},
        {'shipping': 5000},
      ],
    });
    for (final amount in [0, 4999, 5001]) {
      expect(
        () => MarketplacePolicy.validateShippingQuote({
          'stores': [
            {'shipping': amount},
          ],
        }),
        throwsA(isA<ApiException>()),
      );
    }
    expect(MarketplacePolicy.shippingPesos, 50);
  });

  test('PDF generation supports normal, empty and multipage reports', () async {
    final reports = {
      'sample': SellerIncomeReport(
        orders: samples,
        period: EarningsPeriod.custom,
        generatedAt: now,
        demo: true,
        customStart: DateTime(2026, 1, 1),
        customEnd: DateTime(2026, 10, 27),
      ),
      'empty': report([], EarningsPeriod.week),
      'multipage': report(
        List.generate(100, (i) => order('ORDER-${1000 + i}', 100000 + i, now)),
        EarningsPeriod.allTime,
      ),
    };
    for (final entry in reports.entries) {
      final bytes = await buildSellerIncomePdf(entry.value);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(5000));
      if (const bool.fromEnvironment('WRITE_REPORT_PREVIEWS')) {
        final file = File('tmp/pdfs/income-${entry.key}.pdf');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes);
      }
    }
  });
}
