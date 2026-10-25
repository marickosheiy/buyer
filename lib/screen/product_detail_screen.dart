import '../design/lumear_theme.dart';
import '../design/lumear_image.dart';

import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';

import '../cart_manager.dart';
import '../cart_screen.dart';
import '../product_model.dart';
import '../design/components.dart';
import '../services/wishlist_manager.dart';
import '../services/ui_action.dart';
import '../search_screen.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final LumearProduct product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with SingleTickerProviderStateMixin {
  static Color get cream => LumearColors.cream;
  static Color get maroon => LumearColors.maroon;
  static Color get darkMaroon => LumearColors.dark;
  static Color get muted => LumearColors.light;
  static Color get ink => LumearColors.ink;

  int imageIndex = 0;
  int quantity = 1;
  final Map<String, String> selectedVariants = {};
  bool get isFavorite => WishlistManager.instance.contains(product.id);
  bool isAdding = false;
  final _addButtonKey = GlobalKey();
  final _cartIconKey = GlobalKey();
  late final _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );
  OverlayEntry? _flyingProduct;
  OverlayEntry? _cartNotice;
  Timer? _noticeTimer;

  @override
  void dispose() {
    _flyingProduct?.remove();
    dismissCartNotice();
    _flight.dispose();
    super.dispose();
  }

  Future<void> flyToCart() async {
    final source = _addButtonKey.currentContext?.findRenderObject();
    final target = _cartIconKey.currentContext?.findRenderObject();
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject();
    if (MediaQuery.disableAnimationsOf(context) ||
        source is! RenderBox ||
        target is! RenderBox ||
        overlayBox is! RenderBox) {
      setState(() => isAdding = false);
      return;
    }
    final start = overlayBox.globalToLocal(
      source.localToGlobal(source.size.center(Offset.zero)),
    );
    final end = overlayBox.globalToLocal(
      target.localToGlobal(target.size.center(Offset.zero)),
    );
    final control = Offset(start.dx - 70, end.dy + (start.dy - end.dy) * .25);
    final image = product.gallery[imageIndex];
    _flyingProduct = OverlayEntry(
      builder: (_) => AnimatedBuilder(
        animation: _flight,
        builder: (_, _) {
          final t = Curves.easeInOutCubic.transform(_flight.value);
          final position =
              start * ((1 - t) * (1 - t)) +
              control * (2 * (1 - t) * t) +
              end * (t * t);
          final size = 64.0 - 48 * t;
          return Positioned(
            left: position.dx - size / 2,
            top: position.dy - size / 2,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: (1 - ((_flight.value - .85) / .15).clamp(0.0, 1.0)),
                  child: Transform.rotate(
                    angle: -.15 * math.sin(math.pi * t),
                    child: Material(
                      key: const ValueKey('flying-cart-product'),
                      elevation: 8 * (1 - t),
                      color: LumearColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      child: LumearImage(
                        image,
                        width: size,
                        height: size,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => SizedBox(
                          width: size,
                          height: size,
                          child: Icon(
                            product.icon,
                            size: size * .6,
                            color: maroon,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    overlay.insert(_flyingProduct!);
    try {
      await _flight.forward(from: 0).orCancel;
    } on TickerCanceled {
      // The route was closed during the flight.
    } finally {
      if (mounted) {
        _flyingProduct?.remove();
        _flyingProduct = null;
        setState(() => isAdding = false);
      }
    }
  }

  LumearProduct get product => ProductCatalog.instance.connected
      ? lumearProducts.where((p) => p.id == widget.product.id).firstOrNull ??
            widget.product
      : widget.product;

  int get availableStock {
    if (product.variants.isEmpty) return product.stock;
    int stock = product.stock;
    for (final variant in product.variants) {
      final selected = selectedVariants[variant.name];
      if (selected != null) {
        stock = stock < variant.stockFor(selected)
            ? stock
            : variant.stockFor(selected);
      } else {
        stock =
            stock <
                variant.options
                    .map(variant.stockFor)
                    .fold<int>(0, (a, b) => a + b)
            ? stock
            : variant.options
                  .map(variant.stockFor)
                  .fold<int>(0, (a, b) => a + b);
      }
    }
    return stock;
  }

  double get currentPrice {
    double price = product.price;
    for (final variant in product.variants) {
      final option = selectedVariants[variant.name];
      final variantPrice = option == null ? null : variant.priceFor(option);
      if (variantPrice != null) price = variantPrice;
    }
    return price;
  }

  String money(double value) => '₱${value.toStringAsFixed(2)}';

  void dismissCartNotice() {
    _noticeTimer?.cancel();
    _cartNotice?.remove();
    _cartNotice = null;
  }

  void showCartNotice(String message, {bool success = false}) {
    dismissCartNotice();
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight + 8;
    _cartNotice = OverlayEntry(
      builder: (_) => Positioned(
        top: top,
        left: 16,
        right: 16,
        child: SafeArea(
          top: false,
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Semantics(
                liveRegion: true,
                child: Material(
                  key: const ValueKey('cart-notice'),
                  elevation: 6,
                  color: darkMaroon,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                    child: Row(
                      children: [
                        Icon(
                          success
                              ? Icons.check_circle_rounded
                              : Icons.info_outline,
                          color: LumearColors.surface,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            message,
                            style: const TextStyle(
                              color: LumearColors.ivory,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (success)
                          TextButton(
                            onPressed: openCart,
                            style: TextButton.styleFrom(
                              foregroundColor: LumearColors.ivory,
                            ),
                            child: const Text('View cart'),
                          ),
                        IconButton(
                          onPressed: dismissCartNotice,
                          tooltip: 'Dismiss notification',
                          icon: const Icon(
                            Icons.close,
                            color: LumearColors.ivory,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_cartNotice!);
    _noticeTimer = Timer(const Duration(seconds: 4), dismissCartNotice);
  }

  void openCart() {
    dismissCartNotice();
    _flight.stop(canceled: true);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
  }

  Future<void> addToCart({bool buyNow = false}) async {
    if (isAdding) return;
    if (availableStock <= 0 || quantity > availableStock) {
      showCartNotice('The selected variant does not have enough stock.');
      return;
    }
    if (product.variants.any((v) => !selectedVariants.containsKey(v.name))) {
      showCartNotice('Please select all product variants first.');
      return;
    }

    setState(() => isAdding = true);
    try {
      await CartManager.instance.addToCart(
        productId: product.id,
        name: product.name,
        price: money(currentPrice),
        icon: product.icon,
        imageUrl: product.imageUrl,
        selectedVariants: Map<String, String>.from(selectedVariants),
        quantity: quantity,
      );
    } catch (e) {
      if (mounted) {
        setState(() => isAdding = false);
        showCartNotice(e.toString());
      }
      return;
    }
    if (!mounted) return;

    if (!buyNow) {
      flyToCart();
    } else {
      setState(() => isAdding = false);
    }

    if (!buyNow) showCartNotice('${product.name} added to cart', success: true);

    if (buyNow) {
      openCart();
    }
  }

  @override
  Widget build(BuildContext context) {
    LumearAppearance.watch(context);
    final gallery = product.gallery;
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: cream,
        elevation: 0,
        iconTheme: IconThemeData(color: darkMaroon),
        title: Text(
          'The finer details',
          style: TextStyle(
            color: darkMaroon,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            key: _cartIconKey,
            tooltip: 'Shopping cart',
            onPressed: openCart,
            icon: AnimatedBuilder(
              animation: _flight,
              builder: (_, child) => Transform.scale(
                scale:
                    1 +
                    .25 *
                        math.sin(
                          math.pi *
                              ((_flight.value - .72) / .28).clamp(0.0, 1.0),
                        ),
                child: child,
              ),
              child: ListenableBuilder(
                listenable: CartManager.instance,
                builder: (_, _) => Badge(
                  isLabelVisible: CartManager.instance.itemCount > 0,
                  label: Text('${CartManager.instance.itemCount}'),
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => runBuyerAction(
              context,
              () => WishlistManager.instance.toggle(product),
            ),
            icon: Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: isFavorite ? maroon : darkMaroon,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 18),
        children: [
          Container(
            color: LumearColors.field,
            height: MediaQuery.sizeOf(context).width.clamp(300, 460).toDouble(),
            child: Stack(
              children: [
                PageView.builder(
                  itemCount: gallery.length,
                  onPageChanged: (i) => setState(() => imageIndex = i),
                  itemBuilder: (_, i) => LumearImage(
                    gallery[i],
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Center(
                      child: Icon(product.icon, size: 90, color: muted),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: darkMaroon.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.photo_library_outlined,
                          color: LumearColors.ivory,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${imageIndex + 1} / ${gallery.length}',
                          style: const TextStyle(
                            color: LumearColors.ivory,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (product.isNew)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: _tag('NEW ARRIVAL', maroon),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.category.toUpperCase(),
                  style: TextStyle(
                    color: muted,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  product.name,
                  style: TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 4,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      money(currentPrice),
                      style: TextStyle(
                        color: maroon,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    if (product.originalPrice != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        money(product.originalPrice!),
                        style: TextStyle(
                          color: muted,
                          decoration: TextDecoration.lineThrough,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _tag('SALE', maroon),
                      if (product.originalPrice! > 0 &&
                          product.originalPrice! > currentPrice)
                        _tag(
                          '-${(((product.originalPrice! - currentPrice) / product.originalPrice!) * 100).round()}%',
                          LumearColors.maroon,
                        ),
                    ],
                  ],
                ),
                if (product.originalPrice != null &&
                    product.originalPrice! > currentPrice) ...[
                  const SizedBox(height: 5),
                  Text(
                    'You save ${money(product.originalPrice! - currentPrice)}',
                    style: TextStyle(
                      color: LumearColors.maroon,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 13),
                Wrap(
                  spacing: 14,
                  runSpacing: 12,
                  children: [
                    Text(
                      '★ ${product.rating.toStringAsFixed(1)}',
                      style: TextStyle(
                        color: maroon,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${product.reviewCount} reviews',
                      style: TextStyle(color: ink, fontSize: 12),
                    ),
                    Text(
                      '${product.soldCount} sold',
                      style: TextStyle(color: ink, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    Text(
                      availableStock > 0
                          ? '$availableStock available'
                          : 'Out of stock',
                      style: TextStyle(
                        color: maroon,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Cash on delivery',
                      style: TextStyle(color: ink, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _section(
            title: 'Choose your options',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.variants.isEmpty)
                  Text(
                    'No variants required for this product.',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                for (final variant in product.variants) ...[
                  Text(
                    variant.name,
                    style: TextStyle(
                      color: ink,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: variant.options.map((option) {
                      final selected = selectedVariants[variant.name] == option;
                      final stock = variant.stockFor(option);
                      final disabled = stock <= 0;
                      return ChoiceChip(
                        label: Text('$option${disabled ? ' · Sold out' : ''}'),
                        selected: selected,
                        onSelected: disabled
                            ? null
                            : (_) => setState(() {
                                selectedVariants[variant.name] = option;
                                quantity = 1;
                              }),
                        selectedColor: darkMaroon,
                        checkmarkColor: cream,
                        backgroundColor: LumearColors.surface,
                        labelStyle: TextStyle(
                          color: disabled
                              ? Colors.grey
                              : selected
                              ? cream
                              : ink,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: selected ? maroon : LumearColors.border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Text(
                      'Quantity',
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    _quantityButton(Icons.remove_rounded, () {
                      if (quantity > 1) setState(() => quantity--);
                    }),
                    SizedBox(
                      width: 42,
                      child: Center(
                        child: Text(
                          '$quantity',
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    _quantityButton(Icons.add_rounded, () {
                      if (quantity < availableStock) setState(() => quantity++);
                    }),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Maximum ${availableStock < 0 ? 0 : availableStock} unit(s) available for the current selection.',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
          _section(
            title: 'Product description',
            child: Text(
              product.description,
              style: TextStyle(color: ink, height: 1.6, fontSize: 13),
            ),
          ),
          _section(
            title: 'Questions about this product?',
            child: OutlinedButton.icon(
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Chat with seller'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    service: ChatService(
                      connected: ProductCatalog.instance.connected,
                    ),
                    product: product,
                  ),
                ),
              ),
            ),
          ),
          _section(
            title: 'Shop information',
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: LumearColors.field,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.storefront_rounded, color: maroon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.shopName,
                        style: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        ProductCatalog.instance.connected
                            ? 'Lumear seller'
                            : 'Preview shop profile',
                        style: TextStyle(color: muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SearchScreen(shopName: product.shopName),
                    ),
                  ),
                  child: const Text('Visit'),
                ),
              ],
            ),
          ),
          _section(
            title: 'Ratings & reviews',
            trailing: Text(
              '${product.rating.toStringAsFixed(1)} ★',
              style: TextStyle(color: maroon, fontWeight: FontWeight.bold),
            ),
            child: product.reviews.isEmpty
                ? Text(
                    'No reviews yet. Be the first to review this product after ordering.',
                    style: TextStyle(color: muted, fontSize: 12),
                  )
                : Column(
                    children: product.reviews
                        .map(
                          (review) => Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Color(0xFFF0E3DE)),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 17,
                                      backgroundColor: LumearColors.field,
                                      child: Text(
                                        review.reviewer.isNotEmpty
                                            ? review.reviewer[0]
                                            : '?',
                                        style: TextStyle(
                                          color: maroon,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            review.reviewer,
                                            style: TextStyle(
                                              color: ink,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            review.date,
                                            style: TextStyle(
                                              color: muted,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${review.rating.toStringAsFixed(1)} ★',
                                      style: TextStyle(
                                        color: LumearColors.maroon,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 9),
                                Text(
                                  review.comment,
                                  style: TextStyle(
                                    color: ink,
                                    height: 1.45,
                                    fontSize: 12,
                                  ),
                                ),
                                if (review.photoUrls.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 70,
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      children: review.photoUrls
                                          .map(
                                            (url) => Padding(
                                              padding: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: LumearImage(
                                                  url,
                                                  width: 70,
                                                  height: 70,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              children: [
                const SectionHeading(
                  'A few more good finds',
                  kicker: 'KEEP DISCOVERING',
                ),
                SizedBox(
                  height: 300,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: lumearProducts
                        .where((p) => p.id != product.id)
                        .length,
                    separatorBuilder: (_, _) => const SizedBox(width: 16),
                    itemBuilder: (_, i) => SizedBox(
                      width: 170,
                      child: ProductCard(
                        lumearProducts
                            .where((p) => p.id != product.id)
                            .toList()[i],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
          decoration: BoxDecoration(
            color: LumearColors.surface,
            boxShadow: [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, -3),
              ),
            ],
            border: Border(top: BorderSide(color: LumearColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: _addButtonKey,
                  onPressed: isAdding ? null : () => addToCart(),
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      isAdding
                          ? Icons.check_circle_rounded
                          : Icons.add_shopping_cart_rounded,
                      key: ValueKey(isAdding),
                      size: 18,
                    ),
                  ),
                  label: Text(isAdding ? 'Added!' : 'Add to Cart'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: maroon,
                    side: BorderSide(color: maroon),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: availableStock <= 0 || isAdding
                      ? null
                      : () => addToCart(buyNow: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LumearColors.action,
                    foregroundColor: LumearColors.ivory,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Buy Now',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: LumearColors.ivory,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _quantityButton(IconData icon, VoidCallback onPressed) => Material(
    color: LumearColors.field,
    borderRadius: BorderRadius.circular(9),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: LumearColors.border),
        ),
        child: Icon(icon, size: 18, color: maroon),
      ),
    ),
  );

  Widget _section({
    required String title,
    Widget? trailing,
    required Widget child,
  }) => Container(
    margin: const EdgeInsets.fromLTRB(18, 10, 18, 0),
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 19),
    decoration: BoxDecoration(
      color: LumearColors.field,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: darkMaroon,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 13),
        child,
      ],
    ),
  );
}
