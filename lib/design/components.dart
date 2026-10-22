import 'lumear_image.dart';

import 'package:flutter/material.dart';

import '../product_model.dart';
import '../screen/product_detail_screen.dart';
import '../services/wishlist_manager.dart';
import '../services/ui_action.dart';
import 'lumear_theme.dart';

class PageHeading extends StatelessWidget {
  const PageHeading(
    this.title, {
    super.key,
    this.eyebrow,
    this.subtitle,
    this.action,
  });
  final String title;
  final String? eyebrow, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null)
                  Text(
                    eyebrow!.toUpperCase(),
                    style: TextStyle(
                      color: LumearColors.maroon,
                      letterSpacing: 2,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 7),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 29,
                    fontFamily: 'serif',
                    fontFamilyFallback: const ['Roboto'],
                    height: 1.1,
                    color: LumearColors.dark,
                    letterSpacing: -0.8,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 9),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: LumearColors.ink,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?action,
        ],
      ),
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.kicker, this.onTap});
  final String title;
  final String? kicker;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => Padding(
      padding: const EdgeInsets.fromLTRB(0, 26, 0, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (kicker != null)
                  Text(
                    kicker!.toUpperCase(),
                    style: TextStyle(
                      color: LumearColors.maroon,
                      fontSize: 9,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 23,
                    fontFamily: 'serif',
                    fontFamilyFallback: const ['Roboto'],
                    color: LumearColors.dark,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            IconButton(
              tooltip: 'Explore $title',
              onPressed: onTap,
              icon: Icon(
                Icons.arrow_forward_rounded,
                color: LumearColors.maroon,
              ),
            ),
        ],
      ),
    ),
  );
}

class ProductCard extends StatelessWidget {
  const ProductCard(this.product, {super.key});
  final LumearProduct product;
  @override
  Widget build(BuildContext context) {
    LumearAppearance.watch(context);
    final p = product;
    final discount =
        p.originalPrice != null &&
            p.originalPrice! > p.price &&
            p.originalPrice! > 0
        ? ((1 - p.price / p.originalPrice!) * 100).round()
        : 0;
    void open() => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p)),
    );
    return Material(
      color: LumearColors.field,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: open,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProductImage(p),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: LumearColors.cream,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Text(
                        p.category.toUpperCase(),
                        style: TextStyle(
                          fontSize: 8,
                          color: LumearColors.dark,
                          letterSpacing: .8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (discount > 0)
                    Positioned(
                      top: 12,
                      left: -1,
                      child: Transform.rotate(
                        angle: -.07,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          color: LumearColors.maroon,
                          child: Text(
                            '−$discount%',
                            style: TextStyle(
                              color: LumearColors.cream,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: ListenableBuilder(
                      listenable: WishlistManager.instance,
                      builder: (_, _) => IconButton.filledTonal(
                        tooltip: WishlistManager.instance.contains(p.id)
                            ? 'Remove from wishlist'
                            : 'Save to wishlist',
                        style: IconButton.styleFrom(
                          backgroundColor: LumearColors.cream,
                          foregroundColor: LumearColors.dark,
                        ),
                        onPressed: () => runBuyerAction(
                          context,
                          () => WishlistManager.instance.toggle(p),
                        ),
                        iconSize: 18,
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            WishlistManager.instance.contains(p.id)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            key: ValueKey(
                              WishlistManager.instance.contains(p.id),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: LumearColors.ink,
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (discount > 0)
                              Text(
                                '₱${p.originalPrice!.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: LumearColors.ink,
                                  fontSize: 10,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            Text(
                              p.formattedPrice,
                              style: TextStyle(
                                color: LumearColors.dark,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox.square(
                        dimension: 34,
                        child: IconButton.filled(
                          tooltip: 'Choose product options',
                          onPressed: open,
                          padding: EdgeInsets.zero,
                          style: IconButton.styleFrom(
                            backgroundColor: LumearColors.action,
                            foregroundColor: LumearColors.cream,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.north_east, size: 17),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '★ ${p.rating.toStringAsFixed(1)}  ·  ${p.soldCount} sold',
                    style: TextStyle(color: LumearColors.ink, fontSize: 9),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductImage extends StatelessWidget {
  const ProductImage(this.product, {super.key, this.fit = BoxFit.cover});
  final LumearProduct product;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => LumearImage(
      product.imageUrl,
      fit: fit,
      width: double.infinity,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : ColoredBox(
              color: LumearColors.field,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: progress.expectedTotalBytes == null
                      ? null
                      : progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!,
                ),
              ),
            ),
      errorBuilder: (_, _, _) => ColoredBox(
        color: LumearColors.field,
        child: Center(
          child: Icon(product.icon, size: 52, color: LumearColors.light),
        ),
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.shopping_bag_outlined,
    this.action,
  });
  final String title, message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: LumearColors.field,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: LumearColors.maroon),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'CormorantGaramond',
                color: LumearColors.dark,
                fontSize: 25,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LumearColors.ink,
                height: 1.6,
                fontSize: 13,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    ),
  );
}
