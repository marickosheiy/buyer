import 'package:flutter/material.dart';

import '../services/buyer_data.dart';

import '../cart_manager.dart';
import '../cart_screen.dart';
import '../design/components.dart';
import '../design/brand_art.dart';
import '../design/lumear_image.dart';
import '../design/lumear_theme.dart';
import '../product_model.dart';
import '../search_screen.dart';
import '../services/wishlist_manager.dart';
import '../widgets/banner_carousel.dart';
import 'chat_screen.dart';
import 'notifications_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'voucher_screen.dart';
import 'wishlist_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.connected = false});
  final bool connected;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedIndex = 0;
  @override
  void initState() {
    super.initState();
    if (widget.connected) {
      BuyerData.instance.connect();
      refreshData();
    }
  }

  Future<void> refreshData() async {
    try {
      await BuyerData.instance.refresh();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => ListenableBuilder(
      listenable: BuyerData.instance,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              if (widget.connected && BuyerData.instance.loading)
                const LinearProgressIndicator(),
              if (widget.connected && BuyerData.instance.error != null)
                MaterialBanner(
                  content: Text(BuyerData.instance.error!),
                  actions: [
                    TextButton(
                      onPressed: refreshData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              Expanded(
                child: IndexedStack(
                  index: selectedIndex,
                  children: const [
                    HomeScreen(),
                    SearchScreen(embedded: true),
                    OrdersScreen(),
                    ProfileScreen(),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'buyer-chat',
          tooltip: 'Open chat',
          backgroundColor: LumearColors.action,
          foregroundColor: LumearColors.onAction,
          shape: const StadiumBorder(),
          elevation: 3,
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          label: const Text('Chat'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatInboxScreen(connected: widget.connected),
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: LumearDock(
          selectedIndex: selectedIndex,
          onSelected: (i) => setState(() {
            selectedIndex = i;
          }),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Browse',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Orders',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Me',
            ),
          ],
        ),
      ),
    ),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  void _browse(BuildContext context, [String category = 'All']) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SearchScreen(initialCategory: category),
        ),
      );
  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => ListenableBuilder(
      listenable: ProductCatalog.instance,
      builder: (context, _) => _content(context),
    ),
  );
  Widget _content(BuildContext context) {
    final featured = lumearProducts.where((p) => p.isFeatured).toList();
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            sliver: SliverList.list(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 6),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        width: 53,
                        height: 48,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LUMEAR',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                                letterSpacing: 2,
                                color: LumearColors.dark,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Find your kind of everyday.',
                              style: TextStyle(
                                fontSize: 9,
                                color: LumearColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const AppearanceButton(),
                      IconButton(
                        tooltip: 'Notifications',
                        style: IconButton.styleFrom(
                          minimumSize: const Size(40, 48),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        ),
                        icon: Badge(
                          isLabelVisible: BuyerData.instance.notifications.any(
                            (n) => n['read'] == false,
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            size: 21,
                          ),
                        ),
                      ),
                      ListenableBuilder(
                        listenable: CartManager.instance,
                        builder: (_, _) => IconButton(
                          tooltip: 'Shopping bag',
                          style: IconButton.styleFrom(
                            minimumSize: const Size(40, 48),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CartScreen(),
                            ),
                          ),
                          icon: Badge(
                            isLabelVisible: CartManager.instance.itemCount > 0,
                            label: Text('${CartManager.instance.itemCount}'),
                            child: const Icon(
                              Icons.shopping_bag_outlined,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: LumearColors.field,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () => _browse(context),
                    child: Padding(
                      padding: EdgeInsets.all(15),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            color: LumearColors.maroon,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Find your next favorite',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(Icons.tune, size: 18, color: LumearColors.dark),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(child: RuledLabel('GOOD FINDS. GOOD ENERGY.')),
                    Text(
                      'THE DAILY EDIT',
                      style: TextStyle(
                        fontSize: 8,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700,
                        color: LumearColors.dark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const BannerCarousel(),
                const _ShoppingSummary(),
                const SizedBox(height: 12),
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final category
                          in (ProductCatalog.instance.connected
                              ? [
                                  'All finds',
                                  ...lumearProducts
                                      .map((p) => p.category)
                                      .toSet(),
                                ]
                              : const [
                                  'All finds',
                                  'Fashion',
                                  'Electronics',
                                  'Beauty',
                                  'Home',
                                  'Jewelry',
                                  'Gaming',
                                  'Baby',
                                ]))
                        Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: ActionChip(
                            onPressed: () => _browse(
                              context,
                              category == 'All finds' ? 'All' : category,
                            ),
                            backgroundColor: category == 'All finds'
                                ? LumearColors.dark
                                : LumearColors.field,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                            label: Text(
                              category,
                              style: TextStyle(
                                color: category == 'All finds'
                                    ? LumearColors.cream
                                    : LumearColors.dark,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SectionHeading(
                  'Currently catching eyes',
                  kicker: 'THE FAVORITES',
                  onTap: () => _browse(context),
                ),
                SizedBox(
                  height: 310,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: featured.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) =>
                        SizedBox(width: 175, child: ProductCard(featured[i])),
                  ),
                ),
                const SectionHeading(
                  'Pick your mood.',
                  kicker: 'A DIFFERENT KIND OF DISCOVERY',
                ),
                if (lumearProducts.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _MoodTile(
                          product: lumearProducts[0],
                          title: 'WEAR\nYOUR MOOD.',
                          category: lumearProducts[0].category,
                          height: 232,
                          onTap: () =>
                              _browse(context, lumearProducts[0].category),
                        ),
                      ),
                      if (lumearProducts.length > 1) const SizedBox(width: 12),
                      if (lumearProducts.length > 1)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 28),
                            child: _MoodTile(
                              product: lumearProducts[1],
                              title: 'SWITCH\nIT UP.',
                              category: lumearProducts[1].category,
                              height: 232,
                              onTap: () =>
                                  _browse(context, lumearProducts[1].category),
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 22),
                Material(
                  color: LumearColors.light,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const VoucherScreen()),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 20,
                      ),
                      child: Row(
                        children: [
                          Transform.rotate(
                            angle: -.15,
                            child: const Burst(
                              label: 'A LITTLE\nEXTRA',
                              size: 73,
                            ),
                          ),
                          const SizedBox(width: 17),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'GOOD FINDS.\nEXTRA DELIGHT.',
                                  style: TextStyle(
                                    color: LumearColors.dark,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Open your voucher collection',
                                  style: TextStyle(
                                    color: LumearColors.dark,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.north_east, color: LumearColors.dark),
                        ],
                      ),
                    ),
                  ),
                ),
                SectionHeading(
                  'Fresh things, fresh feeling.',
                  kicker: 'NEW TO LUMEAR',
                  onTap: () => _browse(context),
                ),
                SizedBox(
                  height: 310,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: lumearProducts.where((p) => p.isNew).length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => SizedBox(
                      width: 175,
                      child: ProductCard(
                        lumearProducts.where((p) => p.isNew).toList()[i],
                      ),
                    ),
                  ),
                ),
                const SectionHeading(
                  'Your next good find.',
                  kicker: 'GO ON. HAVE A LOOK AROUND.',
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            sliver: SliverLayoutBuilder(
              builder: (_, constraints) => SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: (constraints.crossAxisExtent / 170)
                      .floor()
                      .clamp(2, 6),
                  mainAxisExtent: 328,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 12,
                ),
                itemCount: lumearProducts.length,
                itemBuilder: (_, i) => ProductCard(lumearProducts[i]),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(18, 26, 18, 18),
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: LumearColors.brandMaroon,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Icon(Icons.auto_awesome, color: LumearColors.ivory, size: 29),
                  SizedBox(height: 12),
                  Text(
                    'A LITTLE YOU.\nA LOT TO LOVE.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: LumearColors.ivory,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: 14),
                  Text(
                    'LUMEAR · Cash on delivery',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: LumearColors.ivory, fontSize: 9),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodTile extends StatelessWidget {
  const _MoodTile({
    required this.product,
    required this.title,
    required this.category,
    required this.height,
    required this.onTap,
  });
  final LumearProduct product;
  final String title, category;
  final double height;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => Material(
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      color: LumearColors.dark,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              LumearImage(product.imageUrl, fit: BoxFit.cover),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, LumearColors.dark],
                    stops: [.2, 1],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 12,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.toUpperCase(),
                      style: TextStyle(
                        color: LumearColors.cream,
                        fontSize: 8,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      title,
                      style: TextStyle(
                        color: LumearColors.cream,
                        fontSize: 24,
                        height: .98,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Icon(
                      Icons.arrow_forward,
                      color: LumearColors.cream,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ShoppingSummary extends StatelessWidget {
  const _ShoppingSummary();

  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => ListenableBuilder(
      listenable: Listenable.merge([
        CartManager.instance,
        WishlistManager.instance,
      ]),
      builder: (context, _) => Card(
        margin: const EdgeInsets.symmetric(vertical: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your shopping, at a glance',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pick up where you left off.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.shopping_bag_outlined, size: 18),
                    label: Text('Bag (${CartManager.instance.itemCount})'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.favorite_border, size: 18),
                    label: Text(
                      'Saved (${WishlistManager.instance.items.length})',
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WishlistScreen()),
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(
                      Icons.confirmation_number_outlined,
                      size: 18,
                    ),
                    label: const Text('My vouchers'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const VoucherScreen()),
                    ),
                  ),
                ],
              ),
              if (CartManager.instance.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Bag subtotal: ${CartManager.instance.formattedTotalPrice}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: LumearColors.dark,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
