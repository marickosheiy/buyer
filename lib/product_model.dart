import 'package:flutter/material.dart';

class ProductVariant {
  final String name;
  final List<String> options;
  final Map<String, int> stockByOption;
  final Map<String, double> priceByOption;
  final Map<String, String> idsByOption;

  const ProductVariant({
    required this.name,
    required this.options,
    this.stockByOption = const {},
    this.priceByOption = const {},
    this.idsByOption = const {},
  });

  int stockFor(String option) => stockByOption[option] ?? 0;
  double? priceFor(String option) => priceByOption[option];
}

class ProductReview {
  final String reviewer;
  final double rating;
  final String date;
  final String comment;
  final List<String> photoUrls;

  const ProductReview({
    required this.reviewer,
    required this.rating,
    required this.date,
    required this.comment,
    this.photoUrls = const [],
  });
}

class LumearProduct {
  final String id;
  final String name;
  final String category;
  final String subcategory;
  final String description;
  final double price;
  final double? originalPrice;
  final String imageUrl;
  final List<String> images;
  final IconData icon;
  final double rating;
  final int reviewCount;
  final int soldCount;
  final int stock;
  final String shopName;
  final List<ProductVariant> variants;
  final List<ProductReview> reviews;
  final bool isFeatured;
  final bool isNew;
  final String sellerId;

  const LumearProduct({
    required this.id,
    required this.name,
    required this.category,
    this.subcategory = '',
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.icon,
    this.originalPrice,
    this.images = const [],
    this.rating = 4.8,
    this.reviewCount = 0,
    this.soldCount = 0,
    this.stock = 20,
    this.shopName = 'Lumear Official',
    this.variants = const [],
    this.reviews = const [],
    this.isFeatured = false,
    this.isNew = false,
    this.sellerId = '',
  });

  List<String> get gallery => images.isEmpty ? [imageUrl] : images;

  String get formattedPrice => '₱${price.toStringAsFixed(2)}';
}

class ProductCatalog extends ChangeNotifier {
  ProductCatalog._();
  static final instance = ProductCatalog._();
  bool connected = false;
  List<LumearProduct> products = [];
  void replace(List<dynamic> rows) {
    connected = true;
    products = rows.map((p) {
      final variants = (p['variants'] as List? ?? [])
          .where((v) => v['active'] != false)
          .toList();
      final labels = {
        for (final entry in variants.indexed)
          '${entry.$2['label']}${variants.where((v) => v['label'] == entry.$2['label']).length > 1 ? ' · Option ${entry.$1 + 1}' : ''}':
              entry.$2,
      };
      final images = (p['images'] as List? ?? []).whereType<String>().toList();
      return LumearProduct(
        id: p['id'].toString(),
        name: p['name'],
        category: p['category'],
        subcategory: p['subcategory'] as String? ?? '',
        description: p['description'] ?? '',
        price: (p['price'] as num) / 100,
        imageUrl: images.firstOrNull ?? '',
        images: images,
        icon: Icons.shopping_bag_outlined,
        rating: (p['rating'] as num? ?? 0).toDouble(),
        reviewCount: p['review_count'] ?? 0,
        stock: p['stock'] ?? 0,
        shopName: p['store'],
        sellerId: p['seller'].toString(),
        isFeatured: true,
        isNew: false,
        variants: [
          ProductVariant(
            name: 'Option',
            options: labels.keys.toList(),
            stockByOption: {
              for (final e in labels.entries) e.key: e.value['stock'] as int,
            },
            priceByOption: {
              for (final e in labels.entries)
                e.key: (e.value['price'] as num) / 100,
            },
            idsByOption: {
              for (final e in labels.entries) e.key: e.value['id'].toString(),
            },
          ),
        ],
        reviews: [
          for (final r in p['reviews'] as List? ?? [])
            ProductReview(
              reviewer: r['reviewer'],
              rating: (r['stars'] as num).toDouble(),
              date: '',
              comment: r['text'] ?? '',
            ),
        ],
      );
    }).toList();
    notifyListeners();
  }

  void reset() {
    connected = false;
    products = [];
    notifyListeners();
  }
}

List<LumearProduct> get lumearProducts => ProductCatalog.instance.connected
    ? ProductCatalog.instance.products
    : sampleLumearProducts;

const List<LumearProduct> sampleLumearProducts = [
  LumearProduct(
    id: 'shirt-classic',
    name: 'Classic Everyday Cotton Shirt',
    category: "Men's Apparel",
    subcategory: 'Casual Shirts & Pants',
    description: 'A soft, everyday cotton shirt with a relaxed fit. Easy to style for school, work, or weekends. Please check the size guide and available stock before ordering.',
    price: 499,
    originalPrice: 599,
    imageUrl: 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab',
    images: [
      'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab',
      'https://images.unsplash.com/photo-1503341504253-dff4815485f1',
      'https://images.unsplash.com/photo-1529139574466-a303027c1d8b',
    ],
    icon: Icons.checkroom_rounded,
    rating: 4.8,
    reviewCount: 128,
    soldCount: 860,
    stock: 45,
    variants: [
      ProductVariant(
        name: 'Size',
        options: ['S', 'M', 'L', 'XL'],
        stockByOption: {'S': 8, 'M': 16, 'L': 13, 'XL': 8},
      ),
      ProductVariant(
        name: 'Color',
        options: ['White', 'Black', 'Beige'],
        stockByOption: {'White': 18, 'Black': 15, 'Beige': 12},
      ),
    ],
    reviews: [
      ProductReview(
        reviewer: 'Mika R.',
        rating: 5,
        date: 'Sep 28, 2026',
        comment: 'The fabric is soft and the fit is nice. Worth the price!',
      ),
      ProductReview(
        reviewer: 'Jules A.',
        rating: 4,
        date: 'Sep 20, 2026',
        comment:
            'Good quality. I would recommend checking the size chart first.',
      ),
      ProductReview(
        reviewer: 'Sam C.',
        rating: 5,
        date: 'Sep 12, 2026',
        comment: 'Arrived neatly packed and looks like the photos.',
      ),
    ],
    isFeatured: true,
  ),
  LumearProduct(
    id: 'headset-wireless',
    name: 'Wireless Over-Ear Headphones',
    category: 'Electronics and Gadgets',
    subcategory: 'Audio & Video Equipment',
    description: 'Comfortable over-ear headphones for music, study sessions, and everyday listening. Includes a charging cable and quick-start guide.',
    price: 899,
    originalPrice: 1199,
    imageUrl: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e',
    images: [
      'https://images.unsplash.com/photo-1505740420928-5e560c06d30e',
      'https://images.unsplash.com/photo-1546435770-a3e426bf472b',
    ],
    icon: Icons.headphones_rounded,
    rating: 4.7,
    reviewCount: 96,
    soldCount: 530,
    stock: 23,
    variants: [
      ProductVariant(
        name: 'Color',
        options: ['Black', 'Cream', 'Blue'],
        stockByOption: {'Black': 10, 'Cream': 7, 'Blue': 6},
      ),
    ],
    reviews: [
      ProductReview(
        reviewer: 'Ari P.',
        rating: 5,
        date: 'Oct 1, 2026',
        comment: 'Great for online classes and the sound is clear.',
      ),
      ProductReview(
        reviewer: 'Nico D.',
        rating: 4,
        date: 'Sep 18, 2026',
        comment: 'Comfortable, battery is good so far.',
      ),
    ],
    isFeatured: true,
  ),
  LumearProduct(
    id: 'baby-essentials',
    name: 'Soft Baby Essentials Set',
    category: 'Kids and Baby',
    subcategory: 'Safety and Health',
    description: 'A gentle, practical starter set made for everyday baby care. Check the product label and included items before use.',
    price: 750,
    imageUrl: 'https://images.unsplash.com/photo-1519689680058-324335c77eba',
    icon: Icons.child_friendly_rounded,
    rating: 4.9,
    reviewCount: 43,
    soldCount: 214,
    stock: 17,
    variants: [
      ProductVariant(
        name: 'Set',
        options: ['3-piece', '5-piece'],
        stockByOption: {'3-piece': 9, '5-piece': 8},
        priceByOption: {'3-piece': 750, '5-piece': 990},
      ),
    ],
    reviews: [
      ProductReview(
        reviewer: 'Anne L.',
        rating: 5,
        date: 'Sep 24, 2026',
        comment: 'Cute and useful set. Everything came in good condition.',
      ),
    ],
  ),
  LumearProduct(
    id: 'gold-jewelry',
    name: 'Minimal Gold-Tone Necklace',
    category: "Women's Apparel",
    subcategory: 'Shoes & Accessories',
    description: 'A minimal gold-tone accessory designed for everyday outfits and special occasions. Keep away from water and chemicals to help preserve its finish.',
    price: 1299,
    originalPrice: 1499,
    imageUrl: 'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338',
    icon: Icons.diamond_outlined,
    rating: 4.8,
    reviewCount: 74,
    soldCount: 301,
    stock: 14,
    variants: [
      ProductVariant(
        name: 'Style',
        options: ['Classic', 'Heart', 'Pearl'],
        stockByOption: {'Classic': 6, 'Heart': 5, 'Pearl': 3},
      ),
    ],
    reviews: [
      ProductReview(
        reviewer: 'Bea M.',
        rating: 5,
        date: 'Sep 30, 2026',
        comment: 'Simple and elegant. Looks lovely with most outfits.',
      ),
      ProductReview(
        reviewer: 'Kris V.',
        rating: 4,
        date: 'Sep 10, 2026',
        comment: 'Nice design and packaging.',
      ),
    ],
  ),
  LumearProduct(
    id: 'gaming-controller',
    name: 'Wireless Gaming Controller',
    category: 'Electronics and Gadgets',
    subcategory: 'Mobile Phones & Accessories',
    description: 'A wireless controller for compatible gaming setups. Confirm compatibility with your device before purchasing.',
    price: 1499,
    originalPrice: 1799,
    imageUrl: 'https://images.unsplash.com/photo-1600080972464-8e5f35f63d08',
    icon: Icons.sports_esports_rounded,
    rating: 4.6,
    reviewCount: 58,
    soldCount: 192,
    stock: 11,
    variants: [
      ProductVariant(
        name: 'Color',
        options: ['Black', 'White'],
        stockByOption: {'Black': 7, 'White': 4},
      ),
    ],
    reviews: [
      ProductReview(
        reviewer: 'Ken B.',
        rating: 5,
        date: 'Sep 22, 2026',
        comment: 'Responsive controls and comfortable to hold.',
      ),
    ],
    isFeatured: true,
    isNew: true,
  ),
  LumearProduct(
    id: 'home-organizer',
    name: 'Modern Home Organizer',
    category: 'Home and Garden',
    subcategory: 'Furniture & Decor',
    description: 'A simple organizer to keep everyday essentials tidy. Check the dimensions of your space before ordering.',
    price: 650,
    imageUrl: 'https://images.unsplash.com/photo-1555041469-a586c61ea9bc',
    icon: Icons.inventory_2_outlined,
    rating: 4.7,
    reviewCount: 37,
    soldCount: 146,
    stock: 28,
    variants: [
      ProductVariant(
        name: 'Size',
        options: ['Small', 'Medium', 'Large'],
        stockByOption: {'Small': 12, 'Medium': 10, 'Large': 6},
        priceByOption: {'Small': 650, 'Medium': 850, 'Large': 1090},
      ),
    ],
    reviews: [
      ProductReview(
        reviewer: 'Tess G.',
        rating: 5,
        date: 'Sep 15, 2026',
        comment: 'Looks neat and helps keep my desk organized.',
      ),
    ],
  ),
  LumearProduct(
    id: 'skincare-kit',
    name: 'Daily Skincare Travel Kit',
    category: 'Health and Beauty',
    subcategory: 'Skincare Products',
    description: 'A compact skincare kit for travel and everyday routines. Review the ingredients and product labels before use.',
    price: 399,
    imageUrl: 'https://images.unsplash.com/photo-1596462502278-27bfdc403348',
    icon: Icons.spa_outlined,
    rating: 4.6,
    reviewCount: 81,
    soldCount: 422,
    stock: 32,
    variants: [
      ProductVariant(
        name: 'Bundle',
        options: ['Mini', 'Full set'],
        stockByOption: {'Mini': 20, 'Full set': 12},
        priceByOption: {'Mini': 399, 'Full set': 799},
      ),
    ],
    reviews: [
      ProductReview(
        reviewer: 'Yna S.',
        rating: 5,
        date: 'Sep 26, 2026',
        comment: 'Perfect size for travel and the packaging is cute.',
      ),
    ],
    isNew: true,
  ),
  LumearProduct(
    id: 'backpack-daily',
    name: 'Everyday Canvas Backpack',
    category: "Men's Apparel",
    subcategory: 'Shoes & Accessories',
    description: 'A lightweight everyday backpack for school, commuting, and short trips. Fits daily essentials with a clean, minimal look.',
    price: 799,
    originalPrice: 999,
    imageUrl: 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62',
    icon: Icons.backpack_outlined,
    rating: 4.8,
    reviewCount: 112,
    soldCount: 608,
    stock: 19,
    variants: [
      ProductVariant(
        name: 'Color',
        options: ['Black', 'Olive', 'Sand'],
        stockByOption: {'Black': 8, 'Olive': 6, 'Sand': 5},
      ),
    ],
    reviews: [
      ProductReview(
        reviewer: 'Renz T.',
        rating: 5,
        date: 'Sep 19, 2026',
        comment: 'Spacious and comfortable for daily use.',
      ),
    ],
    isFeatured: true,
  ),
];
