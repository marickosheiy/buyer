import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedIndex = 0;

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
          children: [buildHome(), buildCart(), buildOrders(), buildProfile()],
        ),
      ),

      bottomNavigationBar: buildBottomNavigation(),
    );
  }

  // =========================================================
  // HOME
  // =========================================================

  Widget buildHome() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: fieldColor,
                ),
                child: const Icon(Icons.person_rounded, color: maroon),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back!',
                      style: TextStyle(color: lightMaroon, fontSize: 12),
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

              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: darkMaroon,
                  size: 27,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // SEARCH BAR
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEAD7CE)),
            ),
            child: const TextField(
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: TextStyle(color: lightMaroon, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: maroon),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // PROMO BANNER
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
                        style: TextStyle(color: Colors.white70, fontSize: 11),
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

          // CATEGORY HEADER
          buildSectionHeader('Categories', 'See all'),

          const SizedBox(height: 14),

          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                buildCategory(Icons.checkroom_rounded, 'Fashion'),
                buildCategory(Icons.devices_other_rounded, 'Electronics'),
                buildCategory(Icons.chair_alt_rounded, 'Home'),
                buildCategory(Icons.health_and_safety_outlined, 'Beauty'),
                buildCategory(Icons.sports_esports_rounded, 'Gaming'),
              ],
            ),
          ),

          const SizedBox(height: 25),

          buildSectionHeader('Featured Products', 'See all'),

          const SizedBox(height: 14),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.77,
            children: [
              buildProductCard(
                'Classic Shirt',
                '₱499',
                Icons.checkroom_rounded,
              ),
              buildProductCard(
                'Wireless Headset',
                '₱899',
                Icons.headphones_rounded,
              ),
              buildProductCard('Minimal Lamp', '₱650', Icons.light_rounded),
              buildProductCard('Smart Watch', '₱1,299', Icons.watch_rounded),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SECTION HEADER
  // =========================================================

  Widget buildSectionHeader(String title, String action) {
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
            style: const TextStyle(color: maroon, fontSize: 11),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // CATEGORY
  // =========================================================

  Widget buildCategory(IconData icon, String name) {
    return Container(
      width: 84,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: fieldColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: maroon, size: 28),
          ),

          const SizedBox(height: 8),

          Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: darkText, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // PRODUCT CARD
  // =========================================================

  Widget buildProductCard(String name, String price, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFECDCD4)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: fieldColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Icon(icon, size: 55, color: lightMaroon),
            ),
          ),

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
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // CART PAGE
  // =========================================================

  Widget buildCart() {
    return const Center(
      child: Text(
        'My Cart',
        style: TextStyle(
          color: darkMaroon,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // =========================================================
  // ORDERS PAGE
  // =========================================================

  Widget buildOrders() {
    return const Center(
      child: Text(
        'My Orders',
        style: TextStyle(
          color: darkMaroon,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // =========================================================
  // PROFILE PAGE
  // =========================================================

  Widget buildProfile() {
    return const Center(
      child: Text(
        'My Profile',
        style: TextStyle(
          color: darkMaroon,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // =========================================================
  // BOTTOM NAVIGATION
  // =========================================================

  Widget buildBottomNavigation() {
    return NavigationBar(
      height: 72,
      backgroundColor: Colors.white,

      indicatorColor: fieldColor,

      selectedIndex: selectedIndex,

      onDestinationSelected: (index) {
        setState(() {
          selectedIndex = index;
        });
      },

      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded, color: maroon),
          label: 'Home',
        ),

        NavigationDestination(
          icon: Icon(Icons.shopping_cart_outlined),
          selectedIcon: Icon(Icons.shopping_cart_rounded, color: maroon),
          label: 'Cart',
        ),

        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2_rounded, color: maroon),
          label: 'Orders',
        ),

        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded, color: maroon),
          label: 'Profile',
        ),
      ],
    );
  }
}
