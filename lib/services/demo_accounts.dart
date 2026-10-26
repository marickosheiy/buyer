import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'api_service.dart';
import 'mobile_number.dart';

class DemoAccount {
  const DemoAccount({
    required this.email,
    required this.name,
    required this.role,
    this.phone = '',
    this.shopName = '',
    this.shopDescription = '',
    this.address,
  });
  final String email, name, role, phone, shopName, shopDescription;
  final Map<String, String>? address;
}

/// Local preview accounts only. Nothing is written to disk or sent to a server.
/// This is not production authentication or a replacement for backend verification.
abstract final class DemoAccounts {
  static final Map<String, ({DemoAccount account, String salt, String digest})>
  _accounts = {};
  static DemoAccount? current;
  static const _reserved = {'lumear@gmail.com', 'seller@lumear.com'};

  static DemoAccount register(Map<String, dynamic> body) {
    final email = (body['email'] as String).trim().toLowerCase();
    if (_reserved.contains(email) || _accounts.containsKey(email)) {
      throw const ApiException(
        'A demo account with this email already exists.',
      );
    }
    final role = body['account_type'] as String;
    final password = body['password'] as String;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) ||
        !['buyer', 'seller'].contains(role) ||
        !RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d).{8,}$').hasMatch(password) ||
        !MobileNumber.isValid(body['phone'] as String)) {
      throw const ApiException('Please check your demo account details.');
    }
    final account = DemoAccount(
      email: email,
      name: (body['name'] as String).trim(),
      role: role,
      phone: body['phone'] as String,
      shopName: body['shop_name'] as String? ?? '',
      shopDescription: body['shop_description'] as String? ?? '',
      address: Map<String, String>.unmodifiable({
        for (final entry in (body['address'] as Map<String, dynamic>).entries)
          entry.key: entry.value?.toString() ?? '',
      }),
    );
    final random = Random.secure();
    final salt = List.generate(24, (_) => random.nextInt(256)).join('-');
    _accounts[email] = (
      account: account,
      salt: salt,
      digest: _digest(salt, password),
    );
    return account;
  }

  static String _digest(String salt, String password) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  static DemoAccount? signIn(String email, String password) {
    email = email.trim().toLowerCase();
    DemoAccount? account;
    if (email == 'lumear@gmail.com' && password == 'Lumear123') {
      account = const DemoAccount(
        email: 'lumear@gmail.com',
        name: 'Lumear Buyer',
        role: 'buyer',
      );
    } else if (email == 'seller@lumear.com' && password == 'Seller123') {
      account = const DemoAccount(
        email: 'seller@lumear.com',
        name: '',
        role: 'seller',
      );
    } else {
      final stored = _accounts[email];
      if (stored != null && stored.digest == _digest(stored.salt, password)) {
        account = stored.account;
      }
    }
    current = account;
    return account;
  }

  static void signOut() => current = null;
  static void reset() {
    current = null;
    _accounts.clear();
  }
}
