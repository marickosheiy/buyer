import 'package:flutter/foundation.dart';

import '../product_model.dart';
import '../cart_manager.dart';
import '../address_manager.dart';
import '../order_manager.dart';
import 'wishlist_manager.dart';
import 'api_service.dart';

class BuyerData extends ChangeNotifier {
  BuyerData._();
  static final instance = BuyerData._();
  bool connected = false;
  bool loading = false;
  String? error;
  Map<String, dynamic> profile = {};
  Map<String, dynamic> capabilities = {};
  List<dynamic> notifications = [], vouchers = [];
  Future<void>? _refreshing;
  int _generation = 0;

  void connect() {
    _generation++;
    _refreshing = null;
    connected = true;
    ProductCatalog.instance.connected = true;
    ProductCatalog.instance.products = [];
    CartManager.instance.reload = refresh;
    AddressManager.instance.reload = refresh;
    WishlistManager.instance.reload = refresh;
  }

  Future<void> refresh() {
    final generation = _generation;
    return _refreshing ??= _load(generation).whenComplete(() {
      if (generation == _generation) _refreshing = null;
    });
  }

  Future<void> _load(int generation) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await ApiService.get('/buyer/workspace');
      if (!connected || generation != _generation) return;
      profile = Map<String, dynamic>.from(result['profile']);
      capabilities = Map<String, dynamic>.from(result['capabilities']);
      ProductCatalog.instance.replace(result['products']);
      CartManager.instance.replace(result['cart']);
      AddressManager.instance.replace(result['addresses']);
      OrderManager.instance.replace(result['orders']);
      WishlistManager.instance.replace(result['wishlist']);
      notifications = result['notifications'];
      vouchers = result['vouchers'];
    } catch (e) {
      if (generation == _generation) error = e.toString();
      rethrow;
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> saveProfile(String name) async {
    await ApiService.patch('/me', body: {'name': name});
    await refresh();
  }

  Future<void> markNotification(String? id) async {
    await ApiService.post(
      id == null ? '/notifications' : '/notifications/$id',
      body: {},
    );
    await refresh();
  }

  void reset() {
    _generation++;
    _refreshing = null;
    loading = false;
    connected = false;
    profile = {};
    capabilities = {};
    notifications = [];
    vouchers = [];
    error = null;
    CartManager.instance.reload = null;
    AddressManager.instance.reload = null;
    WishlistManager.instance.reload = null;
    CartManager.instance.clearCart();
    AddressManager.instance.addresses.value = [];
    OrderManager.instance.connected = false;
    OrderManager.instance.clearOrders();
    WishlistManager.instance.clear();
    ProductCatalog.instance.reset();
    notifyListeners();
  }
}
