import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/design/lumear_theme.dart';
import 'package:flutter_application_1/login_page.dart';
import 'package:flutter_application_1/screen/dashboard_screen.dart';
import 'package:flutter_application_1/seller/seller_dashboard_screen.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/buyer_data.dart';

void main() {
  setUp(() => ApiService.baseUrl = 'https://integration.example.invalid/api');
  tearDown(() {
    ApiService.baseUrl = '';
    ApiService.setToken(null);
    BuyerData.instance.reset();
  });

  Future<void> tapGoogle(WidgetTester tester) async {
    final button = find.widgetWithText(OutlinedButton, 'Continue with Google');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Demo Google button explains missing integration without opening Google',
    (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: lumearTheme(),
          home: LoginPage(
            useBackend: false,
            googleIdTokenProvider: () async {
              called = true;
              return 'unused';
            },
          ),
        ),
      );
      await tapGoogle(tester);
      expect(called, isFalse);
      expect(
        find.textContaining('Google sign-in will be available'),
        findsOneWidget,
      );
      expect(find.byType(LoginPage), findsOneWidget);
    },
  );

  testWidgets(
    'Canceling Google does not call the backend or open a workspace',
    (tester) async {
      var requests = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: lumearTheme(),
              home: LoginPage(
                useBackend: true,
                googleIdTokenProvider: () async => null,
              ),
            ),
          );
          await tapGoogle(tester);
          expect(requests, 0);
          expect(find.byType(LoginPage), findsOneWidget);
          expect(
            tester
                .widget<OutlinedButton>(
                  find.widgetWithText(OutlinedButton, 'Continue with Google'),
                )
                .onPressed,
            isNotNull,
          );
        },
        () => MockClient((_) async {
          requests++;
          return http.Response('{}', 500);
        }),
      );
    },
  );

  for (final role in ['buyer', 'seller']) {
    testWidgets(
      'Google token exchange opens the server assigned $role workspace',
      (tester) async {
        var exchanges = 0;
        await http.runWithClient(
          () async {
            await tester.pumpWidget(
              MaterialApp(
                theme: lumearTheme(),
                home: LoginPage(
                  useBackend: true,
                  googleIdTokenProvider: () async => 'google-id-token',
                ),
              ),
            );
            await tapGoogle(tester);
            expect(exchanges, 1);
            expect(
              find.byType(
                role == 'seller' ? SellerDashboardScreen : DashboardScreen,
              ),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
          () => MockClient((request) async {
            if (request.url.path == '/api/auth/google') {
              exchanges++;
              expect(jsonDecode(request.body), {'id_token': 'google-id-token'});
              expect(request.headers['Authorization'], isNull);
              return http.Response(
                jsonEncode({'token': 'lumear-session', 'role': role}),
                200,
              );
            }
            expect(request.headers['Authorization'], 'Bearer lumear-session');
            final response = role == 'buyer'
                ? {
                    'profile': {
                      'name': 'Google Buyer',
                      'email': 'buyer@example.invalid',
                      'phone': '',
                    },
                    'products': [],
                    'cart': [],
                    'orders': [],
                    'addresses': [],
                    'wishlist': [],
                    'notifications': [],
                    'vouchers': [],
                    'capabilities': {},
                  }
                : {
                    'shop': {
                      'owner': 'Seller',
                      'name': 'Google Shop',
                      'email': '',
                      'phone': '',
                      'description': '',
                    },
                    'products': [],
                    'orders': [],
                    'categories': [],
                    'earnings': {},
                  };
            return http.Response(jsonEncode(response), 200);
          }),
        );
      },
    );
  }

  for (final invalidSession in [false, true]) {
    testWidgets(
      'Google ${invalidSession ? 'invalid session' : 'rejection'} never falls back to demo',
      (tester) async {
        await http.runWithClient(
          () async {
            await tester.pumpWidget(
              MaterialApp(
                theme: lumearTheme(),
                home: LoginPage(
                  useBackend: true,
                  googleIdTokenProvider: () async => 'google-id-token',
                ),
              ),
            );
            await tapGoogle(tester);
            expect(find.byType(LoginPage), findsOneWidget);
            expect(find.byType(DashboardScreen), findsNothing);
            expect(find.byType(SellerDashboardScreen), findsNothing);
            expect(
              find.textContaining(
                invalidSession
                    ? 'could not create a Lumear session'
                    : 'Google account not linked',
              ),
              findsOneWidget,
            );
          },
          () => MockClient(
            (_) async => http.Response(
              jsonEncode(
                invalidSession
                    ? {'token': 'invalid-role-session', 'role': 'admin'}
                    : {'message': 'Google account not linked'},
              ),
              invalidSession ? 200 : 403,
            ),
          ),
        );
      },
    );
  }
}
