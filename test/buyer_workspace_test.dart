import 'package:flutter_application_1/services/api_service.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/design/lumear_theme.dart';
import 'package:flutter_application_1/login_page.dart';
import 'package:flutter_application_1/screen/buyer_workspace.dart';
import 'package:flutter_application_1/screen/dashboard_screen.dart';
import 'package:flutter_application_1/seller/seller_dashboard_screen.dart';

void main() {
  setUp(() => ApiService.baseUrl = 'https://integration.example.invalid/api');
  tearDown(() {
    ApiService.baseUrl = '';
    ApiService.setToken(null);
  });
  for (final seller in [false, true]) {
    testWidgets(
      '${seller ? 'Seller' : 'Buyer'} demo opens without an API request',
      (tester) async {
        ApiService.baseUrl = '';
        int apiRequests = 0;
        await http.runWithClient(
          () async {
            await tester.pumpWidget(
              MaterialApp(theme: lumearTheme(), home: const LoginPage()),
            );
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<TextButton>(
                    find.widgetWithText(TextButton, 'Create an account'),
                  )
                  .onPressed,
              isNotNull,
            );
            expect(find.textContaining('connected backend'), findsNothing);
            await tester.tap(
              find.text(seller ? 'Seller · local preview' : 'Buyer'),
            );
            await tester.pump();
            final signIn = find.widgetWithText(FilledButton, 'Sign in');
            await tester.ensureVisible(signIn);
            await tester.tap(signIn);
            await tester.pumpAndSettle();
            expect(
              find.byType(seller ? SellerDashboardScreen : DashboardScreen),
              findsOneWidget,
            );
            expect(apiRequests, 0);
            expect(find.textContaining('server took too long'), findsNothing);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
          },
          () => MockClient((request) async {
            apiRequests++;
            throw http.ClientException('The demo must not use the backend.');
          }),
        );
      },
    );
  }

  testWidgets(
    'Invalid demo credentials show an immediate local validation error',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: lumearTheme(),
          home: const LoginPage(useBackend: false),
        ),
      );
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'lumear@gmail.com');
      await tester.enterText(fields.at(1), 'wrong-password');
      final signIn = find.widgetWithText(FilledButton, 'Sign in');
      await tester.ensureVisible(signIn);
      await tester.tap(signIn);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Invalid demo email or password. Use a demo account or one you created this session.',
        ),
        findsOneWidget,
      );
      expect(find.byType(LoginPage), findsOneWidget);
    },
  );

  testWidgets(
    'Profile sheets can be saved and reopened without disposed controllers',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: navigator,
              theme: lumearTheme(),
              home: const BuyerWorkspace(),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('You'));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(OutlinedButton, 'Edit profile'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField).last, 'Updated Buyer');
          await tester.tap(find.widgetWithText(FilledButton, 'Save'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.widgetWithText(OutlinedButton, 'Edit profile'));
          await tester.pumpAndSettle();
          navigator.currentState!.pop();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
        () => MockClient(
          (request) async => http.Response(
            jsonEncode(
              request.url.path == '/api/me'
                  ? {
                      'name': 'Buyer',
                      'email': 'buyer@example.com',
                      'phone': '09171234567',
                    }
                  : [],
            ),
            200,
          ),
        ),
      );
    },
  );
  testWidgets('Explicit preview fills credentials and has no social sign-in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: lumearTheme(),
        home: const LoginPage(useBackend: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try a demo account'), findsOneWidget);
    final demo = find.text('Buyer', skipOffstage: false);
    await tester.ensureVisible(demo);
    await tester.tap(demo);
    await tester.pumpAndSettle();
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields[0].controller!.text, 'lumear@gmail.com');
    expect(fields[1].controller!.text, 'Lumear123');
    expect(find.text('Continue with Facebook'), findsNothing);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Buyer workspace loads persisted data and shows all order tabs on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final responses = <String, dynamic>{
        '/api/me': {
          'id': 'buyer1',
          'name': 'Juan Miguel Dela Cruz',
          'email': 'buyer@example.com',
          'phone': '09171234567',
        },
        '/api/products': [
          {
            'id': 'P-02',
            'name': 'Rattan Fruit Basket',
            'store': 'Maria Clara Handicrafts',
            'seller': 's1',
            'category': 'Home & Living',
            'price': 45000,
            'stock': 20,
            'review_count': 0,
            'rating': 0,
          },
        ],
        '/api/cart': [],
        '/api/orders': [],
        '/api/addresses': [],
        '/api/vouchers': [],
        '/api/wishlist': [],
        '/api/notifications': [],
        '/api/follows': [],
      };
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(theme: lumearTheme(), home: const BuyerWorkspace()),
          );
          await tester.pumpAndSettle();
          expect(find.text('Rattan Fruit Basket'), findsOneWidget);
          expect(find.text('₱450.00'), findsOneWidget);
          await tester.tap(find.text('Cart'));
          await tester.pumpAndSettle();
          expect(find.text('Your bag is empty'), findsOneWidget);
          await tester.tap(find.text('Orders'));
          await tester.pumpAndSettle();
          expect(find.text('No orders here yet'), findsOneWidget);
          await tester.tap(find.text('You'));
          await tester.pumpAndSettle();
          expect(find.text('Juan Miguel Dela Cruz'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        () => MockClient(
          (request) async => http.Response(
            jsonEncode(responses[request.url.path] ?? []),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
    },
  );
}
