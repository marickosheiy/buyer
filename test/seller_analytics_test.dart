import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/seller/seller_analytics.dart';
import 'package:flutter_application_1/seller/seller_analytics_panel.dart';
import 'package:flutter_application_1/seller/seller_analytics_pdf.dart';
import 'package:flutter_application_1/seller/seller_commerce.dart';
import 'package:flutter_application_1/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => ApiService.baseUrl = '');

  test('Philippine dates include midnight and exclude the next midnight', () {
    final range = SellerAnalyticsRange.period(
      'Today',
      DateTime.parse('2026-10-31T16:30:00Z'),
    );
    expect(range.label, '2026-11-01 to 2026-11-01');
    expect(range.contains(DateTime.parse('2026-10-31T15:59:59Z')), isFalse);
    expect(range.contains(DateTime.parse('2026-10-31T16:00:00Z')), isTrue);
    expect(range.contains(DateTime.parse('2026-11-01T15:59:59Z')), isTrue);
    expect(range.contains(DateTime.parse('2026-11-01T16:00:00Z')), isFalse);
    expect(range.previous.label, '2026-10-31 to 2026-10-31');
    final week = SellerAnalyticsRange.period(
      'This week',
      DateTime.parse('2026-10-31T00:00:00Z'),
    );
    expect(week.start.weekday, DateTime.monday);
    expect(week.previous.end, week.start);
    expect(
      week.previous.end.difference(week.previous.start),
      week.end.difference(week.start),
    );
  });

  test(
    'Demo totals reconcile and actions survive analytics service recreation',
    () async {
      final commerce = SellerCommerce();
      addTearDown(commerce.dispose);
      final range = SellerAnalyticsRange(
        sellerToday().subtract(const Duration(days: 30)),
        sellerToday().add(const Duration(days: 1)),
      );
      final service = SellerAnalytics(commerce);
      final result = await service.load(range);
      expect(result.current['sales'], commerce.grossSales);
      expect(result.current['earnings'], commerce.netEarnings);
      expect(result.current['units'], 3);
      expect(result.current['aov'], 62500);
      expect(
        result.daily.fold<num>(0, (s, r) => s + (r['revenue'] as num)),
        result.current['sales'],
      );
      expect(
        result.products.fold<num>(0, (s, p) => s + (p['revenue'] as num)),
        result.current['sales'],
      );
      expect(
        result.promotions.fold<num>(0, (s, p) => s + (p['revenue'] as num)),
        result.current['sales'],
      );
      await service.pause('demo-voucher');
      await service.markRead('payout');
      final newService = SellerAnalytics(commerce);
      final updated = await newService.load(range);
      expect(updated.promotions.first['active'], isFalse);
      expect(
        updated.notifications.firstWhere((n) => n['id'] == 'payout')['read'],
        isTrue,
      );
      final order = commerce.orders.first;
      await commerce.markPacked(order);
      expect(order.rawStatus, 'packed');
      expect(order.cancellable, isFalse);
      expect(commerce.cancel(order, 'Already packed'), throwsStateError);
      expect(commerce.markPacked(order), throwsStateError);
      await commerce.markShipped(order);
      expect(order.status, SellerOrderStatus.inTransit);
      expect(commerce.markShipped(order), throwsStateError);
    },
  );

  test(
    'Connected analytics uses scoped APIs and never falls back to demo',
    () async {
      ApiService.baseUrl = 'https://example.invalid/api';
      final commerce = SellerCommerce(connected: true);
      addTearDown(commerce.dispose);
      final service = SellerAnalytics(commerce);
      final requests = <http.Request>[];
      await http.runWithClient(
        () async {
          final result = await service.load(
            SellerAnalyticsRange(
              DateTime.utc(2026, 10, 1),
              DateTime.utc(2026, 11, 1),
            ),
          );
          expect(result.current['sales'], 12345);
          expect(result.products, isEmpty);
          await service.pause('voucher:9');
          await service.markRead('42');
          expect(requests.first.url.queryParameters, {
            'start': '2026-10-01',
            'end': '2026-11-01',
          });
          expect(requests[1].method, 'PATCH');
          expect(jsonDecode(requests[1].body), {'active': false});
          expect(
            Uri.decodeComponent(requests[1].url.path),
            '/api/seller/promotions/voucher:9',
          );
          expect(requests[2].url.path, '/api/seller/notifications/42');
          expect(jsonDecode(requests[2].body), {'read': true});
        },
        () => MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode(
              request.method == 'PATCH'
                  ? {}
                  : {
                      'current': {'sales': 12345},
                      'previous': {'sales': 10000},
                      'daily': [],
                      'products': [],
                      'customers': {
                        'new': 0,
                        'returning': 0,
                        'repeat': 0,
                        'locations': [],
                      },
                      'promotions': [],
                      'operations': {},
                      'notifications': [],
                      'returns': [],
                    },
            ),
            200,
          );
        }),
      );
      await http.runWithClient(
        () async {
          expect(
            service.load(SellerAnalyticsRange.period('Today')),
            throwsA(isA<ApiException>()),
          );
        },
        () => MockClient(
          (_) async =>
              http.Response('{"message":"Analytics unavailable"}', 503),
        ),
      );
    },
  );

  test(
    'Seller PDF generates a multipage report from the selected snapshot',
    () async {
      final commerce = SellerCommerce();
      addTearDown(commerce.dispose);
      final range = SellerAnalyticsRange(
        sellerToday().subtract(const Duration(days: 90)),
        sellerToday().add(const Duration(days: 1)),
      );
      final snapshot = await SellerAnalytics(commerce).load(range);
      final bytes = await buildSellerAnalyticsPdf(
        snapshot: snapshot,
        selectedRange: range,
        shopName: 'Test shop',
        demo: true,
      );
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(bytes.length, greaterThan(10000));
    },
  );

  testWidgets('Seller insights and quick actions fit a 320px phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final commerce = SellerCommerce();
    addTearDown(commerce.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SellerAnalyticsPanel(
              commerce: commerce,
              shopName: 'Demo shop',
              openSection: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        '${SellerAnalyticsRange.period('Today').label} · Philippine time',
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Pause promotion').first);
    await tester.tap(find.text('Pause promotion').first);
    await tester.pumpAndSettle();
    expect(find.text('Weekend voucher · Paused'), findsOneWidget);
    await tester.ensureVisible(find.text('Mark packed').first);
    await tester.tap(find.text('Mark packed').first);
    await tester.pumpAndSettle();
    expect(commerce.orders.first.rawStatus, 'packed');
    await tester.ensureVisible(find.text('Export / share PDF'));
    await tester.pumpAndSettle();
    expect(find.text('Customer insights'), findsOneWidget);
    expect(find.text('Seller reports'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
