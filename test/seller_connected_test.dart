import 'package:flutter_application_1/services/api_service.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/design/lumear_theme.dart';
import 'package:flutter_application_1/seller/seller_dashboard_screen.dart';

void main() {
  setUp(() => ApiService.baseUrl = 'https://integration.example.invalid/api');
  tearDown(() {
    ApiService.baseUrl = '';
    ApiService.setToken(null);
  });
  testWidgets(
    'Connected seller uses database sales and wallet balances without sample records',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: lumearTheme(),
              home: const SellerDashboardScreen(connected: true),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Database Shop'), findsOneWidget);
          expect(find.textContaining('Sample orders'), findsNothing);
          await tester.tap(find.text('Products').last);
          await tester.pumpAndSettle();
          expect(find.text('Database Basket'), findsOneWidget);
          expect(find.text('Handwoven market tote'), findsNothing);
          // Multiple-variant prices/stock must not be flattened into one update.
          expect(
            tester
                .widget<IconButton>(
                  find.byWidgetPredicate(
                    (w) =>
                        w is IconButton && w.tooltip == 'Edit Database Basket',
                  ),
                )
                .onPressed,
            isNull,
          );
          await tester.tap(find.text('Earnings').last);
          await tester.pumpAndSettle();
          expect(find.text('Income & Earnings'), findsOneWidget);
          final balance = find.text('₱12.34');
          await tester.scrollUntilVisible(
            balance,
            150,
            scrollable: find.byType(Scrollable).last,
          );
          expect(balance, findsOneWidget);
          await tester.scrollUntilVisible(
            find.text('₱100.00'),
            150,
            scrollable: find.byType(Scrollable).last,
          );
          expect(find.text('₱100.00'), findsOneWidget);
          expect(find.text('₱1187.50'), findsNothing);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          if (request.url.path == '/api/seller/analytics') {
            return http.Response(
              jsonEncode({
                'current': <String, num>{},
                'previous': <String, num>{},
                'daily': [],
                'products': [],
                'customers': {
                  'new': 0,
                  'returning': 0,
                  'repeat': 0,
                  'locations': [],
                },
                'promotions': [],
                'operations': <String, num>{},
                'notifications': [],
                'returns': [],
              }),
              200,
            );
          }
          expect(request.url.path, '/api/seller/workspace');
          return http.Response(
            jsonEncode({
              'shop': {
                'owner': 'Seller',
                'name': 'Database Shop',
                'description': 'Real shop',
                'email': 'seller@example.invalid',
                'phone': '09171234567',
              },
              'products': [
                {
                  'id': '10',
                  'name': 'Database Basket',
                  'price': 5000,
                  'stock': 6,
                  'category': 'Home',
                  'description': 'Basket',
                  'active': true,
                  'variants': [{}, {}],
                },
              ],
              'orders': [],
              'categories': [
                {'id': '1', 'name': 'Home'},
              ],
              'earnings': {
                'gross_sales': 10000,
                'fees': 800,
                'net_sales': 9200,
                'wallet_available': 1234,
                'wallet_pending': 4321,
                'pending_sales': 0,
                'paid_out': 0,
                'payouts': [],
                'journals': [],
              },
            }),
            200,
          );
        }),
      );
    },
  );
}
