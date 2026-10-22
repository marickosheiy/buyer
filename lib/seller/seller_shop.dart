import 'package:flutter/foundation.dart';

/// Owned by the seller workspace; discarded when the seller signs out.
class SellerShop extends ChangeNotifier {
  SellerShop({this.connected = false});
  final bool connected;
  String owner = '';
  String name = '';
  String description = '';
  String email = '';
  String phone = '';
  String status = '';

  bool get identityReady => owner.isNotEmpty && name.isNotEmpty;
  bool get storyReady => description.isNotEmpty;
  bool get contactReady => email.isNotEmpty && phone.isNotEmpty;
  int get completed =>
      [identityReady, storyReady, contactReady].where((ready) => ready).length;

  void update({
    required String owner,
    required String name,
    required String description,
    required String email,
    required String phone,
  }) {
    this.owner = owner;
    this.name = name;
    this.description = description;
    this.email = email;
    this.phone = phone;
    notifyListeners();
  }
}
