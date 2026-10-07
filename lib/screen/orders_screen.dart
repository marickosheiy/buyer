import 'package:flutter/material.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const Color cream = Color(0xFFFFF8F4);
  static const Color maroon = Color(0xFF963B36);
  static const Color darkMaroon = Color(0xFF721E1E);
  static const Color lightMaroon = Color(0xFFC78F88);
  static const Color fieldColor = Color(0xFFF9EEEA);
  static const Color darkText = Color(0xFF4E3431);

  int selectedTab = 0;

  final List<String> tabs = [
    'All',
    'To Pay',
    'To Ship',
    'In Transit',
    'Delivered',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: Column(
          children: [
            // =====================================================
            // HEADER
            // =====================================================

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'My Orders',
                      style: TextStyle(
                        color: darkMaroon,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.search_rounded,
                      color: darkMaroon,
                    ),
                  ),
                ],
              ),
            ),

            // =====================================================
            // ORDER TABS
            // =====================================================

            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: tabs.length,
                itemBuilder: (context, index) {
                  final isSelected = selectedTab == index;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedTab = index;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(
                        right: 8,
                        top: 5,
                        bottom: 5,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? maroon : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? maroon
                              : const Color(0xFFEAD7CE),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        tabs[index],
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : lightMaroon,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // =====================================================
            // ORDERS
            // =====================================================

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  25,
                ),
                children: [
                  if (selectedTab == 0 || selectedTab == 1)
                    buildOrderCard(
                      storeName: 'Lumear Fashion Store',
                      productName: 'Classic Shirt',
                      price: '₱499',
                      quantity: 1,
                      icon: Icons.checkroom_rounded,
                      status: 'Waiting for courier pickup',
                      statusIcon: Icons.payment_rounded,
                      statusColor: Colors.orange,
                      tracking: [
                        TrackingStep(
                          title: 'Order Placed',
                          description:
                              'Your order has been successfully placed.',
                          completed: true,
                        ),
                        TrackingStep(
                          title: 'Waiting for Courier Pickup',
                          description:
                              'Your order is waiting for courier pickup.',
                          completed: false,
                        ),
                      ],
                    ),

                  if (selectedTab == 0 || selectedTab == 2)
                    buildOrderCard(
                      storeName: 'GameHub Official Store',
                      productName: 'Gaming Controller',
                      price: '₱1,499',
                      quantity: 1,
                      icon: Icons.sports_esports_rounded,
                      status: 'In Transit',
                      statusIcon: Icons.inventory_2_outlined,
                      statusColor: maroon,
                      tracking: [
                        TrackingStep(
                          title: 'Order Confirmed',
                          description:
                              'The seller has confirmed your order.',
                          completed: true,
                        ),
                        TrackingStep(
                          title: 'Preparing Order',
                          description:
                              'The seller is preparing your package.',
                          completed: true,
                        ),
                        TrackingStep(
                          title: 'In Transit',
                          description:
                              'Your package is on the way.',
                          completed: false,
                        ),
                      ],
                    ),

                  if (selectedTab == 0 || selectedTab == 3)
                    buildOrderCard(
                      storeName: 'TechZone Philippines',
                      productName: 'Wireless Headset',
                      price: '₱899',
                      quantity: 1,
                      icon: Icons.headphones_rounded,
                      status: 'Arrived at Laguna Logistics Center',
                      statusIcon: Icons.location_on_rounded,
                      statusColor: maroon,
                      tracking: [
                        TrackingStep(
                          title: 'Picked Up by Courier',
                          description:
                              'The courier has picked up your package.',
                          completed: true,
                        ),
                        TrackingStep(
                          title: 'In Transit',
                          description:
                              'Your package is on the way.',
                          completed: true,
                        ),
                        TrackingStep(
                          title: 'Arrived at Logistics Center',
                          description:
                              'Your package arrived at Laguna Logistics Center.',
                          completed: true,
                        ),
                        TrackingStep(
                          title: 'Next Destination',
                          description:
                              'Waiting to be transferred to the next facility.',
                          completed: false,
                        ),
                      ],
                    ),

                  if (selectedTab == 0 || selectedTab == 3)
                    buildOrderCard(
                      storeName: 'BabyCare Shop',
                      productName: 'Baby Essentials',
                      price: '₱750',
                      quantity: 2,
                      icon: Icons.child_friendly_rounded,
                      status: 'Out for Delivery',
                      statusIcon: Icons.delivery_dining_rounded,
                      statusColor: maroon,
                      tracking: [
                        TrackingStep(
                          title: 'Order Shipped',
                          description:
                              'Your package has been shipped.',
                          completed: true,
                        ),
                        TrackingStep(
                          title: 'Arrived at Delivery Hub',
                          description:
                              'Your package arrived at your local delivery hub.',
                          completed: true,
                        ),
                        TrackingStep(
                          title: 'Out for Delivery',
                          description:
                              'Your package is with the delivery rider.',
                          completed: true,
                        ),
                      ],
                    ),

                  if (selectedTab == 0 || selectedTab == 4)
                    buildOrderCard(
                      storeName: 'Golden Gems',
                      productName: 'Gold Jewelry',
                      price: '₱1,299',
                      quantity: 1,
                      icon: Icons.diamond_outlined,
                      status: 'Delivered',
                      statusIcon: Icons.check_circle_rounded,
                      statusColor: Colors.green,
                      tracking: [
                        TrackingStep(
                          title: 'Order Shipped',
                          description:
                              'The seller shipped your package.',
                          completed: true,
                        ),
                        TrackingStep(
                          title: 'Out for Delivery',
                          description:
                              'Your package was assigned to a delivery rider.',
                          completed: true,
                        ),
                        TrackingStep(
                          title: 'Delivered',
                          description:
                              'Your package has been successfully delivered.',
                          completed: true,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================
  // ORDER CARD
  // ===========================================================

  Widget buildOrderCard({
    required String storeName,
    required String productName,
    required String price,
    required int quantity,
    required IconData icon,
    required String status,
    required IconData statusIcon,
    required Color statusColor,
    required List<TrackingStep> tracking,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
          // STORE + STATUS
          // =====================================================

          Row(
            children: [
              const Icon(
                Icons.storefront_rounded,
                color: maroon,
                size: 20,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  storeName,
                  style: const TextStyle(
                    color: darkText,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(
                statusIcon,
                color: statusColor,
                size: 18,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // =====================================================
          // PRODUCT
          // =====================================================

          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: fieldColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: lightMaroon,
                  size: 35,
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: const TextStyle(
                        color: darkText,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Quantity: $quantity',
                      style: const TextStyle(
                        color: lightMaroon,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      price,
                      style: const TextStyle(
                        color: maroon,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          const Divider(
            color: Color(0xFFEAD7CE),
          ),

          const SizedBox(height: 8),

          // =====================================================
          // CURRENT STATUS
          // =====================================================

          Row(
            children: [
              Icon(
                statusIcon,
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // =====================================================
          // TRACK ORDER BUTTON
          // =====================================================

          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton(
              onPressed: () {
                showTrackingBottomSheet(
                  context,
                  productName,
                  tracking,
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                  color: maroon,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Track Order',
                style: TextStyle(
                  color: maroon,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // TRACKING BOTTOM SHEET
  // ===========================================================

  void showTrackingBottomSheet(
    BuildContext context,
    String productName,
    List<TrackingStep> tracking,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              22,
              18,
              22,
              30,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HANDLE
                  Center(
                    child: Container(
                      width: 45,
                      height: 5,
                      decoration: BoxDecoration(
                        color: lightMaroon,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  Text(
                    'Track Order',
                    style: const TextStyle(
                      color: darkMaroon,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    productName,
                    style: const TextStyle(
                      color: lightMaroon,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // TRACKING STEPS
                  ...List.generate(
                    tracking.length,
                    (index) {
                      final step = tracking[index];
                      final isLast =
                          index == tracking.length - 1;

                      return buildTrackingStep(
                        step,
                        isLast,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================
  // TRACKING STEP
  // ===========================================================

  Widget buildTrackingStep(
    TrackingStep step,
    bool isLast,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: step.completed
                    ? maroon
                    : fieldColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                step.completed
                    ? Icons.check_rounded
                    : Icons.circle_outlined,
                color: step.completed
                    ? Colors.white
                    : lightMaroon,
                size: 17,
              ),
            ),

            if (!isLast)
              Container(
                width: 2,
                height: 55,
                color: step.completed
                    ? maroon
                    : const Color(0xFFEAD7CE),
              ),
          ],
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    color: step.completed
                        ? darkText
                        : lightMaroon,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  step.description,
                  style: const TextStyle(
                    color: lightMaroon,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================
// TRACKING MODEL
// =============================================================

class TrackingStep {
  final String title;
  final String description;
  final bool completed;

  TrackingStep({
    required this.title,
    required this.description,
    required this.completed,
  });
}