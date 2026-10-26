import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/design/lumear_theme.dart';
import 'package:flutter_application_1/register_page.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/postal_code_service.dart';
import 'package:flutter_application_1/services/demo_accounts.dart';
import 'package:flutter_application_1/login_page.dart';
import 'package:flutter_application_1/screen/dashboard_screen.dart';
import 'package:flutter_application_1/seller/seller_dashboard_screen.dart';
import 'package:flutter_application_1/address_manager.dart';
import 'package:flutter_application_1/services/buyer_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(DemoAccounts.reset);
  tearDown(() {
    DemoAccounts.reset();
    BuyerData.instance.reset();
  });

  test(
    'Postal lookup uses province and normalizes city and Santa aliases',
    () async {
      final lookup = await PostalCodeService.load();
      expect(lookup.find(province: 'Laguna', municipality: 'Pila'), '4010');
      expect(
        lookup.find(province: 'Laguna', municipality: 'City of Santa Rosa'),
        '4026',
      );
      expect(
        lookup.find(province: 'Laguna', municipality: 'Santa Cruz '),
        '4009',
      );
      expect(
        lookup.find(province: 'Unknown province', municipality: 'Pila'),
        isNull,
      );
      expect(lookup.find(province: '', municipality: ''), isNull);
    },
  );

  for (final mode in ['connected', 'demo buyer', 'demo seller']) {
    final connected = mode == 'connected';
    final seller = mode == 'demo seller';
    testWidgets(
      '$mode registration fills postal code and creates the account',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        ApiService.baseUrl = 'https://integration.example.invalid/api';
        addTearDown(() => ApiService.baseUrl = '');
        Map<String, dynamic>? registration;

        Finder field(String hint) => find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.hintText == hint,
        );
        Future<void> fill(String hint, String value) async {
          final target = field(hint);
          await tester.ensureVisible(target);
          await tester.enterText(target, value);
          await tester.pumpAndSettle();
        }

        Future<void> pick(String hint, String name) async {
          final target = find.byWidgetPredicate(
            (widget) =>
                widget is InputDecorator && widget.decoration.hintText == hint,
          );
          await tester.ensureVisible(target);
          await tester.tap(target);
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(ListTile, name));
          await tester.pumpAndSettle();
        }

        await http.runWithClient(
          () async {
            await tester.pumpWidget(
              MaterialApp(
                theme: lumearTheme(),
                home: connected
                    ? const RegisterPage(useBackend: true)
                    : const LoginPage(useBackend: false),
              ),
            );
            await tester.pumpAndSettle();
            if (!connected) {
              final create = find.widgetWithText(
                TextButton,
                'Create an account',
              );
              await tester.ensureVisible(create);
              await tester.tap(create);
              await tester.pumpAndSettle();
            }
            if (seller) {
              await tester.ensureVisible(find.text('Seller'));
              await tester.tap(find.text('Seller'));
              await tester.pumpAndSettle();
            }
            await fill('First name', 'Ana');
            await fill('Last name', 'Reyes');
            await fill('Email address', 'ana@example.invalid');
            await fill('Mobile number', 'ab09!123456789999');
            expect(
              tester.widget<TextField>(field('Mobile number')).controller!.text,
              '09123456789',
            );
            final birthDate = find.text('Select your date of birth');
            await tester.ensureVisible(birthDate);
            await tester.tap(birthDate);
            await tester.pumpAndSettle();
            await tester.tap(find.text('CONFIRM'));
            await tester.pumpAndSettle();
            await fill('Password*', 'Password123');
            await fill('Confirm password*', 'Password123');
            await fill('Mobile number', '0912345678');
            await tester.tap(find.text('CONTINUE'));
            await tester.pumpAndSettle();
            expect(
              find.text('Enter an 11-digit mobile number starting with 09.'),
              findsOneWidget,
            );
            await tester.pump(const Duration(seconds: 5));
            await tester.pumpAndSettle();
            await fill('Mobile number', '09123456789');
            await tester.tap(find.text('CONTINUE'));
            await tester.pumpAndSettle();
            await pick('Region*', 'CALABARZON');
            await pick('Province*', 'Laguna');
            await pick('City / Municipality*', 'Pila');
            final postal = find.byKey(
              const ValueKey('registration-postal-code'),
            );
            expect(tester.widget<TextField>(postal).controller!.text, '4010');
            await pick('City / Municipality*', 'Santa Cruz');
            expect(tester.widget<TextField>(postal).controller!.text, '4009');
            await pick('Province*', 'Laguna');
            expect(tester.widget<TextField>(postal).controller!.text, isEmpty);
            expect(tester.widget<TextField>(postal).enabled, isFalse);
            await pick('City / Municipality*', 'Pila');
            await pick('Barangay*', 'San Antonio');
            await fill('Street*', 'Rizal Street');
            await tester.ensureVisible(postal);
            await tester.enterText(postal, '40');
            await tester.tap(find.text('CONTINUE'));
            await tester.pumpAndSettle();
            expect(
              find.text('Please enter a valid four-digit postal code.'),
              findsOneWidget,
            );
            await tester.pump(const Duration(seconds: 5));
            await tester.pumpAndSettle();
            await tester.enterText(postal, '4010');
            await tester.tap(find.text('CONTINUE'));
            await tester.pumpAndSettle();
            if (connected) {
              await tester.ensureVisible(find.text('Send verification code'));
              await tester.tap(find.text('Send verification code'));
              await tester.pumpAndSettle();
              await tester.enterText(find.byType(TextField), '654321');
              await tester.ensureVisible(find.text('Verify email'));
              await tester.tap(
                find.widgetWithText(FilledButton, 'Verify email'),
              );
              await tester.pumpAndSettle();
            } else {
              expect(find.text('Send verification code'), findsNothing);
              expect(find.text('SELECT FILE'), findsNothing);
              if (seller) {
                await fill('Shop name *', 'Ana Demo Shop');
                await fill('Shop description *', 'Demo shop description');
              }
            }
            await tester.tap(find.text('CREATE ACCOUNT'));
            await tester.pumpAndSettle();
            if (connected) {
              expect(registration?['address'], {
                'region': 'CALABARZON',
                'province': 'Laguna',
                'city': 'Pila',
                'barangay': 'San Antonio',
                'street': 'Rizal Street',
                'postal_code': '4010',
              });
            } else {
              expect(
                find.text(
                  seller
                      ? 'Seller Demo Account Created!'
                      : 'Buyer Demo Account Created!',
                ),
                findsOneWidget,
              );
              await tester.tap(find.text('GO TO LOGIN'));
              await tester.pumpAndSettle();
              final loginFields = find.byType(TextField);
              await tester.enterText(loginFields.at(0), 'ana@example.invalid');
              await tester.enterText(loginFields.at(1), 'Password123');
              final signIn = find.widgetWithText(FilledButton, 'Sign in');
              await tester.ensureVisible(signIn);
              await tester.tap(signIn);
              await tester.pumpAndSettle();
              expect(
                find.byType(seller ? SellerDashboardScreen : DashboardScreen),
                findsOneWidget,
              );
              expect(DemoAccounts.current?.name, 'Ana Reyes');
              expect(
                AddressManager.instance.addresses.value.single.postalCode,
                '4010',
              );
              expect(registration, isNull);
              if (seller) {
                expect(find.text('Ana Demo Shop'), findsWidgets);
              } else {
                await tester.tap(find.text('Me').last);
                await tester.pumpAndSettle();
                expect(find.text('Ana Reyes'), findsOneWidget);
                expect(find.text('ana@example.invalid'), findsOneWidget);
              }
            }
            expect(tester.takeException(), isNull);
          },
          () => MockClient((request) async {
            final path = request.url.path;
            dynamic data;
            if (request.url.host == 'psgc.cloud') {
              data = path.endsWith('/regions')
                  ? [
                      {'code': 'r1', 'name': 'CALABARZON'},
                    ]
                  : path.endsWith('/provinces')
                  ? [
                      {'code': 'p1', 'name': 'Laguna'},
                    ]
                  : path.endsWith('/cities-municipalities')
                  ? [
                      {'code': 'c1', 'name': 'Pila', 'zip_code': '4005'},
                      {'code': 'c2', 'name': 'Santa Cruz', 'zip_code': '4004'},
                    ]
                  : [
                      {'code': 'b1', 'name': 'San Antonio'},
                    ];
            } else if (!connected) {
              fail(
                'Demo registration must not call the backend: ${request.url}',
              );
            } else if (path.endsWith('/email/send')) {
              data = {'challenge_id': '1', 'message': 'Sent'};
            } else if (path.endsWith('/email/verify')) {
              data = {
                'verified': true,
                'verification_token': 'proof',
                'message': 'Verified',
              };
            } else if (path.endsWith('/register')) {
              registration = Map<String, dynamic>.from(
                jsonDecode(request.body),
              );
              data = {};
            } else {
              fail('Unexpected request: ${request.url}');
            }
            return http.Response(
              jsonEncode(data),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
      },
    );
  }
}
