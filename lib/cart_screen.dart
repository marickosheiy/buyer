import 'package:flutter/material.dart';

import 'cart_manager.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

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

      appBar: AppBar(
        backgroundColor: cream,
        elevation: 0,
        centerTitle: false,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: darkMaroon,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: const Text(
          'My Cart',
          style: TextStyle(
            color: darkMaroon,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),

      body: ValueListenableBuilder<List<CartItem>>(
        valueListenable: CartManager.instance.items,

        builder: (context, items, child) {
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 70,
                    color: lightMaroon,
                  ),

                  SizedBox(height: 16),

                  Text(
                    'Your cart is empty',
                    style: TextStyle(
                      color: darkText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 6),

                  Text(
                    'Add some products from the Home page.',
                    style: TextStyle(
                      color: lightMaroon,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    10,
                  ),

                  itemCount: items.length,

                  itemBuilder: (context, index) {
                    final item = items[index];

                    return buildCartItem(
                      context,
                      item,
                    );
                  },
                ),
              ),

              buildCheckoutSection(
                context,
                items,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget buildCartItem(
    BuildContext context,
    CartItem item,
  ) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFECDCD4),
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 75,
            height: 75,

            decoration: BoxDecoration(
              color: fieldColor,
              borderRadius: BorderRadius.circular(14),
            ),

            child: Icon(
              item.icon,
              color: lightMaroon,
              size: 38,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  item.name,

                  style: const TextStyle(
                    color: darkText,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  item.price,

                  style: const TextStyle(
                    color: maroon,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    buildQuantityButton(
                      icon: Icons.remove,
                      onPressed: () {
                        CartManager.instance
                            .decreaseQuantity(item);
                      },
                    ),

                    SizedBox(
                      width: 38,
                      child: Center(
                        child: Text(
                          item.quantity.toString(),

                          style: const TextStyle(
                            color: darkText,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    buildQuantityButton(
                      icon: Icons.add,
                      onPressed: () {
                        CartManager.instance
                            .increaseQuantity(item);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: () {
              CartManager.instance
                  .removeFromCart(item);
            },

            icon: const Icon(
              Icons.delete_outline_rounded,
              color: maroon,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildQuantityButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,

      borderRadius:
          BorderRadius.circular(8),

      child: Container(
        width: 30,
        height: 30,

        decoration: BoxDecoration(
          color: fieldColor,
          borderRadius:
              BorderRadius.circular(8),
        ),

        child: Icon(
          icon,
          color: maroon,
          size: 17,
        ),
      ),
    );
  }

  Widget buildCheckoutSection(
    BuildContext context,
    List<CartItem> items,
  ) {
    final total = calculateTotal(items);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        22,
      ),

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

        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  'Total',

                  style: TextStyle(
                    color: darkText,
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const Spacer(),

                Text(
                  '₱${total.toStringAsFixed(2)}',

                  style: const TextStyle(
                    color: maroon,
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              height: 52,

              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const CheckoutScreen(),
                    ),
                  );
                },

                style:
                    ElevatedButton.styleFrom(
                  backgroundColor: maroon,
                  foregroundColor: Colors.white,

                  elevation: 0,

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                ),

                child: const Text(
                  'Checkout',

                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double calculateTotal(
    List<CartItem> items,
  ) {
    double total = 0;

    for (final item in items) {
      final cleanPrice =
          item.price.replaceAll(
        RegExp(r'[^0-9.]'),
        '',
      );

      final price =
          double.tryParse(cleanPrice) ?? 0;

      total += price * item.quantity;
    }

    return total;
  }
}