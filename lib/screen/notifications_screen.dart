import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  // =========================================================
  // LUMEAR COLORS
  // =========================================================

  static const Color cream = Color(0xFFFFF8F4);
  static const Color maroon = Color(0xFF963B36);
  static const Color darkMaroon = Color(0xFF721E1E);
  static const Color lightMaroon = Color(0xFFC78F88);
  static const Color fieldColor = Color(0xFFF9EEEA);
  static const Color darkText = Color(0xFF4E3431);

  @override
  Widget build(BuildContext context) {
    final notifications = [
      {
        'title': 'Your order is almost here!',
        'message':
            'Your Wireless Gaming Controller is out for delivery and will arrive soon.',
        'icon': Icons.local_shipping_rounded,
        'time': '10 min ago',
        'unread': true,
      },
      {
        'title': 'Order shipped',
        'message':
            'Your Baby Care Essentials Set has been shipped and is on its way.',
        'icon': Icons.inventory_2_rounded,
        'time': '1 hour ago',
        'unread': true,
      },
      {
        'title': 'Order confirmed',
        'message':
            'Your order has been confirmed. The seller is now preparing your items.',
        'icon': Icons.shopping_bag_rounded,
        'time': '3 hours ago',
        'unread': true,
      },
      {
        'title': 'Order delivered',
        'message':
            'Your Elegant Gold Jewelry Set has been successfully delivered.',
        'icon': Icons.check_circle_rounded,
        'time': 'Yesterday',
        'unread': false,
      },
      {
        'title': 'Payment successful',
        'message':
            'Your payment for Smart Fitness Watch was successfully processed.',
        'icon': Icons.payment_rounded,
        'time': 'Yesterday',
        'unread': false,
      },
      {
        'title': 'Order preparing',
        'message':
            'The seller is currently preparing your Premium Self-Care Set.',
        'icon': Icons.inventory_rounded,
        'time': '2 days ago',
        'unread': false,
      },
      {
        'title': 'Order shipped',
        'message':
            'Your Wireless Bluetooth Headphones have been shipped.',
        'icon': Icons.local_shipping_outlined,
        'time': '2 days ago',
        'unread': false,
      },
      {
        'title': 'Order delivered',
        'message':
            'Your Everyday Tote Bag has been delivered successfully.',
        'icon': Icons.check_circle_outline_rounded,
        'time': '3 days ago',
        'unread': false,
      },
    ];

    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
          children: [
            // =================================================
            // HEADER
            // =================================================

            const Text(
              'Notifications',
              style: TextStyle(
                color: darkMaroon,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Stay updated with your orders and purchases',
              style: TextStyle(
                color: lightMaroon,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 24),

            // =================================================
            // TODAY
            // =================================================

            const Text(
              'Today',
              style: TextStyle(
                color: darkText,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            buildNotificationCard(
              title: notifications[0]['title'] as String,
              message: notifications[0]['message'] as String,
              icon: notifications[0]['icon'] as IconData,
              time: notifications[0]['time'] as String,
              unread: notifications[0]['unread'] as bool,
            ),

            buildNotificationCard(
              title: notifications[1]['title'] as String,
              message: notifications[1]['message'] as String,
              icon: notifications[1]['icon'] as IconData,
              time: notifications[1]['time'] as String,
              unread: notifications[1]['unread'] as bool,
            ),

            buildNotificationCard(
              title: notifications[2]['title'] as String,
              message: notifications[2]['message'] as String,
              icon: notifications[2]['icon'] as IconData,
              time: notifications[2]['time'] as String,
              unread: notifications[2]['unread'] as bool,
            ),

            const SizedBox(height: 10),

            // =================================================
            // EARLIER
            // =================================================

            const Text(
              'Earlier',
              style: TextStyle(
                color: darkText,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            ...List.generate(
              notifications.length - 3,
              (index) {
                final notification = notifications[index + 3];

                return buildNotificationCard(
                  title: notification['title'] as String,
                  message: notification['message'] as String,
                  icon: notification['icon'] as IconData,
                  time: notification['time'] as String,
                  unread: notification['unread'] as bool,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // NOTIFICATION CARD
  // =========================================================

  Widget buildNotificationCard({
    required String title,
    required String message,
    required IconData icon,
    required String time,
    required bool unread,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: unread ? fieldColor : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFECDCD4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // NOTIFICATION ICON
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: unread ? maroon : fieldColor,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              color: unread ? Colors.white : maroon,
              size: 25,
            ),
          ),

          const SizedBox(width: 13),

          // NOTIFICATION DETAILS
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: darkText,
                          fontSize: 14,
                          fontWeight: unread
                              ? FontWeight.bold
                              : FontWeight.w600,
                        ),
                      ),
                    ),

                    if (unread)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: const BoxDecoration(
                          color: maroon,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 5),

                Text(
                  message,
                  style: const TextStyle(
                    color: lightMaroon,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),

                const SizedBox(height: 9),

                Text(
                  time,
                  style: const TextStyle(
                    color: lightMaroon,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}