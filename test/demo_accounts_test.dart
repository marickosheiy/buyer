import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/product_model.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/chat_service.dart';
import 'package:flutter_application_1/services/demo_accounts.dart';

Map<String, dynamic> account(String email, {bool seller = false}) => {
  'name': 'Local Test User',
  'email': email,
  'password': 'Password123',
  'phone': '09171234567',
  'account_type': seller ? 'seller' : 'buyer',
  if (seller) 'shop_name': 'Local Test Shop',
  'address': {
    'region': 'CALABARZON',
    'province': 'Laguna',
    'city': 'Pila',
    'barangay': 'San Antonio',
    'street': 'Test Street',
    'postal_code': '4010',
  },
};

void main() {
  setUp(DemoAccounts.reset);
  tearDown(DemoAccounts.reset);

  test(
    'Demo registration normalizes emails and protects existing accounts',
    () {
      DemoAccounts.register(account(' New@Example.invalid '));
      expect(
        () => DemoAccounts.register(account('new@example.invalid')),
        throwsA(isA<ApiException>()),
      );
      for (final email in ['lumear@gmail.com', 'SELLER@LUMEAR.COM']) {
        expect(
          () => DemoAccounts.register(account(email)),
          throwsA(isA<ApiException>()),
        );
      }
      expect(DemoAccounts.signIn('new@example.invalid', 'wrong'), isNull);
      expect(
        DemoAccounts.signIn('NEW@example.invalid', 'Password123')?.name,
        'Local Test User',
      );
    },
  );

  test('Signing out retains a new account; restarting the demo registry removes it', () {
    DemoAccounts.register(account('session@example.invalid'));
    DemoAccounts.signIn('session@example.invalid', 'Password123');
    DemoAccounts.signOut();
    expect(DemoAccounts.current, isNull);
    expect(
      DemoAccounts.signIn('session@example.invalid', 'Password123'),
      isNotNull,
    );
    DemoAccounts.reset();
    expect(
      DemoAccounts.signIn('session@example.invalid', 'Password123'),
      isNull,
    );
    expect(DemoAccounts.signIn('lumear@gmail.com', 'Lumear123')?.role, 'buyer');
  });

  test(
    'Local buyers and new sellers cannot read another buyer conversation',
    () async {
      DemoAccounts.register(account('chat-one@example.invalid'));
      DemoAccounts.signIn('chat-one@example.invalid', 'Password123');
      final buyer = ChatService(connected: false);
      final thread = await buyer.openSeller(sampleLumearProducts.first);
      await buyer.send(thread, 'Is this available?', 'local-1');

      DemoAccounts.register(account('chat-two@example.invalid'));
      DemoAccounts.signIn('chat-two@example.invalid', 'Password123');
      final otherBuyer = ChatService(connected: false);
      expect(await otherBuyer.threads(), isEmpty);
      await expectLater(
        otherBuyer.messages(thread),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        otherBuyer.send(thread, 'Not my chat', 'local-2'),
        throwsA(isA<ApiException>()),
      );

      DemoAccounts.register(account('new-shop@example.invalid', seller: true));
      DemoAccounts.signIn('new-shop@example.invalid', 'Password123');
      final otherSeller = ChatService(connected: false, seller: true);
      expect(await otherSeller.threads(), isEmpty);
      await expectLater(
        otherSeller.messages(thread),
        throwsA(isA<ApiException>()),
      );

      DemoAccounts.signIn('seller@lumear.com', 'Seller123');
      final sampleSeller = ChatService(connected: false, seller: true);
      expect(
        (await sampleSeller.threads()).any((t) => t.id == thread.id),
        isTrue,
      );
      await sampleSeller.send(thread, 'Yes!', 'local-3');
      expect((await buyer.messages(thread)).last.text, 'Yes!');
      expect((await buyer.messages(thread)).last.mine, isFalse);
    },
  );
}
