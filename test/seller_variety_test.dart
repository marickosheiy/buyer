import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/seller/seller_commerce.dart';
import 'package:flutter_application_1/services/api_service.dart';

void main() {
  test(
    'seller products keep one variety and reject an empty variety',
    () async {
      final commerce = SellerCommerce();
      addTearDown(commerce.dispose);
      SellerProduct product(String variety) => SellerProduct(
        id: 'single',
        name: 'Basket',
        price: 10000,
        stock: 4,
        category: 'Home and Garden',
        subcategory: 'Furniture & Decor',
        variety: variety,
      );
      await commerce.saveProduct(product('Natural / Small'));
      expect(commerce.products.first.variety, 'Natural / Small');
      await expectLater(
        commerce.saveProduct(product(' ')),
        throwsArgumentError,
      );
      expect(commerce.products.first.variety, 'Natural / Small');
      expect(
        SellerProduct(
          id: 'default',
          name: 'Simple',
          price: 100,
          stock: 1,
          category: 'Home and Garden',
        ).variety,
        'Default',
      );
    },
  );

  test(
    'connected save sends one label and protects existing multi-variety data',
    () async {
      ApiService.baseUrl = 'https://integration.example.invalid/api';
      addTearDown(() => ApiService.baseUrl = '');
      final commerce = SellerCommerce(connected: true);
      addTearDown(commerce.dispose);
      var label = 'Original';
      var saves = 0;
      await http.runWithClient(
        () async {
          await commerce.load();
          expect(commerce.products.first.variety, 'Original');
          expect(commerce.products.first.editable, isTrue);
          final product = SellerProduct(
            id: 'single',
            name: 'Basket',
            price: 10000,
            stock: 5,
            category: 'Home and Garden',
            variety: 'Natural / Large',
          );
          await commerce.saveProduct(product);
          expect(commerce.products.first.variety, 'Natural / Large');
          expect(saves, 1);
          await expectLater(
            commerce.saveProduct(
              SellerProduct(
                id: 'legacy',
                name: 'Legacy',
                price: 10000,
                stock: 5,
                category: 'Home and Garden',
                variety: 'Flattened',
              ),
            ),
            throwsStateError,
          );
          expect(saves, 1);
        },
        () => MockClient((request) async {
          if (request.method == 'PATCH') {
            expect(request.url.path, '/api/seller/products/single');
            final body = jsonDecode(request.body) as Map;
            expect(body['variant_label'], 'Natural / Large');
            expect(body.containsKey('variants'), isFalse);
            expect(body['price'], 10000);
            expect(body['stock'], 5);
            label = body['variant_label'];
            saves++;
            return http.Response('{}', 200);
          }
          return http.Response(
            jsonEncode({
              'shop': {},
              'orders': [],
              'earnings': {},
              'products': [
                for (final id in ['single', 'legacy'])
                  {
                    'id': id,
                    'name': 'Basket',
                    'price': 10000,
                    'stock': 5,
                    'category': 'Home and Garden',
                    'description': '',
                    'active': true,
                    'variants': id == 'single'
                        ? [
                            {'label': label},
                          ]
                        : [
                            {'label': 'Red'},
                            {'label': 'Blue'},
                          ],
                  },
              ],
            }),
            200,
          );
        }),
      );
    },
  );
}
