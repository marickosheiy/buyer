import 'services/top_notification.dart';
import 'design/lumear_theme.dart';
import 'design/lumear_image.dart';

import 'package:flutter/material.dart';

import 'services/ui_action.dart';

import 'cart_manager.dart';
import 'design/components.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  static Color get cream => LumearColors.cream;
  static Color get maroon => LumearColors.maroon;
  static Color get darkMaroon => LumearColors.dark;
  static Color get muted => LumearColors.light;
  static Color get fieldColor => LumearColors.field;
  static Color get darkText => LumearColors.ink;
  static Color get borderColor => LumearColors.border;

  String money(double value) => '₱${value.toStringAsFixed(2)}';

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
          tooltip: 'Go back',
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: darkMaroon),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Your shopping bag',
          style: TextStyle(
            color: darkMaroon,
            fontWeight: FontWeight.bold,
            fontFamily: 'CormorantGaramond',
            fontSize: 22,
          ),
        ),
        actions: [
          ListenableBuilder(
            listenable: CartManager.instance,
            builder: (context, _) => Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: fieldColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${CartManager.instance.itemCount} item${CartManager.instance.itemCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: darkMaroon,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: CartManager.instance,
        builder: (context, _) {
          final items = CartManager.instance.items;

          if (items.isEmpty) {
            return _emptyCart(context);
          }

          final total = CartManager.instance.totalPrice;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                  children: [
                    const PageHeading(
                      'Good choices, together.',
                      eyebrow: 'YOUR BAG',
                    ),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: LumearColors.field,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.local_shipping_outlined,
                            color: maroon,
                            size: 23,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Review your items before checking out.',
                              style: TextStyle(
                                color: darkText,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Your items',
                            style: TextStyle(
                              color: darkMaroon,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '${items.length} product${items.length == 1 ? '' : 's'}',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (var index = 0; index < items.length; index++)
                      _cartItem(context, items[index], index),
                  ],
                ),
              ),
              _checkoutPanel(context, total, items.length),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyCart(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                color: LumearColors.field,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shopping_bag_outlined, size: 56, color: muted),
            ),
            const SizedBox(height: 22),
            Text(
              'Your cart is waiting',
              style: TextStyle(
                color: darkMaroon,
                fontFamily: 'CormorantGaramond',
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Looks like you haven’t added anything yet. Find something lovely on the Home page.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.storefront_outlined, size: 18),
              label: const Text('Continue shopping'),
              style: ElevatedButton.styleFrom(
                backgroundColor: LumearColors.action,
                foregroundColor: LumearColors.ivory,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartItem(BuildContext context, CartItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: LumearColors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: darkMaroon.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Container(
              width: 88,
              height: 96,
              color: fieldColor,
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? LumearImage(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Icon(item.icon, color: muted, size: 38),
                    )
                  : Icon(item.icon, color: muted, size: 38),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: darkText,
                    fontSize: 14,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.variantText.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: fieldColor,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      item.variantText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 10),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  item.formattedPrice,
                  style: TextStyle(
                    color: maroon,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    _quantityButton(
                      icon: Icons.remove_rounded,
                      onTap: () => runBuyerAction(
                        context,
                        () => CartManager.instance.decreaseQuantity(index),
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      child: Center(
                        child: Text(
                          '${item.quantity}',
                          style: TextStyle(
                            color: darkText,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    _quantityButton(
                      icon: Icons.add_rounded,
                      onTap: () => runBuyerAction(
                        context,
                        () => CartManager.instance.increaseQuantity(index),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      money(item.totalPrice),
                      style: TextStyle(
                        color: darkMaroon,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip: 'Remove item',
            visualDensity: VisualDensity.compact,
            onPressed: () => _confirmRemove(context, index, item.name),
            icon: Icon(Icons.delete_outline_rounded, color: muted, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _quantityButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: fieldColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 29,
          height: 29,
          child: Icon(icon, color: maroon, size: 17),
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    int index,
    String itemName,
  ) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Remove item?',
          style: TextStyle(color: darkMaroon, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Remove "$itemName" from your cart?',
          style: TextStyle(color: darkText, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Keep item', style: TextStyle(color: muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: LumearColors.action,
              foregroundColor: LumearColors.ivory,
              elevation: 0,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (shouldRemove == true && context.mounted) {
      if (!await runBuyerAction(
        context,
        () => CartManager.instance.removeFromCart(index),
      )) {
        return;
      }
      if (context.mounted) {
        showTopNotification(
          context,
          const SnackBar(
            content: Text('Item removed from your cart.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _checkoutPanel(BuildContext context, double total, int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      decoration: BoxDecoration(
        color: LumearColors.surface,
        border: Border(top: BorderSide(color: borderColor)),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Subtotal',
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                ),
                Text(
                  money(total),
                  style: TextStyle(
                    color: darkMaroon,
                    fontFamily: 'CormorantGaramond',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Shipping and discounts are calculated at checkout.',
                style: TextStyle(color: muted, fontSize: 10),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: count == 0
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CheckoutScreen(),
                        ),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: LumearColors.action,
                  disabledBackgroundColor: muted,
                  foregroundColor: LumearColors.ivory,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 17),
                    const SizedBox(width: 8),
                    Text(
                      'Checkout ($count)',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
