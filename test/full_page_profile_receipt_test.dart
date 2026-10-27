import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/address_manager.dart';
import 'package:flutter_application_1/cart_manager.dart';
import 'package:flutter_application_1/checkout_receipt_screen.dart';
import 'package:flutter_application_1/checkout_screen.dart';
import 'package:flutter_application_1/design/lumear_theme.dart';
import 'package:flutter_application_1/order_manager.dart';
import 'package:flutter_application_1/seller/seller_profile_screen.dart';
import 'package:flutter_application_1/seller/seller_shop.dart';
import 'package:flutter_application_1/seller/seller_shop_editor_screen.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/buyer_data.dart';

final class _Photo extends PlatformFile {
  _Photo(this.name, this.bytes);
  @override
  final String name;
  final Uint8List bytes;
  @override
  Uri get uri => Uri.file(name);
  @override
  int? lengthSync() => bytes.length;
  @override
  Future<int?> length() async => bytes.length;
  @override
  Future<Uint8List> readAsBytes() async => bytes;
  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Picker extends FilePickerPlatform {
  PlatformFile? selected;
  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => selected;
}

void main() {
  final png = File('assets/images/logo.png').readAsBytesSync();
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  SellerShop shop({bool connected = false}) => SellerShop(connected: connected)
    ..update(
      owner: 'Maria',
      name: 'Handmade Shop',
      description: 'Our story',
      email: 'maria@example.com',
      phone: '09171234567',
    );

  testWidgets('shop photos preview, save, remove and cancel on a full page', (
    tester,
  ) async {
    phone(tester);
    final data = shop();
    addTearDown(data.dispose);
    final picker = _Picker();
    final original = FilePickerPlatform.instance;
    FilePickerPlatform.instance = picker;
    addTearDown(() => FilePickerPlatform.instance = original);
    await tester.pumpWidget(
      MaterialApp(
        theme: lumearTheme(),
        home: SellerProfileScreen(shop: data),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> open() async {
      await tester.ensureVisible(find.text('Edit shop profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit shop profile'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SellerShopEditorScreen), findsOneWidget);
      expect(tester.getSize(find.byType(Scaffold).last), const Size(360, 800));
    }

    Future<void> pick(String label, String filename) async {
      picker.selected = _Photo(filename, png);
      await tester.ensureVisible(find.text(label));
      await tester.runAsync(() async {
        await tester.tap(find.text(label));
        // Image decoding runs on the engine outside the widget fake clock.
        for (var i = 0; i < 100; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
          if (find.byType(LinearProgressIndicator).evaluate().isEmpty) break;
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await open();
    await pick('Add profile picture', 'profile.png');
    await pick('Add background picture', 'background.png');
    expect(find.text('Remove profile picture'), findsOneWidget);
    expect(find.text('Remove background picture'), findsOneWidget);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(data.profileImage?.name, 'profile.png');
    expect(data.coverImage?.name, 'background.png');
    expect(find.byType(SellerShopEditorScreen), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shop-profile-photo')), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-cover-photo')), findsOneWidget);
    expect(find.byType(Image), findsAtLeastNWidgets(2));

    await open();
    await tester.tap(find.text('Remove profile picture'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(data.profileImage, isNotNull);
    await open();
    await tester.tap(find.text('Remove profile picture'));
    await tester.tap(find.text('Remove background picture'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(data.profileImage, isNull);
    expect(data.coverImage, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failed connected save retains the full-page draft for retry', (
    tester,
  ) async {
    phone(tester);
    final data = shop(connected: true);
    addTearDown(data.dispose);
    ApiService.baseUrl = 'https://integration.example.invalid/api';
    addTearDown(() => ApiService.baseUrl = '');
    var requests = 0;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            theme: lumearTheme(),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  child: const Text('Edit'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SellerShopEditorScreen(shop: data),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        final name = find.widgetWithText(TextFormField, 'Shop name');
        await tester.ensureVisible(name);
        await tester.enterText(name, 'Updated Shop');
        await tester.tap(find.text('Save changes'));
        await tester.pumpAndSettle();
        expect(find.byType(SellerShopEditorScreen), findsOneWidget);
        expect(find.text('Updated Shop'), findsOneWidget);
        expect(data.name, 'Handmade Shop');
        await tester.tap(find.text('Save changes'));
        await tester.pumpAndSettle();
        expect(data.name, 'Updated Shop');
        expect(find.byType(SellerShopEditorScreen), findsNothing);
      },
      () => MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/seller/shop');
        final body = jsonDecode(request.body) as Map;
        expect(body['name'], 'Updated Shop');
        expect(body.containsKey('profile_image'), isFalse);
        requests++;
        return http.Response(
          requests == 1 ? '{"message":"Save unavailable"}' : '{}',
          requests == 1 ? 503 : 200,
        );
      }),
    );
  });

  for (final back in [false, true]) {
    testWidgets(
      'checkout receipt fills the screen and ${back ? 'Back' : 'Done'} returns to cart',
      (tester) async {
        phone(tester);
        BuyerData.instance.reset();
        addTearDown(BuyerData.instance.reset);
        await AddressManager.instance.addAddress(
          SavedAddress(
            id: '1',
            label: 'Home',
            fullName: 'Buyer',
            phone: '09171234567',
            region: 'NCR',
            province: 'Metro Manila',
            cityMunicipality: 'Manila',
            barangay: 'Barangay 1',
            houseStreet: '1 Sample Street',
          ),
        );
        await CartManager.instance.addToCart(
          name: 'Basket',
          price: '₱1000.00',
          icon: Icons.shopping_bag_outlined,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: lumearTheme(),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                  ),
                  child: const Text('Cart checkout'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Cart checkout'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('PLACE ORDER'));
        await tester.pumpAndSettle();
        expect(find.byType(CheckoutReceiptScreen), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);
        expect(find.byType(CheckoutScreen), findsNothing);
        expect(
          tester.getSize(find.byType(Scaffold).last),
          const Size(360, 800),
        );
        expect(OrderManager.instance.latestOrder!.shippingFee, 50);
        expect(find.text('₱1050.00'), findsOneWidget);
        if (back) {
          await tester.pageBack();
        } else {
          await tester.ensureVisible(find.text('DONE'));
          await tester.tap(find.text('DONE'));
        }
        await tester.pumpAndSettle();
        expect(find.text('Cart checkout'), findsOneWidget);
        expect(find.byType(CheckoutScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
