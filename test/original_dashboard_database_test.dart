import 'package:flutter_application_1/services/api_service.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/design/lumear_theme.dart';
import 'package:flutter_application_1/design/brand_art.dart';
import 'package:flutter_application_1/screen/dashboard_screen.dart';
import 'package:flutter_application_1/services/buyer_data.dart';
import 'package:flutter_application_1/cart_manager.dart';
import 'package:flutter_application_1/product_model.dart';
import 'package:flutter_application_1/services/wishlist_manager.dart';

void main() {
  setUp(() => ApiService.baseUrl = 'https://integration.example.invalid/api');
  tearDown(() {
    ApiService.baseUrl = '';
    ApiService.setToken(null);
  });
  testWidgets(
    'Original dashboard keeps its navigation and saves cart/wishlist through the API',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      bool cartSaved = false, wishlistSaved = false;
      int snapshots = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: lumearTheme(),
              home: const DashboardScreen(connected: true),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<LumearDock>(find.byType(LumearDock))
                .destinations
                .map((d) => d.label),
            ['Home', 'Browse', 'Orders', 'Me'],
          );
          expect(find.text('Classic Everyday Cotton Shirt'), findsNothing);
          expect(BuyerData.instance.error, isNull);
          expect(lumearProducts.single.name, 'Database Basket');
          expect(snapshots, 1);
          final chatRect = tester.getRect(find.byType(FloatingActionButton));
          final dockRect = tester.getRect(find.byType(LumearDock));
          expect(chatRect.bottom, lessThanOrEqualTo(dockRect.top));
          expect(chatRect.center.dx, greaterThan(180));
          expect(
            tester.getCenter(find.byTooltip('Notifications')).dy,
            lessThan(150),
          );
          await tester.tap(find.byTooltip('Notifications'));
          await tester.pumpAndSettle();
          expect(find.widgetWithText(AppBar, 'Notifications'), findsOneWidget);
          expect(find.text('Your order is almost here!'), findsNothing);
          await tester.pageBack();
          await tester.pumpAndSettle();
          await CartManager.instance.addToCart(
            name: 'Database Basket',
            price: '₱125.00',
            icon: Icons.shopping_bag,
            productId: '7',
            selectedVariants: {'Option': 'Default'},
            quantity: 2,
          );
          await tester.pumpAndSettle();
          expect(cartSaved, isTrue);
          expect(CartManager.instance.items.single.serverId, '44');
          expect(CartManager.instance.itemCount, 2);
          await WishlistManager.instance.toggle(lumearProducts.single);
          await tester.pumpAndSettle();
          expect(wishlistSaved, isTrue);
          expect(WishlistManager.instance.contains('7'), isTrue);
          await tester.tap(find.text('Orders').last);
          await tester.pumpAndSettle();
          expect(find.text('LMR-2026-001'), findsNothing);
          await tester.tap(find.byTooltip('Open chat'));
          await tester.pumpAndSettle();
          expect(find.text('Your order is almost here!'), findsNothing);
          await tester.pageBack();
          await tester.pumpAndSettle();
          await tester.tap(find.text('Me').last);
          await tester.pumpAndSettle();
          expect(find.text('Database Buyer'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          BuyerData.instance.reset();
        },
        () => MockClient((request) async {
          if (request.url.path == '/api/chat/threads') {
            return http.Response('{"threads":[]}', 200);
          }
          if (request.method == 'POST' && request.url.path == '/api/cart') {
            final body = jsonDecode(request.body);
            expect(body['product_id'], '7');
            expect(body['variant_id'], '70');
            expect(body['quantity'], 2);
            cartSaved = true;
            return http.Response('{}', 200);
          }
          if (request.method == 'POST' &&
              request.url.path == '/api/wishlist/7') {
            wishlistSaved = true;
            return http.Response('{}', 200);
          }
          expect(request.url.path, '/api/buyer/workspace');
          snapshots++;
          return http.Response(
            jsonEncode({
              'profile': {
                'name': 'Database Buyer',
                'email': 'buyer@example.invalid',
              },
              'products': [
                {
                  'id': '7',
                  'name': 'Database Basket',
                  'category': 'Home',
                  'description': 'Basket',
                  'price': 12500,
                  'stock': 5,
                  'store': 'Database Shop',
                  'seller': '3',
                  'rating': 0,
                  'review_count': 0,
                  'variants': [
                    {
                      'id': '70',
                      'label': 'Default',
                      'price': 12500,
                      'stock': 5,
                    },
                  ],
                },
              ],
              'cart': cartSaved
                  ? [
                      {
                        'id': '44',
                        'product_id': '7',
                        'variant_id': '70',
                        'name': 'Database Basket',
                        'variant': 'Default',
                        'quantity': 2,
                        'price': 12500,
                      },
                    ]
                  : [],
              'orders': [],
              'addresses': [],
              'notifications': [],
              'vouchers': [],
              'wishlist': wishlistSaved
                  ? [
                      {'id': '7'},
                    ]
                  : [],
              'capabilities': {'storage': 'mysql', 'checkout': false},
            }),
            200,
          );
        }),
      );
    },
  );
}
