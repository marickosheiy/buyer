import '../services/top_notification.dart';
import '../design/lumear_theme.dart';

import 'package:flutter/material.dart';

import '../services/buyer_data.dart';

class VoucherScreen extends StatefulWidget {
  const VoucherScreen({super.key});

  @override
  State<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen> {
  static Color get cream => LumearColors.cream;
  static Color get dark => LumearColors.dark;
  static Color get muted => LumearColors.light;

  final Set<String> claimed = {};

  List<_VoucherData> get vouchers =>
      BuyerData.instance.connected ? [] : sampleVouchers;
  final sampleVouchers = [
    _VoucherData(
      id: 'SHIP50',
      title: 'FREE SHIPPING',
      subtitle: '₱50 off shipping fee',
      requirement: 'Min. spend ₱299',
      color: LumearColors.maroon,
    ),
    _VoucherData(
      id: 'SAVE10',
      title: '10% OFF',
      subtitle: 'Save 10% on your order',
      requirement: 'Min. spend ₱500 · Max discount ₱100',
      color: LumearColors.light,
    ),
    _VoucherData(
      id: 'SAVE100',
      title: '₱100 OFF',
      subtitle: 'Take ₱100 off your purchase',
      requirement: 'Min. spend ₱1,000',
      color: LumearColors.dark,
    ),
    _VoucherData(
      id: 'WELCOME',
      title: 'WELCOME DEAL',
      subtitle: '₱75 off your first order',
      requirement: 'Min. spend ₱399 · New buyers',
      color: LumearColors.maroon,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    LumearAppearance.watch(context);
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: cream,
        elevation: 0,
        iconTheme: IconThemeData(color: dark),
        title: Text(
          'Vouchers & Rewards',
          style: TextStyle(color: dark, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (BuyerData.instance.connected)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No vouchers are available at the moment.'),
            ),
          if (!BuyerData.instance.connected)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [LumearColors.brandMaroon, LumearColors.charcoal],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.confirmation_num_rounded,
                    color: LumearColors.ivory,
                    size: 38,
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'A little reward for you',
                          style: TextStyle(
                            color: LumearColors.ivory,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Collect sample vouchers. Discounts are not applied at checkout.',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Text(
            'AVAILABLE VOUCHERS',
            style: TextStyle(
              color: muted,
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          for (final voucher in vouchers)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: LumearColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: LumearColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 102,
                    height: 112,
                    decoration: BoxDecoration(
                      color: voucher.color,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(15),
                      ),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          voucher.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: LumearColors.ivory,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            voucher.subtitle,
                            style: TextStyle(
                              color: dark,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            voucher.requirement,
                            style: TextStyle(color: muted, fontSize: 10),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  claimed.contains(voucher.id)
                                      ? 'Claimed · Demo voucher'
                                      : 'Limited demo offer',
                                  style: TextStyle(color: muted, fontSize: 9),
                                ),
                              ),
                              SizedBox(
                                height: 31,
                                child: ElevatedButton(
                                  onPressed: claimed.contains(voucher.id)
                                      ? null
                                      : () {
                                          setState(
                                            () => claimed.add(voucher.id),
                                          );
                                          showTopNotification(
                                            context,
                                            SnackBar(
                                              content: Text(
                                                '${voucher.id} claimed for demo!',
                                              ),
                                            ),
                                          );
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: LumearColors.action,
                                    foregroundColor: LumearColors.ivory,
                                    disabledBackgroundColor: const Color(
                                      0xFFE8DAD5,
                                    ),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                  ),
                                  child: Text(
                                    claimed.contains(voucher.id)
                                        ? 'CLAIMED'
                                        : 'CLAIM',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Note: These are sample vouchers. They are not yet applied to checkout totals.',
            style: TextStyle(color: muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _VoucherData {
  final String id;
  final String title;
  final String subtitle;
  final String requirement;
  final Color color;
  const _VoucherData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.requirement,
    required this.color,
  });
}
