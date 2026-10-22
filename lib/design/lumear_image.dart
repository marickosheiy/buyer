import 'lumear_theme.dart';

import 'package:flutter/material.dart';

/// The original sample catalog photographs are bundled for reliable offline previews.
/// Unknown server-provided images still use the normal network image path.
class LumearImage extends StatelessWidget {
  const LumearImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.errorBuilder,
    this.loadingBuilder,
  });
  final String url;
  final double? width, height;
  final BoxFit? fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  static const bundled = <String>{
    'photo-1503341504253-dff4815485f1',
    'photo-1505740420928-5e560c06d30e',
    'photo-1515562141207-7a88fb7ce338',
    'photo-1519689680058-324335c77eba',
    'photo-1521572163474-6864f9cf17ab',
    'photo-1529139574466-a303027c1d8b',
    'photo-1546435770-a3e426bf472b',
    'photo-1553062407-98eeb64c6a62',
    'photo-1555041469-a586c61ea9bc',
    'photo-1596462502278-27bfdc403348',
    'photo-1600080972464-8e5f35f63d08',
  };
  @override
  Widget build(BuildContext context) {
    LumearAppearance.watch(context);
    if (url.isEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: Center(
          child: Icon(
            Icons.inventory_2_outlined,
            color: LumearColors.light,
            size: 42,
          ),
        ),
      );
    }
    final uri = Uri.tryParse(url);
    final photo = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : '';
    if (uri?.host == 'images.unsplash.com' && bundled.contains(photo)) {
      return Image.asset(
        'assets/images/products/$photo.jpg',
        width: width,
        height: height,
        fit: fit,
        errorBuilder: errorBuilder,
      );
    }
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: errorBuilder,
      loadingBuilder: loadingBuilder,
    );
  }
}
