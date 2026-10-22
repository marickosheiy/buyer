import 'package:flutter/material.dart';

import 'design/components.dart';
import 'design/lumear_theme.dart';
import 'product_model.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.initialCategory = 'All',
    this.embedded = false,
    this.shopName,
  });
  final String initialCategory;
  final bool embedded;
  final String? shopName;
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final controller = TextEditingController();
  late String category = widget.initialCategory;
  String sortBy = 'Recommended';
  bool inStockOnly = false;
  List<String> get categories => ProductCatalog.instance.connected
      ? ['All', ...lumearProducts.map((p) => p.category).toSet()]
      : const [
          'All',
          'Fashion',
          'Electronics',
          'Baby',
          'Jewelry',
          'Gaming',
          'Home',
          'Beauty',
        ];
  static const sorts = [
    'Recommended',
    'Price: Low to High',
    'Price: High to Low',
    'Top Rated',
    'Best Selling',
    'New Arrivals',
  ];
  List<LumearProduct> get results {
    final query = controller.text.trim().toLowerCase();
    final products = lumearProducts
        .where(
          (p) =>
              (query.isEmpty ||
                  '${p.name} ${p.category} ${p.shopName}'
                      .toLowerCase()
                      .contains(query)) &&
              (category == 'All' || p.category == category) &&
              (!inStockOnly || p.stock > 0) &&
              (widget.shopName == null || p.shopName == widget.shopName),
        )
        .toList();
    switch (sortBy) {
      case 'Price: Low to High':
        products.sort((a, b) => a.price.compareTo(b.price));
      case 'Price: High to Low':
        products.sort((a, b) => b.price.compareTo(a.price));
      case 'Top Rated':
        products.sort((a, b) => b.rating.compareTo(a.rating));
      case 'Best Selling':
        products.sort((a, b) => b.soldCount.compareTo(a.soldCount));
      case 'New Arrivals':
        products.sort((a, b) => (b.isNew ? 1 : 0).compareTo(a.isNew ? 1 : 0));
    }
    return products;
  }

  @override
  void initState() {
    super.initState();
    ProductCatalog.instance.addListener(dataChanged);
  }

  void dataChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ProductCatalog.instance.removeListener(dataChanged);
    controller.dispose();
    super.dispose();
  }

  void _filters() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => StatefulBuilder(
      builder: (context, update) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeading('Your way to browse', eyebrow: 'FILTER & SORT'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final sort in sorts)
                    ChoiceChip(
                      label: Text(sort),
                      selected: sortBy == sort,
                      onSelected: (_) {
                        setState(() => sortBy = sort);
                        update(() {});
                      },
                    ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('In stock only'),
                value: inStockOnly,
                onChanged: (value) {
                  setState(() => inStockOnly = value);
                  update(() {});
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Show ${results.length} products'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    LumearAppearance.watch(context);
    final products = results;
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: Text(widget.shopName ?? 'The collection')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              children: [
                PageHeading(
                  widget.shopName ?? 'FIND YOUR NEXT THING.',
                  eyebrow: 'THE COLLECTION / ALL THE GOOD FINDS',
                ),
                TextField(
                  controller: controller,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search products, categories, shops',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        controller.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              scrollDirection: Axis.horizontal,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemCount: categories.length,
              itemBuilder: (_, i) => ChoiceChip(
                label: Text(categories[i]),
                selected: category == categories[i],
                selectedColor: LumearColors.dark,
                labelStyle: TextStyle(
                  color: category == categories[i]
                      ? LumearColors.cream
                      : LumearColors.ink,
                ),
                onSelected: (_) => setState(() => category = categories[i]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 14, 5),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${products.length} finds · $sortBy',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                IconButton(
                  tooltip: 'Filter and sort',
                  onPressed: _filters,
                  icon: const Icon(Icons.tune),
                ),
              ],
            ),
          ),
          Expanded(
            child: products.isEmpty
                ? EmptyState(
                    title: 'No finds just yet',
                    icon: Icons.search_off,
                    message:
                        'Try a different word or explore another category.',
                    action: OutlinedButton(
                      onPressed: () => setState(() {
                        controller.clear();
                        category = 'All';
                        inStockOnly = false;
                      }),
                      child: const Text('Reset filters'),
                    ),
                  )
                : LayoutBuilder(
                    builder: (_, constraints) => GridView.builder(
                      padding: const EdgeInsets.fromLTRB(22, 6, 22, 26),
                      itemCount: products.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: (constraints.maxWidth / 180)
                            .floor()
                            .clamp(2, 6),
                        mainAxisExtent: 328,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 24,
                      ),
                      itemBuilder: (_, i) => ProductCard(products[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
