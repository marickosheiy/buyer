import 'package:flutter/material.dart';

import '../design/lumear_theme.dart';
import '../product_categories.dart';
import 'product_media.dart';
import 'seller_commerce.dart';

class SellerProductEditorScreen extends StatefulWidget {
  const SellerProductEditorScreen({super.key, this.product});
  final SellerProduct? product;
  @override
  State<SellerProductEditorScreen> createState() =>
      _SellerProductEditorScreenState();
}

class _SellerProductEditorScreenState extends State<SellerProductEditorScreen> {
  final form = GlobalKey<FormState>();
  late final media = [...?widget.product?.media];
  bool pickingMedia = false;
  String? mediaError;

  Future<void> addMedia(bool video) async {
    setState(() {
      pickingMedia = true;
      mediaError = null;
    });
    try {
      final selected = await ProductMedia.pick(video: video, existing: media);
      if (mounted && selected != null) setState(() => media.add(selected));
    } catch (error) {
      if (mounted) {
        setState(
          () => mediaError = error is FormatException
              ? error.message
              : 'Unable to select media. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => pickingMedia = false);
    }
  }

  late final categories = ProductCategories.names;
  late String? category =
      widget.product == null ||
          !categories.contains(
            ProductCategories.canonical(widget.product!.category),
          )
      ? null
      : ProductCategories.canonical(widget.product!.category);
  late String? subcategory =
      ProductCategories.children(category).contains(widget.product?.subcategory)
      ? widget.product!.subcategory
      : null;
  late final fields = {
    'name': TextEditingController(text: widget.product?.name),
    'price': TextEditingController(
      text: widget.product == null
          ? ''
          : (widget.product!.price / 100).toStringAsFixed(2),
    ),
    'stock': TextEditingController(
      text: widget.product?.stock.toString() ?? '0',
    ),
    'description': TextEditingController(text: widget.product?.description),
    'variety': TextEditingController(
      text: widget.product?.variety ?? 'Default',
    ),
  };
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => Scaffold(
      key: const ValueKey('product-editor-page'),
      appBar: AppBar(
        title: Text(widget.product == null ? 'Add product' : 'Edit product'),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: form,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Product photos and video',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Up to 5 photos (5 MB each) and 1 video (20 MB). JPG, PNG, WEBP or MP4.',
                          ),
                          const SizedBox(height: 8),
                          ProductMediaGallery(
                            media: media,
                            onRemove: pickingMedia
                                ? null
                                : (index) =>
                                      setState(() => media.removeAt(index)),
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed:
                                    pickingMedia ||
                                        media.where((m) => !m.isVideo).length >=
                                            5
                                    ? null
                                    : () => addMedia(false),
                                icon: const Icon(
                                  Icons.add_photo_alternate_outlined,
                                ),
                                label: const Text('Add photo'),
                              ),
                              OutlinedButton.icon(
                                onPressed:
                                    pickingMedia || media.any((m) => m.isVideo)
                                    ? null
                                    : () => addMedia(true),
                                icon: const Icon(Icons.video_library_outlined),
                                label: const Text('Add video'),
                              ),
                            ],
                          ),
                          if (pickingMedia) const LinearProgressIndicator(),
                          if (mediaError != null)
                            Text(
                              mediaError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          const SizedBox(height: 16),
                          for (final entry in {
                            'name': 'Product name',
                            'price': 'Price (₱)',
                            'stock': 'Available stock',
                            'category': 'Category',
                            'subcategory': 'Subcategory',
                            'variety': 'Variety',
                            'description': 'Description (optional)',
                          }.entries)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: entry.key == 'category'
                                  ? DropdownButtonFormField<String>(
                                      initialValue: category,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText: 'Category',
                                        hintText: 'Choose a category',
                                        helperText: categories.isEmpty
                                            ? 'No categories available. Refresh and try again.'
                                            : null,
                                      ),
                                      items: [
                                        for (final option in categories)
                                          DropdownMenuItem(
                                            value: option,
                                            child: Text(option),
                                          ),
                                      ],
                                      onChanged: categories.isEmpty
                                          ? null
                                          : (value) => setState(() {
                                              category = value;
                                              subcategory = null;
                                            }),
                                      validator: (value) => value == null
                                          ? 'Choose a category.'
                                          : null,
                                    )
                                  : entry.key == 'subcategory'
                                  ? DropdownButtonFormField<String>(
                                      key: ValueKey(category),
                                      initialValue: subcategory,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Subcategory',
                                        hintText: 'Choose a subcategory',
                                      ),
                                      items: [
                                        for (final child
                                            in ProductCategories.children(
                                              category,
                                            ))
                                          DropdownMenuItem(
                                            value: child,
                                            child: Text(
                                              child,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                      onChanged: category == null
                                          ? null
                                          : (value) => setState(
                                              () => subcategory = value,
                                            ),
                                      validator: (value) => value == null
                                          ? 'Choose a subcategory.'
                                          : null,
                                    )
                                  : TextFormField(
                                      controller: fields[entry.key],
                                      decoration: InputDecoration(
                                        labelText: entry.value,
                                        helperText: entry.key == 'variety'
                                            ? 'One variety per product (e.g. Red / Small). Add other varieties as separate products.'
                                            : null,
                                        helperMaxLines: 3,
                                      ),
                                      maxLength: entry.key == 'description'
                                          ? 1000
                                          : 100,
                                      maxLines: entry.key == 'description'
                                          ? 3
                                          : 1,
                                      keyboardType: entry.key == 'price'
                                          ? const TextInputType.numberWithOptions(
                                              decimal: true,
                                            )
                                          : entry.key == 'stock'
                                          ? TextInputType.number
                                          : TextInputType.text,
                                      validator: (value) {
                                        final v = value?.trim() ?? '';
                                        if (entry.key == 'description') {
                                          return null;
                                        }
                                        if (v.isEmpty) {
                                          return 'This field is required.';
                                        }
                                        if (entry.key == 'price' &&
                                            (!RegExp(r'^\d{1,7}(\.\d{1,2})?$')
                                                    .hasMatch(v) ||
                                                (double.tryParse(v) ?? 0) <=
                                                    0)) {
                                          return 'Enter a positive price with up to 2 decimals.';
                                        }
                                        if (entry.key == 'stock' &&
                                            (!RegExp(r'^\d{1,6}$')
                                                .hasMatch(v))) {
                                          return 'Enter a whole number from 0 to 999999.';
                                        }
                                        return null;
                                      },
                                    ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: pickingMedia
                            ? null
                            : () {
                                if (!form.currentState!.validate()) return;
                                Navigator.pop(
                                  context,
                                  SellerProduct(
                                    id:
                                        widget.product?.id ??
                                        'SP-${DateTime.now().microsecondsSinceEpoch}',
                                    name: fields['name']!.text.trim(),
                                    price:
                                        (double.parse(
                                                  fields['price']!.text.trim(),
                                                ) *
                                                100)
                                            .round(),
                                    stock: int.parse(
                                      fields['stock']!.text.trim(),
                                    ),
                                    category: category!,
                                    subcategory: subcategory!,
                                    variety: fields['variety']!.text.trim(),
                                    description: fields['description']!.text
                                        .trim(),
                                    active: widget.product?.active ?? true,
                                    media: List.unmodifiable(media),
                                  ),
                                );
                              },
                        child: const Text('Save product'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
