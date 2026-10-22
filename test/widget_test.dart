import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/cart_manager.dart';
import 'package:flutter_application_1/design/lumear_theme.dart';
import 'package:flutter_application_1/product_model.dart';
import 'package:flutter_application_1/screen/product_detail_screen.dart';

void main() {
  testWidgets('Product details require variants before adding to cart', (
    tester,
  ) async {
    CartManager.instance.clearCart();
    addTearDown(CartManager.instance.clearCart);
    final product = lumearProducts.first;
    await tester.pumpWidget(
      MaterialApp(
        theme: lumearTheme(),
        home: ProductDetailScreen(product: product),
      ),
    );
    await tester.pumpAndSettle();
    final details = find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text(product.name),
      200,
      scrollable: details,
    );
    expect(find.text(product.name), findsOneWidget);

    await tester.tap(find.text('Add to Cart'));
    await tester.pumpAndSettle();
    expect(CartManager.instance.items, isEmpty);
    expect(
      find.text('Please select all product variants first.'),
      findsOneWidget,
    );

    for (final option in ['M', 'White']) {
      final chip = find.widgetWithText(ChoiceChip, option);
      await tester.scrollUntilVisible(chip, 200, scrollable: details);
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Add to Cart'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final flyingProduct = find.byKey(const ValueKey('flying-cart-product'));
    expect(flyingProduct, findsOneWidget);
    final notice = find.byKey(const ValueKey('cart-notice'));
    expect(
      tester.getRect(notice).bottom,
      lessThan(tester.view.physicalSize.height / 2),
    );
    expect(find.byType(SnackBar), findsNothing);
    final takeoff = tester.getCenter(flyingProduct);
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.getCenter(flyingProduct).dy, lessThan(takeoff.dy));
    await tester.pumpAndSettle();
    expect(flyingProduct, findsNothing);
    final item = CartManager.instance.items.single;
    expect(item.id, product.id);
    expect(item.selectedVariants, {'Size': 'M', 'Color': 'White'});
    expect(item.price, product.price);
    expect(item.quantity, 1);
    await tester.tap(find.text('Add to Cart'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('Shopping cart'));
    await tester.pumpAndSettle();
    expect(flyingProduct, findsNothing);
    expect(notice, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
