import 'package:flutter/material.dart';

import 'seller_commerce.dart';

class SellerStockAlertsScreen extends StatelessWidget {
  const SellerStockAlertsScreen({super.key, required this.commerce});
  final SellerCommerce commerce;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Stock notifications')),
    body: ListenableBuilder(
      listenable: commerce,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Restock products with 5 or fewer units. Out-of-stock and inactive listings are included.',
          ),
          const SizedBox(height: 16),
          if (commerce.lowStockProducts.isEmpty)
            const Text('No low-stock products. Your inventory is healthy.'),
          for (final product in commerce.lowStockProducts)
            Card(
              child: ListTile(
                leading: Icon(
                  product.stock == 0
                      ? Icons.inventory_2_outlined
                      : Icons.warning_amber_rounded,
                ),
                title: Text(product.name),
                subtitle: Text(
                  product.stock == 0
                      ? 'Out of stock'
                      : '${product.stock} left · Low stock',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, true),
              ),
            ),
        ],
      ),
    ),
  );
}
