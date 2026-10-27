import 'package:flutter/material.dart';

import 'address_manager.dart';
import 'design/lumear_theme.dart';

class CheckoutReceiptScreen extends StatelessWidget {
  const CheckoutReceiptScreen({
    super.key,
    required this.orderNumber,
    required this.orderDate,
    required this.address,
    required this.orderSubtotal,
    required this.orderShipping,
    required this.orderTotal,
  });

  final String orderNumber;
  final DateTime orderDate;
  final SavedAddress address;
  final double orderSubtotal, orderShipping, orderTotal;

  static Color get cream => LumearColors.cream;
  static Color get darkMaroon => LumearColors.dark;
  static Color get maroon => LumearColors.maroon;
  static Color get muted => LumearColors.light;
  static Color get ink => LumearColors.ink;
  static Color get line => LumearColors.border;
  String money(double value) => '₱${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => Scaffold(
      appBar: AppBar(title: const Text('Checkout receipt')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 66,
                          height: 66,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F5E9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.green,
                            size: 38,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Order Confirmed!',
                          style: TextStyle(
                            color: darkMaroon,
                            fontFamily: 'CormorantGaramond',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Thank you for shopping with Lumear.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _receiptCard(
                    title: 'ORDER DETAILS',
                    children: [
                      _receiptRow('Order number', orderNumber),
                      _receiptRow('Date', _formatDate(orderDate)),
                      _receiptRow('Payment', 'Cash on Delivery'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _receiptCard(
                    title: 'DELIVERY ADDRESS',
                    children: [
                      Text(
                        address.fullName,
                        style: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(address.phone, style: TextStyle(color: muted)),
                      const SizedBox(height: 4),
                      Text(
                        address.formattedAddress,
                        style: TextStyle(color: ink, height: 1.4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _receiptCard(
                    title: 'PAYMENT SUMMARY',
                    children: [
                      _receiptRow('Subtotal', money(orderSubtotal)),
                      _receiptRow(
                        'Shipping fee',
                        orderShipping == 0 ? 'FREE' : money(orderShipping),
                      ),
                      Divider(color: line, height: 22),
                      _receiptRow('TOTAL', money(orderTotal), isTotal: true),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LumearColors.action,
                        foregroundColor: LumearColors.ivory,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        'DONE',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Please keep your order details for reference.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _receiptCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: LumearColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: muted,
              fontSize: 10,
              letterSpacing: 1,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isTotal ? darkMaroon : muted,
                fontSize: isTotal ? 13 : 11,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: isTotal ? maroon : ink,
                fontSize: isTotal ? 16 : 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
