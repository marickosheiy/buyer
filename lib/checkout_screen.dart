import 'package:flutter/material.dart';
import 'cart_manager.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const Color cream = Color(0xFFFFF8F4);
  static const Color maroon = Color(0xFF963B36);
  static const Color darkMaroon = Color(0xFF721E1E);
  static const Color lightMaroon = Color(0xFFC78F88);
  static const Color fieldColor = Color(0xFFF9EEEA);
  static const Color darkText = Color(0xFF4E3431);

  final TextEditingController nameController =
      TextEditingController();

  final TextEditingController phoneController =
      TextEditingController();

  final TextEditingController addressController =
      TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }

  double getItemPrice(CartItem item) {
    final cleanedPrice = item.price
        .replaceAll('₱', '')
        .replaceAll(',', '')
        .trim();

    return double.tryParse(cleanedPrice) ?? 0;
  }

  double get subtotal {
    return CartManager.instance.items.value.fold(
      0,
      (total, item) {
        return total +
            (getItemPrice(item) * item.quantity);
      },
    );
  }

  double get shippingFee {
    if (subtotal >= 1000) {
      return 0;
    }

    return 50;
  }

  double get total {
    return subtotal + shippingFee;
  }

  void placeOrder() {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final address = addressController.text.trim();

    if (name.isEmpty ||
        phone.isEmpty ||
        address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete your delivery information.',
          ),
          backgroundColor: darkMaroon,
        ),
      );

      return;
    }

    final cartItems = List<CartItem>.from(
      CartManager.instance.items.value,
    );

    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your cart is empty.',
          ),
          backgroundColor: darkMaroon,
        ),
      );

      return;
    }

    final orderNumber =
        'LUM-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: cream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 650,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // =================================================
                  // SUCCESS HEADER
                  // =================================================

                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          decoration:
                              const BoxDecoration(
                            color: Color(0xFFE9F6E8),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.green,
                            size: 38,
                          ),
                        ),

                        const SizedBox(height: 12),

                        const Text(
                          'Order Confirmed!',
                          style: TextStyle(
                            color: darkMaroon,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 5),

                        const Text(
                          'Thank you for shopping with Lumear',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: lightMaroon,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // =================================================
                  // RECEIPT HEADER
                  // =================================================

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFECDCD4),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'LUMEAR',
                          style: TextStyle(
                            color: maroon,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),

                        const SizedBox(height: 3),

                        const Text(
                          'OFFICIAL RECEIPT',
                          style: TextStyle(
                            color: lightMaroon,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),

                        const SizedBox(height: 14),

                        receiptInfoRow(
                          'Order No.',
                          orderNumber,
                        ),

                        const SizedBox(height: 6),

                        receiptInfoRow(
                          'Date',
                          _formatReceiptDate(
                            DateTime.now(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // =================================================
                  // DELIVERY INFORMATION
                  // =================================================

                  const Text(
                    'Delivery Information',
                    style: TextStyle(
                      color: darkMaroon,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: fieldColor,
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        receiptDetailRow(
                          Icons.person_outline_rounded,
                          name,
                        ),

                        const SizedBox(height: 8),

                        receiptDetailRow(
                          Icons.phone_outlined,
                          phone,
                        ),

                        const SizedBox(height: 8),

                        receiptDetailRow(
                          Icons.location_on_outlined,
                          address,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // =================================================
                  // ITEMS PURCHASED
                  // =================================================

                  const Text(
                    'Items Purchased',
                    style: TextStyle(
                      color: darkMaroon,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFECDCD4),
                      ),
                    ),
                    child: Column(
                      children: [
                        ...cartItems.map(
                          (item) {
                            final itemPrice =
                                getItemPrice(item);

                            final itemTotal =
                                itemPrice *
                                    item.quantity;

                            return Padding(
                              padding:
                                  const EdgeInsets.only(
                                bottom: 13,
                              ),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration:
                                        BoxDecoration(
                                      color: fieldColor,
                                      borderRadius:
                                          BorderRadius.circular(
                                        10,
                                      ),
                                    ),
                                    child: Icon(
                                      item.icon,
                                      color: maroon,
                                      size: 22,
                                    ),
                                  ),

                                  const SizedBox(
                                    width: 10,
                                  ),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                        Text(
                                          item.name,
                                          maxLines: 2,
                                          overflow:
                                              TextOverflow
                                                  .ellipsis,
                                          style:
                                              const TextStyle(
                                            color: darkText,
                                            fontSize: 13,
                                            fontWeight:
                                                FontWeight
                                                    .w600,
                                          ),
                                        ),

                                        const SizedBox(
                                          height: 3,
                                        ),

                                        Text(
                                          '₱${itemPrice.toStringAsFixed(2)} × ${item.quantity}',
                                          style:
                                              const TextStyle(
                                            color:
                                                lightMaroon,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(
                                    width: 8,
                                  ),

                                  Text(
                                    '₱${itemTotal.toStringAsFixed(2)}',
                                    style:
                                        const TextStyle(
                                      color: maroon,
                                      fontSize: 13,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        const Divider(
                          color: Color(0xFFECDCD4),
                        ),

                        const SizedBox(height: 8),

                        receiptAmountRow(
                          'Subtotal',
                          '₱${subtotal.toStringAsFixed(2)}',
                        ),

                        const SizedBox(height: 8),

                        receiptAmountRow(
                          'Shipping Fee',
                          shippingFee == 0
                              ? 'FREE'
                              : '₱${shippingFee.toStringAsFixed(2)}',
                        ),

                        const SizedBox(height: 10),

                        const Divider(
                          color: Color(0xFFECDCD4),
                        ),

                        const SizedBox(height: 10),

                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL',
                              style: TextStyle(
                                color: darkText,
                                fontSize: 16,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),

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
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // =================================================
                  // PAYMENT METHOD
                  // =================================================

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: fieldColor,
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration:
                              const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.payments_outlined,
                            color: maroon,
                            size: 22,
                          ),
                        ),

                        const SizedBox(width: 11),

                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment Method',
                                style: TextStyle(
                                  color: lightMaroon,
                                  fontSize: 10,
                                ),
                              ),

                              SizedBox(height: 3),

                              Text(
                                'Cash on Delivery',
                                style: TextStyle(
                                  color: darkText,
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                          size: 22,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // =================================================
                  // DONE BUTTON
                  // =================================================

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        CartManager.instance.clearCart();

                        Navigator.pop(dialogContext);

                        Navigator.pop(context);
                      },
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor: maroon,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        'DONE',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Center(
                    child: Text(
                      'Please keep this receipt for your records.',
                      style: TextStyle(
                        color: lightMaroon,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatReceiptDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final hour = date.hour > 12
        ? date.hour - 12
        : date.hour == 0
            ? 12
            : date.hour;

    final minute =
        date.minute.toString().padLeft(2, '0');

    final period =
        date.hour >= 12 ? 'PM' : 'AM';

    return '${months[date.month - 1]} '
        '${date.day}, ${date.year} • '
        '$hour:$minute $period';
  }

  Widget receiptInfoRow(
    String label,
    String value,
  ) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: lightMaroon,
            fontSize: 11,
          ),
        ),

        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: darkText,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget receiptDetailRow(
    IconData icon,
    String text,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: maroon,
          size: 18,
        ),

        const SizedBox(width: 9),

        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: darkText,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget receiptAmountRow(
    String label,
    String value,
  ) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),

        Text(
          value,
          style: const TextStyle(
            color: darkText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,

      appBar: AppBar(
        backgroundColor: cream,
        elevation: 0,
        centerTitle: true,

        title: const Text(
          'Checkout',
          style: TextStyle(
            color: darkMaroon,
            fontWeight: FontWeight.bold,
          ),
        ),

        iconTheme: const IconThemeData(
          color: darkMaroon,
        ),
      ),

      body: ValueListenableBuilder<List<CartItem>>(
        valueListenable:
            CartManager.instance.items,

        builder: (
          context,
          items,
          child,
        ) {
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    color: lightMaroon,
                    size: 70,
                  ),

                  SizedBox(height: 15),

                  Text(
                    'Your cart is empty.',
                    style: TextStyle(
                      color: darkText,
                      fontSize: 17,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView(
            physics:
                const BouncingScrollPhysics(),

            padding:
                const EdgeInsets.fromLTRB(
              18,
              10,
              18,
              30,
            ),

            children: [
              // ==================================================
              // DELIVERY ADDRESS
              // ==================================================

              sectionTitle(
                Icons.location_on_outlined,
                'Delivery Address',
              ),

              const SizedBox(height: 12),

              Container(
                padding:
                    const EdgeInsets.all(16),

                decoration:
                    BoxDecoration(
                  color: Colors.white,

                  borderRadius:
                      BorderRadius.circular(18),

                  border: Border.all(
                    color:
                        const Color(
                      0xFFECDCD4,
                    ),
                  ),
                ),

                child: Column(
                  children: [
                    TextField(
                      controller:
                          nameController,

                      decoration:
                          inputDecoration(
                        'Full Name',
                        Icons
                            .person_outline_rounded,
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    TextField(
                      controller:
                          phoneController,

                      keyboardType:
                          TextInputType.phone,

                      decoration:
                          inputDecoration(
                        'Phone Number',
                        Icons.phone_outlined,
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    TextField(
                      controller:
                          addressController,

                      maxLines: 3,

                      decoration:
                          inputDecoration(
                        'Complete Address',
                        Icons.home_outlined,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 25,
              ),

              // ==================================================
              // PAYMENT METHOD
              // ==================================================

              sectionTitle(
                Icons.payments_outlined,
                'Payment Method',
              ),

              const SizedBox(height: 12),

              Container(
                padding:
                    const EdgeInsets.all(16),

                decoration:
                    BoxDecoration(
                  color: Colors.white,

                  borderRadius:
                      BorderRadius.circular(18),

                  border: Border.all(
                    color:
                        const Color(
                      0xFFECDCD4,
                    ),
                  ),
                ),

                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,

                      decoration:
                          BoxDecoration(
                        color: fieldColor,

                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),

                      child: const Icon(
                        Icons.payments_outlined,
                        color: maroon,
                        size: 27,
                      ),
                    ),

                    const SizedBox(
                      width: 13,
                    ),

                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cash on Delivery',
                            style: TextStyle(
                              color: darkText,
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          SizedBox(
                            height: 4,
                          ),

                          Text(
                            'Pay when your order arrives',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Icon(
                      Icons.radio_button_checked,
                      color: maroon,
                      size: 24,
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 25,
              ),

              // ==================================================
              // ORDER SUMMARY
              // ==================================================

              sectionTitle(
                Icons.receipt_long_outlined,
                'Order Summary',
              ),

              const SizedBox(height: 12),

              Container(
                padding:
                    const EdgeInsets.all(16),

                decoration:
                    BoxDecoration(
                  color: Colors.white,

                  borderRadius:
                      BorderRadius.circular(18),

                  border: Border.all(
                    color:
                        const Color(
                      0xFFECDCD4,
                    ),
                  ),
                ),

                child: Column(
                  children: [
                    ...items.map(
                      (item) {
                        return Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                            bottom: 14,
                          ),

                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,

                                decoration:
                                    BoxDecoration(
                                  color:
                                      fieldColor,

                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    13,
                                  ),
                                ),

                                child: Icon(
                                  item.icon,
                                  color: maroon,
                                  size: 30,
                                ),
                              ),

                              const SizedBox(
                                width: 12,
                              ),

                              Expanded(
                                child:
                                    Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,

                                  children: [
                                    Text(
                                      item.name,

                                      maxLines:
                                          2,

                                      overflow:
                                          TextOverflow
                                              .ellipsis,

                                      style:
                                          const TextStyle(
                                        color:
                                            darkText,

                                        fontSize:
                                            14,

                                        fontWeight:
                                            FontWeight
                                                .w600,
                                      ),
                                    ),

                                    const SizedBox(
                                      height: 5,
                                    ),

                                    Text(
                                      'Qty: ${item.quantity}',

                                      style:
                                          const TextStyle(
                                        color:
                                            lightMaroon,

                                        fontSize:
                                            12,
                                      ),
                                    ),

                                    const SizedBox(
                                      height: 5,
                                    ),

                                    Text(
                                      item.price,

                                      style:
                                          const TextStyle(
                                        color:
                                            maroon,

                                        fontSize:
                                            13,

                                        fontWeight:
                                            FontWeight
                                                .bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const Divider(
                      color:
                          Color(0xFFECDCD4),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    summaryRow(
                      'Subtotal',
                      '₱${subtotal.toStringAsFixed(2)}',
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    summaryRow(
                      'Shipping Fee',
                      shippingFee == 0
                          ? 'FREE'
                          : '₱${shippingFee.toStringAsFixed(2)}',
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    const Divider(
                      color:
                          Color(0xFFECDCD4),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .spaceBetween,

                      children: [
                        const Text(
                          'Total',

                          style: TextStyle(
                            color: darkText,
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

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
                  ],
                ),
              ),

              const SizedBox(
                height: 25,
              ),

              // ==================================================
              // PLACE ORDER BUTTON
              // ==================================================

              SizedBox(
                height: 55,
                width: double.infinity,

                child: ElevatedButton(
                  onPressed: placeOrder,

                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor: maroon,
                    foregroundColor:
                        Colors.white,

                    elevation: 0,

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                    ),
                  ),

                  child: Text(
                    'PLACE ORDER • ₱${total.toStringAsFixed(2)}',

                    style:
                        const TextStyle(
                      fontSize: 14,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget sectionTitle(
    IconData icon,
    String title,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: maroon,
          size: 22,
        ),

        const SizedBox(
          width: 8,
        ),

        Text(
          title,

          style: const TextStyle(
            color: darkMaroon,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  InputDecoration inputDecoration(
    String hint,
    IconData icon,
  ) {
    return InputDecoration(
      hintText: hint,

      hintStyle: const TextStyle(
        color: lightMaroon,
        fontSize: 12,
      ),

      prefixIcon: Icon(
        icon,
        color: maroon,
        size: 20,
      ),

      filled: true,

      fillColor: fieldColor,

      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(13),

        borderSide: BorderSide.none,
      ),

      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
    );
  }

  Widget summaryRow(
    String title,
    String value,
  ) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,

      children: [
        Text(
          title,

          style: const TextStyle(
            color: Colors.grey,
            fontSize: 13,
          ),
        ),

        Text(
          value,

          style: const TextStyle(
            color: darkText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}