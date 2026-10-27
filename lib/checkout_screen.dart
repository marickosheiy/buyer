import 'checkout_receipt_screen.dart';
import 'services/top_notification.dart';
import 'services/marketplace_policy.dart';
import 'design/lumear_theme.dart';
import 'design/lumear_image.dart';

import 'package:flutter/material.dart';

import 'address_book_screen.dart';
import 'address_manager.dart';
import 'cart_manager.dart';
import 'order_manager.dart';
import 'services/buyer_data.dart';
import 'services/api_service.dart';
import 'design/components.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static Color get cream => LumearColors.cream;
  static Color get maroon => LumearColors.maroon;
  static Color get darkMaroon => LumearColors.dark;
  static Color get muted => LumearColors.light;
  static Color get fieldColor => LumearColors.field;
  static Color get ink => LumearColors.ink;
  static Color get line => LumearColors.border;

  SavedAddress? selectedAddress;
  Map<String, dynamic>? quote;
  String? quoteError;
  bool reviewing = false;
  bool submitting = false;
  String checkoutKey = '';

  Future<void> reviewTotal() async {
    if (!BuyerData.instance.connected) return;
    final address = selectedAddress ?? AddressManager.instance.defaultAddress;
    if (address == null) return;
    setState(() {
      reviewing = true;
      quote = null;
      quoteError = null;
    });
    try {
      final result = await ApiService.post(
        '/checkout/quote',
        body: {'address_id': address.id, 'vouchers': []},
      );
      MarketplacePolicy.validateShippingQuote(
        Map<String, dynamic>.from(result),
      );
      if (mounted) {
        setState(() {
          quote = Map<String, dynamic>.from(result);
          checkoutKey = 'checkout-${DateTime.now().microsecondsSinceEpoch}';
        });
      }
    } catch (e) {
      if (mounted) setState(() => quoteError = e.toString());
    } finally {
      if (mounted) setState(() => reviewing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    selectedAddress = AddressManager.instance.defaultAddress;
    if (BuyerData.instance.connected) reviewTotal();
  }

  double get subtotal => CartManager.instance.totalPrice;
  double get shippingFee => BuyerData.instance.connected
      ? (quote?['stores'] as List? ?? []).fold<double>(
          0,
          (sum, g) => sum + (g['shipping'] as num) / 100,
        )
      : MarketplacePolicy.shippingPesos;
  double get total => BuyerData.instance.connected && quote != null
      ? (quote!['total'] as num) / 100
      : subtotal + shippingFee;

  String money(double value) => '₱${value.toStringAsFixed(2)}';

  Future<void> openAddressBook() async {
    final result = await Navigator.push<SavedAddress?>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddressBookScreen(selectedAddressId: selectedAddress?.id),
      ),
    );

    if (!mounted) return;
    setState(() {
      selectedAddress = result ?? AddressManager.instance.defaultAddress;
    });
    await reviewTotal();
  }

  Future<void> placeOrder() async {
    if (submitting || reviewing) return;
    final address = selectedAddress ?? AddressManager.instance.defaultAddress;
    final items = List<CartItem>.from(CartManager.instance.items);

    if (items.isEmpty) {
      showTopNotification(
        context,
        const SnackBar(content: Text('Your cart is empty.')),
      );
      return;
    }

    if (address == null) {
      showTopNotification(
        context,
        const SnackBar(
          content: Text('Please add and select a delivery address.'),
        ),
      );
      return;
    }

    final orderSubtotal = items.fold<double>(
      0,
      (sum, item) => sum + item.totalPrice,
    );
    final orderShipping = BuyerData.instance.connected
        ? shippingFee
        : MarketplacePolicy.shippingPesos;
    final orderTotal = orderSubtotal + orderShipping;
    final orderDate = DateTime.now();
    String orderNumber;
    if (BuyerData.instance.connected) {
      if (quote == null) {
        await reviewTotal();
        return;
      }
      setState(() => submitting = true);
      try {
        final result = await ApiService.post(
          '/checkout',
          body: {
            'address_id': address.id,
            'vouchers': [],
            'payment_method': 'COD',
            'note': '',
            'idempotency_key': checkoutKey,
            'expected_quote': quote,
          },
        );
        orderNumber =
            result['orders'].first['reference'] ?? result['orders'].first['id'];
        await BuyerData.instance.refresh();
        if (!mounted) return;
      } catch (e) {
        if (mounted) setState(() => quoteError = e.toString());
        return;
      } finally {
        if (mounted) setState(() => submitting = false);
      }
    } else {
      OrderManager.instance.addOrder(
        items: items,
        name: address.fullName,
        phone: address.phone,
        address: address.formattedAddress,
        paymentMethod: 'COD',
        subtotal: orderSubtotal,
        shippingFee: orderShipping,
        total: orderTotal,
      );
      orderNumber = OrderManager.instance.latestOrder!.orderId;
      CartManager.instance.clearCart();
    }

    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(
        builder: (_) => CheckoutReceiptScreen(
          orderNumber: orderNumber,
          orderDate: orderDate,
          address: address,
          orderSubtotal: orderSubtotal,
          orderShipping: orderShipping,
          orderTotal: orderTotal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    LumearAppearance.watch(context);
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: cream,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: darkMaroon),
        ),
        title: Text(
          'Checkout',
          style: TextStyle(
            color: darkMaroon,
            fontWeight: FontWeight.bold,
            fontFamily: 'CormorantGaramond',
            fontSize: 21,
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: CartManager.instance,
        builder: (context, _) {
          final items = CartManager.instance.items;

          return Column(
            children: [
              if (reviewing || submitting) const LinearProgressIndicator(),
              if (quoteError != null)
                MaterialBanner(
                  content: Text(quoteError!),
                  actions: [
                    TextButton(
                      onPressed: reviewTotal,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _pageIntro(items.length),
                      const SizedBox(height: 18),
                      _sectionHeading(
                        icon: Icons.location_on_outlined,
                        title: 'Delivery Address',
                        action: 'CHANGE',
                        onAction: openAddressBook,
                      ),
                      const SizedBox(height: 10),
                      _addressCard(),
                      const SizedBox(height: 22),
                      _sectionHeading(
                        icon: Icons.shopping_bag_outlined,
                        title: 'Products Ordered',
                      ),
                      const SizedBox(height: 10),
                      _productsCard(items),
                      const SizedBox(height: 22),
                      _sectionHeading(
                        icon: Icons.confirmation_number_outlined,
                        title: 'Vouchers',
                      ),
                      const SizedBox(height: 10),
                      _voucherCard(),
                      const SizedBox(height: 22),
                      _sectionHeading(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Payment Method',
                      ),
                      const SizedBox(height: 10),
                      _paymentCard(),
                      const SizedBox(height: 22),
                      _sectionHeading(
                        icon: Icons.receipt_long_outlined,
                        title: 'Order Summary',
                      ),
                      const SizedBox(height: 10),
                      _summaryCard(),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          'Please review your order details before placing your order.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _bottomPlaceOrder(items.isNotEmpty),
            ],
          );
        },
      ),
    );
  }

  Widget _pageIntro(int itemCount) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const PageHeading('Almost yours.', eyebrow: 'THE FINAL LITTLE DETAILS'),
      Row(
        children: [
          for (final step in ['01  Bag', '02  Delivery', '03  Confirm'])
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: maroon, width: 2)),
                ),
                child: Text(
                  step,
                  style: TextStyle(
                    color: darkMaroon,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 14),
      Text(
        '$itemCount items · Cash on delivery',
        style: TextStyle(fontSize: 12, color: ink),
      ),
    ],
  );

  Widget _sectionHeading({
    required IconData icon,
    required String title,
    String? action,
    VoidCallback? onAction,
  }) {
    return Row(
      children: [
        Icon(icon, color: maroon, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: darkMaroon,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              action,
              style: TextStyle(
                color: maroon,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _addressCard() {
    final address = selectedAddress ?? AddressManager.instance.defaultAddress;

    if (address == null) {
      return _whiteCard(
        child: InkWell(
          onTap: openAddressBook,
          borderRadius: BorderRadius.circular(15),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: fieldColor,
                child: Icon(Icons.add_location_alt_outlined, color: maroon),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add delivery address',
                      style: TextStyle(
                        color: darkMaroon,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Add your recipient details and full address.',
                      style: TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: muted),
            ],
          ),
        ),
      );
    }

    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_rounded, color: maroon, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 7,
                      runSpacing: 5,
                      children: [
                        Text(
                          address.fullName,
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: fieldColor,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            address.label,
                            style: TextStyle(
                              color: maroon,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      address.phone,
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      address.formattedAddress,
                      style: TextStyle(color: ink, fontSize: 12, height: 1.45),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit address',
                onPressed: openAddressBook,
                icon: Icon(Icons.edit_outlined, color: maroon, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: openAddressBook,
              style: OutlinedButton.styleFrom(
                foregroundColor: maroon,
                side: BorderSide(color: line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'CHANGE DELIVERY ADDRESS',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _productsCard(List<CartItem> items) {
    return _whiteCard(
      child: items.isEmpty
          ? Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: Text(
                  'Your cart is empty.',
                  style: TextStyle(color: muted),
                ),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) Divider(color: line, height: 22),
                  _productRow(items[i]),
                ],
                Divider(color: line, height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Items subtotal',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ),
                    Text(
                      money(subtotal),
                      style: TextStyle(
                        color: maroon,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _productRow(CartItem item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 76,
            height: 82,
            color: fieldColor,
            child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                ? LumearImage(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Icon(item.icon, color: muted, size: 32),
                  )
                : Icon(item.icon, color: muted, size: 32),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
              if (item.variantText.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  item.variantText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: muted, fontSize: 10),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                '${money(item.price)} × ${item.quantity}',
                style: TextStyle(color: muted, fontSize: 11),
              ),
              const SizedBox(height: 6),
              Text(
                money(item.totalPrice),
                style: TextStyle(
                  color: maroon,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _voucherCard() {
    return _whiteCard(
      child: InkWell(
        onTap: () {
          showTopNotification(
            context,
            const SnackBar(
              content: Text(
                'Voucher selection will be connected in a future update.',
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: fieldColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.local_offer_outlined, color: maroon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Apply a voucher',
                    style: TextStyle(
                      color: ink,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Choose an available discount or shipping voucher.',
                    style: TextStyle(color: muted, fontSize: 11, height: 1.4),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: muted),
          ],
        ),
      ),
    );
  }

  Widget _paymentCard() {
    return _whiteCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: fieldColor,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.payments_outlined, color: maroon, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cash on Delivery (COD)',
                  style: TextStyle(
                    color: ink,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Pay when your order arrives.',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded, color: maroon, size: 23),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    return _whiteCard(
      child: Column(
        children: [
          _summaryRow('Subtotal', money(subtotal)),
          const SizedBox(height: 13),
          _summaryRow(
            'Shipping fee',
            shippingFee == 0 ? 'FREE' : money(shippingFee),
            valueColor: shippingFee == 0 ? Colors.green.shade700 : ink,
          ),
          const SizedBox(height: 13),
          if (shippingFee == 0)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 13),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF5E9),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 17,
                  ),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'You unlocked free shipping!',
                      style: TextStyle(color: Color(0xFF367A3B), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          Divider(color: line, height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total Payment',
                  style: TextStyle(
                    color: darkMaroon,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                money(total),
                style: TextStyle(
                  color: maroon,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'CormorantGaramond',
                  fontSize: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Shipping is free for orders of ₱1,000 or more.',
              style: TextStyle(color: muted, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: muted, fontSize: 12)),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? ink,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _whiteCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: LumearColors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: line),
        boxShadow: [
          BoxShadow(
            color: darkMaroon.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _bottomPlaceOrder(bool enabled) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      decoration: BoxDecoration(
        color: LumearColors.surface,
        border: Border(top: BorderSide(color: line)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D651D32),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Payment',
                    style: TextStyle(color: muted, fontSize: 10),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    money(total),
                    style: TextStyle(
                      color: maroon,
                      fontWeight: FontWeight.bold,
                      fontSize: 19,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed:
                      enabled &&
                          !reviewing &&
                          !submitting &&
                          (!BuyerData.instance.connected || quote != null)
                      ? placeOrder
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LumearColors.action,
                    disabledBackgroundColor: muted,
                    foregroundColor: LumearColors.ivory,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: const Text(
                    'PLACE ORDER',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
