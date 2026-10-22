import 'package:flutter/foundation.dart';

import 'services/api_service.dart';

class SavedAddress {
  String id;
  String label;
  String fullName;
  String phone;
  String region;
  String province;
  String cityMunicipality;
  String barangay;
  String houseStreet;
  bool isDefault;
  String postalCode;

  SavedAddress({
    required this.id,
    required this.label,
    required this.fullName,
    required this.phone,
    required this.region,
    required this.province,
    required this.cityMunicipality,
    required this.barangay,
    required this.houseStreet,
    this.isDefault = false,
    this.postalCode = '',
  });

  String get formattedAddress {
    return '$houseStreet, $barangay, $cityMunicipality, $province';
  }

  String get shortAddress {
    return '$cityMunicipality, $province';
  }
}

class AddressManager {
  AddressManager._();

  static final AddressManager instance = AddressManager._();

  final ValueNotifier<List<SavedAddress>> addresses =
      ValueNotifier<List<SavedAddress>>([]);
  Future<void> Function()? reload;
  bool get connected => reload != null;
  void replace(List<dynamic> rows) {
    addresses.value = rows
        .map(
          (a) => SavedAddress(
            id: a['id'].toString(),
            label: a['label'],
            fullName: a['name'],
            phone: a['phone'],
            region: a['region'] ?? '',
            province: a['province'],
            cityMunicipality: a['city'],
            barangay: a['barangay'] ?? '',
            houseStreet: a['street'],
            postalCode: a['postal_code'] ?? '',
            isDefault: a['default'] == true,
          ),
        )
        .toList();
  }

  Map<String, dynamic> body(SavedAddress a) => {
    'label': a.label,
    'name': a.fullName,
    'phone': a.phone,
    'street': a.houseStreet,
    'barangay': a.barangay,
    'city': a.cityMunicipality,
    'province': a.province,
    'postal_code': a.postalCode,
    'default': a.isDefault,
  };

  // ============================================================
  // ADD ADDRESS
  // ============================================================

  Future<SavedAddress> addAddress(SavedAddress address) async {
    if (connected) {
      final result = await ApiService.post('/addresses', body: body(address));
      await reload!();
      return addresses.value.firstWhere((a) => a.id == result['id'].toString());
    }
    final current = List<SavedAddress>.from(addresses.value);

    // If this address is default,
    // remove default status from all other addresses.
    if (address.isDefault) {
      for (final item in current) {
        item.isDefault = false;
      }
    }

    // First address automatically becomes default.
    if (current.isEmpty) {
      address.isDefault = true;
    }

    current.add(address);

    addresses.value = current;
    return address;
  }

  // ============================================================
  // UPDATE ADDRESS
  // ============================================================

  Future<void> updateAddress(SavedAddress address) async {
    if (connected) {
      await ApiService.patch('/addresses/${address.id}', body: body(address));
      await reload!();
      return;
    }
    final current = List<SavedAddress>.from(addresses.value);

    if (address.isDefault) {
      for (final item in current) {
        item.isDefault = false;
      }
    }

    final index = current.indexWhere((item) => item.id == address.id);

    if (index != -1) {
      current[index] = address;
    }

    addresses.value = current;
  }

  // ============================================================
  // DELETE ADDRESS
  // ============================================================

  Future<void> deleteAddress(String id) async {
    if (connected) {
      await ApiService.delete('/addresses/$id');
      await reload!();
      return;
    }
    final current = List<SavedAddress>.from(addresses.value);

    final wasDefault = current.any((item) => item.id == id && item.isDefault);

    current.removeWhere((item) => item.id == id);

    // If the deleted address was the default,
    // make the first remaining address default.
    if (wasDefault && current.isNotEmpty) {
      current.first.isDefault = true;
    }

    addresses.value = current;
  }

  // ============================================================
  // SET DEFAULT
  // ============================================================

  Future<void> setDefault(String id) async {
    if (connected) {
      await ApiService.patch('/addresses/$id', body: {'default': true});
      await reload!();
      return;
    }
    final current = List<SavedAddress>.from(addresses.value);

    for (final item in current) {
      item.isDefault = item.id == id;
    }

    addresses.value = current;
  }

  // ============================================================
  // GET DEFAULT ADDRESS
  // ============================================================

  SavedAddress? get defaultAddress {
    for (final address in addresses.value) {
      if (address.isDefault) {
        return address;
      }
    }

    if (addresses.value.isNotEmpty) {
      return addresses.value.first;
    }

    return null;
  }
}
