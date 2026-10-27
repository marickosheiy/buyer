import 'package:flutter_application_1/services/api_service.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/seller/seller_commerce.dart';
import 'package:flutter_application_1/seller/seller_tools_screen.dart';

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/design/lumear_theme.dart';
import 'package:flutter_application_1/screen/dashboard_screen.dart';
import 'package:flutter_application_1/seller/seller_dashboard_screen.dart';
import 'package:flutter_application_1/services/buyer_data.dart';
import 'package:flutter_application_1/login_page.dart';

Widget themed(Widget home) => ListenableBuilder(
  listenable: LumearAppearance.instance,
  builder: (context, _) => LumearAppearanceScope(
    child: MaterialApp(
      theme: lumearTheme(dark: false),
      darkTheme: lumearTheme(dark: true),
      themeMode: LumearAppearance.instance.mode,
      home: RepaintBoundary(key: const ValueKey('preview'), child: home),
    ),
  ),
);
Future<void> preview(WidgetTester tester, String name) async {
  if (const bool.fromEnvironment('WRITE_UI_PREVIEWS')) {
    await expectLater(
      find.byKey(const ValueKey('preview')),
      matchesGoldenFile('../build/design-preview/$name.png'),
    );
  }
}

void main() {
  setUp(() => ApiService.baseUrl = 'https://integration.example.invalid/api');
  tearDown(() {
    ApiService.baseUrl = '';
    ApiService.setToken(null);
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (const bool.fromEnvironment('WRITE_UI_PREVIEWS')) {
      for (final font in [
        ('Roboto', 'C:/Windows/Fonts/segoeui.ttf'),
        ('serif', 'C:/Windows/Fonts/georgia.ttf'),
      ]) {
        final loader = FontLoader(font.$1)
          ..addFont(
            Future.value(
              ByteData.sublistView(await File(font.$2).readAsBytes()),
            ),
          );
        await loader.load();
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  final saved = <String>[];
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LumearAppearance.channel, (call) async {
          if (call.method == 'write') saved.add(call.arguments as String);
          return call.method == 'read' ? 'dark' : null;
        });
    saved.clear();
    BuyerData.instance.reset();
    await LumearAppearance.instance.setMode(ThemeMode.light);
  });
  tearDown(() async {
    await LumearAppearance.instance.setMode(ThemeMode.system);
    BuyerData.instance.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LumearAppearance.channel, null);
  });
  testWidgets(
    'Demo account selection keeps readable text and seller sign-in retains dark mode',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(themed(const LoginPage(useBackend: false)));
      await tester.pumpAndSettle();
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        await LumearAppearance.instance.setMode(mode);
        await tester.pumpAndSettle();
        for (final label in ['Buyer', 'Seller · local preview']) {
          final option = find.widgetWithText(ChoiceChip, label);
          await tester.ensureVisible(option);
          await tester.pumpAndSettle();
          await tester.tap(option);
          await tester.pumpAndSettle();
          final chip = tester.widget<ChoiceChip>(option);
          expect(chip.selected, isTrue);
          final background = chip.selectedColor!.computeLuminance();
          final foreground = (chip.label as Text).style!.color!
              .computeLuminance();
          final contrast = background > foreground
              ? (background + .05) / (foreground + .05)
              : (foreground + .05) / (background + .05);
          expect(
            contrast,
            greaterThanOrEqualTo(4.5),
            reason: '$label should remain readable in ${mode.name} mode',
          );
          expect(LumearAppearance.instance.mode, mode);
          if (mode == ThemeMode.dark) {
            expect((chip.label as Text).style!.color, LumearColors.charcoal);
          }
        }
      }
      final signIn = find.widgetWithText(FilledButton, 'Sign in');
      await tester.ensureVisible(signIn);
      await tester.pumpAndSettle();
      await tester.tap(signIn);
      await tester.pumpAndSettle();
      expect(find.byType(SellerDashboardScreen), findsOneWidget);
      expect(LumearAppearance.instance.mode, ThemeMode.dark);
      expect(
        Theme.of(tester.element(find.byType(SellerDashboardScreen))).brightness,
        Brightness.dark,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Buyer appearance changes live and persists the preference', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(themed(const DashboardScreen()));
    await tester.pumpAndSettle();
    await preview(tester, 'buyer-light-phone');
    await tester.tap(find.byTooltip('Dark mode').first);
    await tester.pumpAndSettle();
    expect(saved.last, 'dark');
    expect(LumearColors.ink, LumearColors.beige);
    expect(
      Theme.of(tester.element(find.byType(DashboardScreen))).brightness,
      Brightness.dark,
    );
    await preview(tester, 'buyer-dark-phone');
    await tester.tap(find.byTooltip('Dark mode').first);
    await tester.pumpAndSettle();
    expect(saved.last, 'light');
    expect(LumearAppearance.instance.isDark, isFalse);
    await tester.tap(find.text('Me').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'Seller tablet has a sidebar, responsive catalogue and dark profile',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await LumearAppearance.instance.setMode(ThemeMode.dark);
      await tester.pumpWidget(themed(const SellerDashboardScreen()));
      await tester.pumpAndSettle();
      expect(find.text('SELLER CENTRE'), findsOneWidget);
      await preview(tester, 'seller-dark-tablet');
      await tester.tap(find.text('Products').first);
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsOneWidget);
      expect(tester.takeException(), isNull);
      await preview(tester, 'seller-products-dark-tablet');
      await tester.tap(find.text('My profile').first);
      await tester.pumpAndSettle();
      expect(find.text('Sign-in protection'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await preview(tester, 'seller-profile-dark-tablet');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Seller fits a narrow phone and opens additional operations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await LumearAppearance.instance.setMode(ThemeMode.dark);
    await tester.pumpWidget(themed(const SellerDashboardScreen()));
    await tester.pumpAndSettle();
    await preview(tester, 'seller-dark-phone');
    await tester.tap(find.byTooltip('Seller menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inventory'));
    await tester.pumpAndSettle();
    expect(find.text('STOCK CONTROL'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'Seller payout form submits integer centavos and uses the manual review queue',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await LumearAppearance.instance.setMode(ThemeMode.dark);
      final data = SellerCommerce(connected: true);
      data.earnings = {
        'gross_sales': 1668500,
        'fees': 133480,
        'net_sales': 1535020,
        'wallet_available': 273428,
        'wallet_pending': 1161592,
        'available_to_request': 173428,
        'payout_accounts': [
          {'id': '7', 'name': 'Store owner', 'type': 'bank'},
        ],
        'payouts': [
          {'id': '1', 'amount': 100000, 'status': 'requested'},
        ],
        'journals': [
          {
            'type': 'cod_sale_pending',
            'available_delta': 0,
            'pending_delta': 46000,
            'reference': 'Order reference',
          },
        ],
      };
      var submitted = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            themed(
              Scaffold(
                body: SellerToolsScreen(commerce: data, section: 'Earnings'),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await preview(tester, 'seller-earnings-dark-tablet');
          await tester.scrollUntilVisible(
            find.widgetWithText(FilledButton, 'Request payout'),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, 'Request payout'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField).last, '0');
          await tester.tap(
            find.widgetWithText(FilledButton, 'Request payout').last,
          );
          await tester.pumpAndSettle();
          expect(submitted, 0);
          await tester.enterText(find.byType(TextField).last, '25.10');
          await tester.tap(
            find.widgetWithText(FilledButton, 'Request payout').last,
          );
          await tester.pumpAndSettle();
          expect(submitted, 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        () => MockClient((request) async {
          if (request.method == 'POST') {
            expect(request.url.path, '/api/seller/payouts');
            final body = jsonDecode(request.body);
            expect(body['amount'], 2510);
            expect(body['account_id'], '7');
            expect(body['idempotency_key'], isNotEmpty);
            submitted++;
            return http.Response(
              jsonEncode({
                'message': 'Payout request received for manual review.',
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'shop': {},
              'products': [],
              'orders': [],
              'categories': [],
              'earnings': data.earnings,
            }),
            200,
          );
        }),
      );
      data.dispose();
    },
  );
}
