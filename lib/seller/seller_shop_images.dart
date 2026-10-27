import 'package:flutter/material.dart';

import '../design/lumear_theme.dart';
import 'product_media.dart';

class ShopPhoto extends StatelessWidget {
  const ShopPhoto({super.key, required this.photo, this.profile = false});
  final ProductMedia? photo;
  final bool profile;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: LumearColors.field,
      child: Center(
        child: Icon(
          profile ? Icons.person_outline : Icons.storefront_outlined,
          color: LumearColors.maroon,
          size: profile ? 32 : 48,
        ),
      ),
    );
    final image = photo;
    if (image == null) return fallback;
    if (image.bytes != null) {
      return Image.memory(
        image.bytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    if (image.url?.isNotEmpty == true) {
      return Image.network(
        image.url!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return fallback;
  }
}

class SellerShopImages extends StatelessWidget {
  const SellerShopImages({super.key, this.profileImage, this.coverImage});
  final ProductMedia? profileImage, coverImage;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 216,
    child: Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 168,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ShopPhoto(
              key: const ValueKey('shop-cover-photo'),
              photo: coverImage,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 20,
          width: 96,
          height: 96,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: ClipOval(
                child: ShopPhoto(
                  key: const ValueKey('shop-profile-photo'),
                  photo: profileImage,
                  profile: true,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
