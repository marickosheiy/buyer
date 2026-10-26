import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/design/lumear_theme.dart';
import 'package:flutter_application_1/product_model.dart';
import 'package:flutter_application_1/product_categories.dart';
import 'package:flutter_application_1/search_screen.dart';

void main() {
  test('All eight requested categories have six children and sample products use valid pairs', () {
    expect(ProductCategories.names, [
      'Pet Supplies',
      'Electronics and Gadgets',
      "Women's Apparel",
      "Men's Apparel",
      'Kids and Baby',
      'Home and Garden',
      'Sports and Outdoors',
      'Health and Beauty',
    ]);
    for (final children in ProductCategories.hierarchy.values) {
      expect(children.length, 6);
    }
    for (final product in sampleLumearProducts) {
      expect(
        ProductCategories.children(product.category),
        contains(product.subcategory),
      );
    }
  });

  testWidgets(
    'Buyer subcategory filters products and resets when the main category changes',
    (tester) async {
      ProductCatalog.instance.reset();
      await tester.pumpWidget(
        MaterialApp(
          theme: lumearTheme(),
          home: const SearchScreen(initialCategory: 'Electronics and Gadgets'),
        ),
      );
      await tester.pumpAndSettle();
      final dropdown = find.byType(DropdownButtonFormField<String>);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Audio & Video Equipment').last);
      await tester.pumpAndSettle();
      expect(find.text('Wireless Over-Ear Headphones'), findsOneWidget);
      expect(find.text('Wireless Gaming Controller'), findsNothing);
      final pets = find.widgetWithText(ChoiceChip, 'Pet Supplies');
      await tester.ensureVisible(pets);
      await tester.tap(pets);
      await tester.pumpAndSettle();
      expect(
        tester.widget<DropdownButtonFormField<String>>(dropdown).initialValue,
        'All',
      );
      expect(find.text('No finds just yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
