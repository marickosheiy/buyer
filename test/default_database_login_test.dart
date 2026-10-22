import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/design/lumear_theme.dart';
import 'package:flutter_application_1/login_page.dart';
import 'package:flutter_application_1/services/buyer_data.dart';
import 'package:flutter_application_1/screen/dashboard_screen.dart';

void main() {
  testWidgets('Normal login uses the backend and opens persisted buyer data', (
    tester,
  ) async {
    bool loggedIn = false;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(theme: lumearTheme(), home: const LoginPage()),
        );
        await tester.pumpAndSettle();
        expect(find.text('Try a demo account'), findsNothing);
        await tester.enterText(
          find.byType(TextField).at(0),
          'registered@example.invalid',
        );
        await tester.enterText(find.byType(TextField).at(1), 'TestPassword123');
        await tester.ensureVisible(
          find.widgetWithText(FilledButton, 'Sign in'),
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
        await tester.pumpAndSettle();
        expect(loggedIn, isTrue);
        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(find.text('Home'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        BuyerData.instance.reset();
      },
      () => MockClient((request) async {
        if (request.url.path == '/api/auth/login') {
          expect(
            jsonDecode(request.body)['email'],
            'registered@example.invalid',
          );
          loggedIn = true;
          return http.Response(
            jsonEncode({'token': 'test-session', 'role': 'buyer'}),
            200,
          );
        }
        expect(request.headers['Authorization'], 'Bearer test-session');
        final body = switch (request.url.path) {
          '/api/buyer/workspace' => {
            'profile': {
              'name': 'Database Buyer',
              'email': 'registered@example.invalid',
              'phone': '09171234567',
            },
            'products': [],
            'cart': [],
            'orders': [],
            'addresses': [],
            'wishlist': [],
            'notifications': [],
            'vouchers': [],
            'capabilities': {'storage': 'mysql', 'checkout': false},
          },
          '/api/capabilities' => {'storage': 'mysql', 'checkout': false},
          _ => [],
        };
        return http.Response(jsonEncode(body), 200);
      }),
    );
  });

  testWidgets('An unreachable backend never falls back to a demo login', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(theme: lumearTheme(), home: const LoginPage()),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'lumear@gmail.com');
      await tester.enterText(find.byType(TextField).at(1), 'Lumear123');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Cannot connect to Lumear'),
        findsOneWidget,
      );
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);
    }, () => MockClient((_) async => throw http.ClientException('offline')));
  });
}
