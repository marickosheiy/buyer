import '../design/lumear_theme.dart';

import 'package:flutter/material.dart';

import '../design/components.dart';
import '../services/wishlist_manager.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});
  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => Scaffold(
      appBar: AppBar(title: const Text('Saved for later')),
      body: ListenableBuilder(
        listenable: WishlistManager.instance,
        builder: (_, _) {
          final products = WishlistManager.instance.items;
          if (products.isEmpty) {
            return EmptyState(
              title: 'Keep your favorites close.',
              message: WishlistManager.instance.reload != null
                  ? 'Tap a heart on a product to save it to your account.'
                  : 'Tap a heart on a product to save it here.\nSaved items last for this app session.',
              icon: Icons.favorite_border,
            );
          }
          return LayoutBuilder(
            builder: (_, constraints) => GridView.builder(
              padding: const EdgeInsets.all(22),
              itemCount: products.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: (constraints.maxWidth / 180).floor().clamp(
                  2,
                  6,
                ),
                mainAxisExtent: 310,
                mainAxisSpacing: 24,
                crossAxisSpacing: 16,
              ),
              itemBuilder: (_, i) => ProductCard(products[i]),
            ),
          );
        },
      ),
    ),
  );
}
