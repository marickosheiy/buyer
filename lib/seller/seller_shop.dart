import 'package:flutter/foundation.dart';

import 'product_media.dart';

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
  ProductMedia? profileImage;
  ProductMedia? coverImage;

  void readImages(Map<String, dynamic> data) {
    ProductMedia? photo(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return ProductMedia(name: 'Shop photo', isVideo: false, url: value);
      }
      if (value is Map) {
        return ProductMedia.fromProduct({
          'media': [value],
        }).first;
      }
      return null;
    }

    if (data.containsKey('profile_image') ||
        data.containsKey('profile_image_url')) {
      profileImage = photo(data['profile_image'] ?? data['profile_image_url']);
    }
    if (data.containsKey('cover_image') ||
        data.containsKey('cover_image_url')) {
      coverImage = photo(data['cover_image'] ?? data['cover_image_url']);
    }
  }

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
