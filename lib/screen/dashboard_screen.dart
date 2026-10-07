import 'package:flutter/material.dart';

import '../cart_manager.dart';
import '../cart_screen.dart';
import 'notifications_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedIndex = 0;

  // Key for the CART ICON at the top of the Dashboard.
  final GlobalKey cartKey = GlobalKey();

  static const Color cream = Color(0xFFFFF8F4);
  static const Color maroon = Color(0xFF963B36);
  static const Color darkMaroon = Color(0xFF721E1E);
  static const Color lightMaroon = Color(0xFFC78F88);
  static const Color fieldColor = Color(0xFFF9EEEA);
  static const Color darkText = Color(0xFF4E3431);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: IndexedStack(
          index: selectedIndex,
          children: [
            HomeScreen(
              cartKey: cartKey,
            ),
            const NotificationsScreen(),
            const OrdersScreen(),
            const ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: buildBottomNavigation(),
    );
  }

  // ===========================================================
  // BOTTOM NAVIGATION
  // ===========================================================

  Widget buildBottomNavigation() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFECDCD4),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              buildNavItem(
                Icons.home_rounded,
                Icons.home_outlined,
                'Home',
                0,
              ),
              buildNavItem(
                Icons.notifications_rounded,
                Icons.notifications_none_rounded,
                'Notifications',
                1,
              ),
              buildOrdersNavItem(),
              buildNavItem(
                Icons.person_rounded,
                Icons.person_outline_rounded,
                'Profile',
                3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildNavItem(
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
    int index,
  ) {
    final isSelected = selectedIndex == index;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        setState(() {
          selectedIndex = index;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? maroon : lightMaroon,
              size: 25,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? maroon : lightMaroon,
                fontSize: 10,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildOrdersNavItem() {
    final isSelected = selectedIndex == 2;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        setState(() {
          selectedIndex = 2;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected
                  ? Icons.receipt_long_rounded
                  : Icons.receipt_long_outlined,
              color: isSelected ? maroon : lightMaroon,
              size: 25,
            ),
            const SizedBox(height: 4),
            Text(
              'Orders',
              style: TextStyle(
                color: isSelected ? maroon : lightMaroon,
                fontSize: 10,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// HOME SCREEN
// ===========================================================

class HomeScreen extends StatefulWidget {
  final GlobalKey cartKey;

  const HomeScreen({
    super.key,
    required this.cartKey,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color cream = Color(0xFFFFF8F4);
  static const Color maroon = Color(0xFF963B36);
  static const Color darkMaroon = Color(0xFF721E1E);
  static const Color lightMaroon = Color(0xFFC78F88);
  static const Color fieldColor = Color(0xFFF9EEEA);
  static const Color darkText = Color(0xFF4E3431);

  // Keys for the actual product pictures.
  final GlobalKey shirtKey = GlobalKey();
  final GlobalKey headsetKey = GlobalKey();
  final GlobalKey babyKey = GlobalKey();
  final GlobalKey jewelryKey = GlobalKey();
  final GlobalKey controllerKey = GlobalKey();
  final GlobalKey organizerKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          22,
          20,
          22,
          30,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===================================================
            // HEADER
            // ===================================================

            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: fieldColor,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: maroon,
                  ),
                ),

                const SizedBox(width: 12),

                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back!',
                        style: TextStyle(
                          color: lightMaroon,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Lumear Buyer',
                        style: TextStyle(
                          color: darkMaroon,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // =================================================
                // TOP CART ICON
                // =================================================

                ValueListenableBuilder<List<CartItem>>(
                  valueListenable: CartManager.instance.items,
                  builder: (context, items, child) {
                    final totalItems = items.fold<int>(
                      0,
                      (total, item) => total + item.quantity,
                    );

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          key: widget.cartKey,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const CartScreen(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.shopping_cart_outlined,
                            color: darkMaroon,
                            size: 27,
                          ),
                        ),

                        if (totalItems > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: 19,
                                minHeight: 19,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              decoration: const BoxDecoration(
                                color: maroon,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  totalItems > 99
                                      ? '99+'
                                      : totalItems.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ===================================================
            // SEARCH BAR
            // ===================================================

            Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFEAD7CE),
                ),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  hintStyle: TextStyle(
                    color: lightMaroon,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: maroon,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 16,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ===================================================
            // PROMO BANNER
            // ===================================================

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: darkMaroon,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good Finds,\nBrighter Days.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            height: 1.2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Discover products made for you.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 78,
                    height: 78,
                    decoration: const BoxDecoration(
                      color: Colors.white12,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shopping_bag_outlined,
                      size: 38,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ===================================================
            // CATEGORIES
            // ===================================================

            buildSectionHeader(
              'Categories',
              'See all',
            ),

            const SizedBox(height: 14),

            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  buildCategory(
                    'https://images.unsplash.com/photo-1445205170230-053b83016050',
                    'Fashion',
                  ),
                  buildCategory(
                    'https://images.unsplash.com/photo-1496181133206-80ce9b88a853',
                    'Electronics',
                  ),
                  buildCategory(
                    'https://images.unsplash.com/photo-1519689680058-324335c77eba',
                    'Baby',
                  ),
                  buildCategory(
                    'https://images.unsplash.com/photo-1596462502278-27bfdc403348',
                    'Beauty',
                  ),
                  buildCategory(
                    'https://images.unsplash.com/photo-1600080972464-8e5f35f63d08',
                    'Gaming',
                  ),
                  buildCategory(
                    'https://images.unsplash.com/photo-1555041469-a586c61ea9bc',
                    'Home',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // ===================================================
            // FEATURED PRODUCTS
            // ===================================================

            buildSectionHeader(
              'Featured Products',
              'See all',
            ),

            const SizedBox(height: 14),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.65,
              children: [
                buildProductCard(
                  context,
                  'Classic Shirt',
                  '₱499',
                  'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab',
                  shirtKey,
                ),

                buildProductCard(
                  context,
                  'Wireless Headset',
                  '₱899',
                  'https://images.unsplash.com/photo-1505740420928-5e560c06d30e',
                  headsetKey,
                ),

                buildProductCard(
                  context,
                  'Baby Essentials',
                  '₱750',
                  'https://images.unsplash.com/photo-1519689680058-324335c77eba',
                  babyKey,
                ),

                buildProductCard(
                  context,
                  'Gold Jewelry',
                  '₱1,299',
                  'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338',
                  jewelryKey,
                ),

                buildProductCard(
                  context,
                  'Gaming Controller',
                  '₱1,499',
                  'https://images.unsplash.com/photo-1600080972464-8e5f35f63d08',
                  controllerKey,
                ),

                buildProductCard(
                  context,
                  'Home Organizer',
                  '₱650',
                  'https://images.unsplash.com/photo-1555041469-a586c61ea9bc',
                  organizerKey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================
  // SECTION HEADER
  // ===========================================================

  Widget buildSectionHeader(
    String title,
    String action,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: darkMaroon,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        TextButton(
          onPressed: () {},
          child: Text(
            action,
            style: const TextStyle(
              color: maroon,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================
  // CATEGORY
  // ===========================================================

  Widget buildCategory(
    String imageUrl,
    String name,
  ) {
    return Container(
      width: 84,
      margin: const EdgeInsets.only(
        right: 12,
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: fieldColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                imageUrl,
                width: 62,
                height: 62,
                fit: BoxFit.cover,
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return const Icon(
                    Icons.image_outlined,
                    color: maroon,
                    size: 28,
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: darkText,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // PRODUCT CARD
  // ===========================================================

  Widget buildProductCard(
    BuildContext context,
    String name,
    String price,
    String imageUrl,
    GlobalKey imageKey,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFECDCD4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =====================================================
          // PRODUCT IMAGE
          // =====================================================

          Expanded(
            child: Container(
              key: imageKey,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: fieldColor,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (
                    context,
                    child,
                    loadingProgress,
                  ) {
                    if (loadingProgress == null) {
                      return child;
                    }

                    return const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: maroon,
                      ),
                    );
                  },
                  errorBuilder: (
                    context,
                    error,
                    stackTrace,
                  ) {
                    return const Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: 55,
                        color: lightMaroon,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // =====================================================
          // PRODUCT DETAILS
          // =====================================================

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: darkText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  price,
                  style: const TextStyle(
                    color: maroon,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // ADD TO CART
                      CartManager.instance.addToCart(
                        name: name,
                        price: price,
                        icon: Icons.shopping_bag_outlined,
                      );

                      // TOP NOTIFICATION
                      showTopCartNotification(
                        context,
                        name,
                      );

                      // FLY PRODUCT PICTURE TO CART
                      animateProductToCart(
                        context,
                        imageUrl,
                        imageKey,
                      );
                    },
                    icon: const Icon(
                      Icons.add_shopping_cart_rounded,
                      size: 16,
                    ),
                    label: const Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: maroon,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // TOP NOTIFICATION
  // ===========================================================

  void showTopCartNotification(
    BuildContext context,
    String productName,
  ) {
    final overlay = Overlay.of(context);

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (overlayContext) {
        return Positioned(
          top: MediaQuery.of(overlayContext).padding.top + 10,
          left: 18,
          right: 18,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: -80,
              end: 0,
            ),
            duration: const Duration(
              milliseconds: 350,
            ),
            curve: Curves.easeOutCubic,
            builder: (
              context,
              value,
              child,
            ) {
              return Transform.translate(
                offset: Offset(0, value),
                child: child,
              );
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFECDCD4),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 14,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 35,
                      height: 35,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE9F6E8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.green,
                        size: 21,
                      ),
                    ),

                    const SizedBox(width: 11),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Added to Cart',
                            style: TextStyle(
                              color: darkMaroon,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 2),

                          Text(
                            productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: lightMaroon,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Icon(
                      Icons.shopping_cart_outlined,
                      color: maroon,
                      size: 21,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);

    Future.delayed(
      const Duration(milliseconds: 2200),
      () {
        if (entry.mounted) {
          entry.remove();
        }
      },
    );
  }

  // ===========================================================
  // FLY PRODUCT PICTURE TO TOP CART
  // ===========================================================

  void animateProductToCart(
    BuildContext context,
    String imageUrl,
    GlobalKey imageKey,
  ) {
    final overlay = Overlay.of(context);

    final sourceRenderBox =
        imageKey.currentContext?.findRenderObject()
            as RenderBox?;

    final cartRenderBox =
        widget.cartKey.currentContext?.findRenderObject()
            as RenderBox?;

    if (sourceRenderBox == null ||
        cartRenderBox == null) {
      return;
    }

    final sourcePosition =
        sourceRenderBox.localToGlobal(
      Offset.zero,
    );

    final cartPosition =
        cartRenderBox.localToGlobal(
      Offset.zero,
    );

    final sourceSize = sourceRenderBox.size;
    final cartSize = cartRenderBox.size;

    final startCenter = Offset(
      sourcePosition.dx +
          sourceSize.width / 2,
      sourcePosition.dy +
          sourceSize.height / 2,
    );

    final endCenter = Offset(
      cartPosition.dx +
          cartSize.width / 2,
      cartPosition.dy +
          cartSize.height / 2,
    );

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (overlayContext) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(
            begin: 0,
            end: 1,
          ),
          duration: const Duration(
            milliseconds: 700,
          ),
          curve: Curves.easeInOutCubic,
          onEnd: () {
            if (entry.mounted) {
              entry.remove();
            }
          },
          builder: (
            context,
            progress,
            child,
          ) {
            // =================================================
            // CURVED PATH
            // =================================================

            final controlPoint = Offset(
              (startCenter.dx + endCenter.dx) / 2,
              startCenter.dy - 120,
            );

            final x =
                ((1 - progress) *
                        (1 - progress) *
                        startCenter.dx) +
                    (2 *
                        (1 - progress) *
                        progress *
                        controlPoint.dx) +
                    (progress *
                        progress *
                        endCenter.dx);

            final y =
                ((1 - progress) *
                        (1 - progress) *
                        startCenter.dy) +
                    (2 *
                        (1 - progress) *
                        progress *
                        controlPoint.dy) +
                    (progress *
                        progress *
                        endCenter.dy);

            // Shrinks while flying toward cart.
            final scale =
                1.0 - (progress * 0.72);

            return Positioned(
              left: x - 38,
              top: y - 38,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFECDCD4),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 12,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(16),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (
                        context,
                        error,
                        stackTrace,
                      ) {
                        return const Icon(
                          Icons.shopping_bag_outlined,
                          color: maroon,
                          size: 30,
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    overlay.insert(entry);
  }
}