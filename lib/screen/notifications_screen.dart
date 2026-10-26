import 'package:flutter/material.dart';

import '../services/buyer_data.dart';
import '../services/ui_action.dart';

import '../design/components.dart';
import '../design/lumear_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool unreadOnly = false;
  @override
  void initState() {
    super.initState();
    BuyerData.instance.addListener(changed);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    BuyerData.instance.removeListener(changed);
    super.dispose();
  }

  List<Map<String, dynamic>> get notifications => BuyerData.instance.connected
      ? [
          for (final n in BuyerData.instance.notifications)
            {
              'id': n['id'],
              'title': n['title'],
              'message': n['message'] ?? '',
              'icon': Icons.receipt_long_outlined,
              'time': DateTime.fromMillisecondsSinceEpoch(
                (n['date'] as num).toInt() * 1000,
              ).toLocal().toString().split('.').first,
              'unread': n['read'] != true,
            },
        ]
      : sampleNotifications;
  final sampleNotifications = [
    {
      'title': 'Your order is almost here!',
      'message': 'Your Wireless Gaming Controller is out for delivery and will arrive soon.',
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
      'message': 'Your order has been confirmed. The seller is now preparing your items.',
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
      'message': 'Your Wireless Bluetooth Headphones have been shipped.',
      'icon': Icons.local_shipping_outlined,
      'time': '2 days ago',
      'unread': false,
    },
    {
      'title': 'Order delivered',
      'message': 'Your Everyday Tote Bag has been delivered successfully.',
      'icon': Icons.check_circle_outline_rounded,
      'time': '3 days ago',
      'unread': false,
    },
  ];
  @override
  Widget build(BuildContext context) {
    LumearAppearance.watch(context);
    final visible = notifications
        .where((n) => !unreadOnly || n['unread'] == true)
        .toList();
    final unreadCount = notifications.where((n) => n['unread'] == true).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 26),
        children: [
          PageHeading(
            'A little heads-up.',
            eyebrow: 'YOUR UPDATES',
            subtitle: BuyerData.instance.connected
                ? 'Your latest updates · tap an update to mark it as read.'
                : 'Sample updates · tap an update to mark it as read.',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All updates'),
                selected: !unreadOnly,
                onSelected: (_) => setState(() => unreadOnly = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text('Unread ($unreadCount)'),
                selected: unreadOnly,
                onSelected: (_) => setState(() => unreadOnly = true),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: unreadCount == 0
                  ? null
                  : () {
                      if (BuyerData.instance.connected) {
                        runBuyerAction(
                          context,
                          () => BuyerData.instance.markNotification(null),
                        );
                        return;
                      }
                      setState(() {
                        for (final n in notifications) {
                          n['unread'] = false;
                        }
                      });
                    },
              child: const Text('Mark all as read'),
            ),
          ),
          if (visible.isEmpty)
            const EmptyState(
              title: 'All caught up.',
              message: 'There are no unread updates.',
              icon: Icons.mark_email_read_outlined,
            ),
          for (final n in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: n['unread'] == true
                    ? LumearColors.field
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    if (BuyerData.instance.connected) {
                      runBuyerAction(
                        context,
                        () => BuyerData.instance.markNotification(n['id']),
                      );
                    } else {
                      setState(() => n['unread'] = false);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          n['icon'] as IconData,
                          color: LumearColors.maroon,
                          size: 24,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                n['time'] as String,
                                style: TextStyle(
                                  color: LumearColors.maroon,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                n['title'] as String,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: n['unread'] == true
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                n['message'] as String,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (n['unread'] == true)
                          Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.circle,
                              size: 6,
                              color: LumearColors.maroon,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
