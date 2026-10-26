import '../design/lumear_theme.dart';

import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../design/components.dart';
import '../login_page.dart';
import '../services/api_service.dart';
import '../services/mobile_number.dart';
import '../product_categories.dart';

/// Buyer workspace backed by the authenticated API, rather than sample records.
class BuyerWorkspace extends StatefulWidget {
  const BuyerWorkspace({super.key});

  @override
  State<BuyerWorkspace> createState() => _BuyerWorkspaceState();
}

class _BuyerWorkspaceState extends State<BuyerWorkspace> {
  int tab = 0;
  bool loading = true;
  bool busy = false;
  String? error;
  String search = '';
  String category = '';
  String sort = 'name';
  String orderFilter = 'All';
  Map<String, dynamic> profile = {};
  Map<String, dynamic> capabilities = {};
  bool supports(String feature) => capabilities[feature] != false;
  List<dynamic> products = [], cart = [], orders = [], addresses = [];
  List<dynamic> vouchers = [], wishlist = [], notifications = [], follows = [];

  String money(dynamic cents) =>
      '₱${((cents as num) / 100).toStringAsFixed(2)}';
  String key() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
  String date(dynamic seconds) =>
      DateTime.fromMillisecondsSinceEpoch(((seconds as num) * 1000).round())
          .toLocal()
          .toString()
          .split('.')
          .first;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    try {
      final values = await Future.wait([
        ApiService.get('/me'),
        ApiService.get('/products'),
        ApiService.get('/cart'),
        ApiService.get('/orders'),
        ApiService.get('/addresses'),
        ApiService.get('/vouchers'),
        ApiService.get('/wishlist'),
        ApiService.get('/notifications'),
        ApiService.get('/follows'),
        ApiService.get('/capabilities'),
      ]);
      if (!mounted) return;
      setState(() {
        profile = Map<String, dynamic>.from(values[0]);
        products = values[1];
        cart = values[2];
        orders = values[3];
        addresses = values[4];
        vouchers = values[5];
        wishlist = values[6];
        notifications = values[7];
        follows = values[8];
        capabilities = values[9] is Map
            ? Map<String, dynamic>.from(values[9])
            : {};
        loading = false;
        error = null;
      });
    } catch (e) {
      if (e is ApiException && e.status == 401) {
        await logout();
        return;
      }
      if (mounted) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  Future<bool> perform(Future<dynamic> Function() action) async {
    if (busy) return false;
    setState(() => busy = true);
    try {
      await action();
      await refresh();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> logout() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await ApiService.post('/auth/logout', body: {});
    } catch (_) {
      // Local sign-out must also work offline or after session expiry.
    } finally {
      ApiService.setToken(null);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => Scaffold(
      appBar: AppBar(
        title: const Text('Lumear'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: busy ? null : refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: busy ? null : logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            MaterialBanner(
              content: Text(error!),
              actions: [
                TextButton(onPressed: refresh, child: const Text('Retry')),
              ],
            ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: switch (tab) {
                        0 => catalog(),
                        1 => cartView(),
                        2 => ordersView(),
                        3 => savedView(),
                        _ => accountView(),
                      },
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: cart.isNotEmpty,
              label: Text('${cart.length}'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            label: 'Cart',
          ),
          const NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            label: 'Orders',
          ),
          const NavigationDestination(
            icon: Icon(Icons.favorite_border),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: notifications.any((n) => n['read'] == false),
              child: const Icon(Icons.person_outline),
            ),
            label: 'You',
          ),
        ],
      ),
    ),
  );

  Widget empty(String title, String subtitle, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        Icon(icon, size: 48),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(subtitle, textAlign: TextAlign.center),
      ],
    ),
  );

  List<Widget> catalog() {
    final visible = products
        .where(
          (p) =>
              p['name'].toString().toLowerCase().contains(
                search.toLowerCase(),
              ) &&
              (category.isEmpty ||
                  ProductCategories.canonical(p['category'].toString()) ==
                      category),
        )
        .toList();
    visible.sort(
      (a, b) => sort == 'name'
          ? a['name'].toString().compareTo(b['name'])
          : sort == 'rating'
          ? (b['rating'] as num).compareTo(a['rating'] as num)
          : sort == 'price_desc'
          ? (b['price'] as num).compareTo(a['price'] as num)
          : (a['price'] as num).compareTo(b['price'] as num),
    );
    return [
      PageHeading(
        'Find your everyday.',
        eyebrow: 'HELLO, ${profile['name'] ?? 'BUYER'}',
        subtitle: 'Handcrafted favorites and useful finds from local stores.',
      ),
      TextField(
        decoration: const InputDecoration(
          labelText: 'Search products',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (v) => setState(() => search = v),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final c in ['', ...ProductCategories.names])
              ChoiceChip(
                label: Text(c.isEmpty ? 'All' : c),
                selected: category == c,
                onSelected: (_) => setState(() => category = c),
              ),
          ],
        ),
      ),
      DropdownButton<String>(
        value: sort,
        isExpanded: true,
        items: const [
          DropdownMenuItem(value: 'name', child: Text('Sort by name')),
          DropdownMenuItem(value: 'price', child: Text('Price: low to high')),
          DropdownMenuItem(
            value: 'price_desc',
            child: Text('Price: high to low'),
          ),
          DropdownMenuItem(value: 'rating', child: Text('Highest rated')),
        ],
        onChanged: (v) => setState(() => sort = v!),
      ),
      if (visible.isEmpty)
        empty(
          'No products found',
          'Try a different search or category.',
          Icons.search_off,
        ),
      for (final p in visible) productCard(p),
    ];
  }

  Widget productCard(dynamic p) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  p['category'] == 'Electronics'
                      ? Icons.headphones
                      : p['category'] == 'Bags'
                      ? Icons.shopping_bag_outlined
                      : Icons.chair_outlined,
                  size: 34,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      p['store'],
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      money(p['price']),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Save product',
                icon: Icon(
                  wishlist.any((w) => w['id'] == p['id'])
                      ? Icons.favorite
                      : Icons.favorite_border,
                ),
                onPressed: busy || !supports('wishlist')
                    ? null
                    : () => perform(
                        () => wishlist.any((w) => w['id'] == p['id'])
                            ? ApiService.delete('/wishlist/${p['id']}')
                            : ApiService.post('/wishlist/${p['id']}', body: {}),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${p['stock']} in stock · ${p['review_count']} reviews${p['review_count'] > 0 ? ' · ${p['rating'].toStringAsFixed(1)} ★' : ''}',
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => productDetails(p),
              child: const Text('View product'),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> productDetails(dynamic product) async {
    dynamic p;
    if (!await perform(() async {
      p = await ApiService.get('/products/${product['id']}');
    })) {
      return;
    }
    if (!mounted) return;
    String? variant = p['variants'].length == 1 ? p['variants'][0]['id'] : null;
    int quantity = 1;
    String? detailError;
    bool submitting = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, update) {
          final options = p['variants'] as List;
          final selected = options.where((v) => v['id'] == variant).firstOrNull;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                22,
                22,
                MediaQuery.viewInsetsOf(sheet).bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['name'],
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(p['description']),
                    const SizedBox(height: 12),
                    Text(
                      money(selected?['price'] ?? p['price']),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final v in options)
                          ChoiceChip(
                            label: Text('${v['label']} (${v['stock']})'),
                            selected: variant == v['id'],
                            onSelected: v['stock'] == 0
                                ? null
                                : (_) => update(() {
                                    variant = v['id'];
                                    quantity = 1;
                                  }),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: quantity > 1
                              ? () => update(() => quantity--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('$quantity'),
                        IconButton(
                          onPressed:
                              selected != null && quantity < selected['stock']
                              ? () => update(() => quantity++)
                              : null,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                        const Spacer(),
                        Text('${selected?['stock'] ?? p['stock']} available'),
                      ],
                    ),
                    if (detailError != null)
                      Text(
                        detailError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    FilledButton(
                      onPressed:
                          submitting || p['stock'] == 0 || p['vacation'] == true
                          ? null
                          : () async {
                              if (variant == null) {
                                update(
                                  () => detailError = 'Select a variant first.',
                                );
                                return;
                              }
                              update(() => submitting = true);
                              try {
                                await ApiService.post(
                                  '/cart',
                                  body: {
                                    'product_id': p['id'],
                                    'variant_id': variant,
                                    'quantity': quantity,
                                  },
                                );
                                await refresh();
                                if (sheet.mounted) Navigator.pop(sheet);
                              } catch (e) {
                                if (sheet.mounted) {
                                  update(() {
                                    detailError = e.toString();
                                    submitting = false;
                                  });
                                }
                              }
                            },
                      child: Text(
                        p['stock'] == 0
                            ? 'Out of stock'
                            : p['vacation'] == true
                            ? 'Store on vacation'
                            : 'Add to cart',
                      ),
                    ),
                    Wrap(
                      spacing: 10,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Chat with store'),
                          onPressed: !supports('chat')
                              ? null
                              : () {
                                  Navigator.pop(sheet);
                                  chat(p['seller'], p['store']);
                                },
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.storefront),
                          label: Text(
                            follows.any((f) => f['id'] == p['seller'])
                                ? 'Following'
                                : 'Follow store',
                          ),
                          onPressed: !supports('follows')
                              ? null
                              : () async {
                                  final followed = follows.any(
                                    (f) => f['id'] == p['seller'],
                                  );
                                  await perform(
                                    () => followed
                                        ? ApiService.delete(
                                            '/follows/${p['seller']}',
                                          )
                                        : ApiService.post(
                                            '/follows/${p['seller']}',
                                            body: {},
                                          ),
                                  );
                                  if (sheet.mounted) update(() {});
                                },
                        ),
                      ],
                    ),
                    const Divider(),
                    const Text(
                      'Buyer reviews',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if ((p['reviews'] as List).isEmpty)
                      const Text('No reviews yet.'),
                    for (final r in p['reviews'])
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${r['reviewer']} · ${r['stars']} ★'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r['text']),
                            ...photosView(r['photos']),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> cartView() => [
    const PageHeading(
      'Your bag.',
      eyebrow: 'READY WHEN YOU ARE',
      subtitle: 'Prices and stock are checked again before ordering.',
    ),
    if (cart.isEmpty)
      empty(
        'Your bag is empty',
        'Discover something you love and add it here.',
        Icons.shopping_bag_outlined,
      ),
    for (final item in cart)
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['name'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('${item['store']} · ${item['variant']}'),
              Row(
                children: [
                  Text(money(item['price'] * item['quantity'])),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Decrease quantity',
                    onPressed: busy || item['quantity'] <= 1
                        ? null
                        : () => perform(
                            () => ApiService.patch(
                              '/cart/${item['id']}',
                              body: {'quantity': item['quantity'] - 1},
                            ),
                          ),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('${item['quantity']}'),
                  IconButton(
                    tooltip: 'Increase quantity',
                    onPressed: busy
                        ? null
                        : () => perform(
                            () => ApiService.patch(
                              '/cart/${item['id']}',
                              body: {'quantity': item['quantity'] + 1},
                            ),
                          ),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  IconButton(
                    tooltip: 'Remove item',
                    onPressed: busy
                        ? null
                        : () => perform(
                            () => ApiService.delete('/cart/${item['id']}'),
                          ),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    if (cart.isNotEmpty)
      FilledButton(
        onPressed: busy ? null : checkout,
        child: const Text('Continue to checkout'),
      ),
  ];

  Future<void> checkout() async {
    if (addresses.isEmpty) {
      await addressForm();
      return;
    }
    if (!supports('checkout')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checkout is awaiting a configured shipping rate.'),
        ),
      );
      return;
    }
    String addressId =
        (addresses.where((a) => a['default'] == true).firstOrNull ??
        addresses.first)['id'];
    final note = TextEditingController();
    final code = TextEditingController();
    List<String> selectedCodes = [];
    Map<String, dynamic>? quote;
    String? checkoutError;
    bool working = false;
    String requestKey = key();
    Future<void> calculate(StateSetter update, BuildContext sheet) async {
      update(() {
        working = true;
        quote = null;
        checkoutError = null;
      });
      try {
        final q = await ApiService.post(
          '/checkout/quote',
          body: {'address_id': addressId, 'vouchers': selectedCodes},
        );
        if (!sheet.mounted) return;
        update(() {
          quote = Map<String, dynamic>.from(q);
          requestKey = key();
        });
      } catch (e) {
        if (sheet.mounted) update(() => checkoutError = e.toString());
      } finally {
        if (sheet.mounted) update(() => working = false);
      }
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => _SheetControllerOwner(
        controllers: [note, code],
        child: StatefulBuilder(
          builder: (sheet, update) => SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                22,
                22,
                MediaQuery.viewInsetsOf(sheet).bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Checkout',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: addressId,
                      decoration: const InputDecoration(
                        labelText: 'Delivery address',
                      ),
                      items: [
                        for (final a in addresses)
                          DropdownMenuItem(
                            value: a['id'] as String,
                            child: Text('${a['label']} · ${a['city']}'),
                          ),
                      ],
                      onChanged: working
                          ? null
                          : (v) => update(() {
                              addressId = v!;
                              quote = null;
                            }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: code,
                      enabled: !working,
                      onChanged: (_) => update(() => quote = null),
                      decoration: const InputDecoration(
                        labelText: 'Voucher codes',
                        helperText: 'Separate codes with commas. Claim them in You first.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: note,
                      maxLength: 200,
                      enabled: !working,
                      decoration: const InputDecoration(
                        labelText: 'Note to seller (optional)',
                      ),
                    ),
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.payments_outlined),
                      title: Text('Cash on delivery'),
                      subtitle: Text(
                        'Pay the confirmed amount when your parcel arrives.',
                      ),
                    ),
                    if (checkoutError != null)
                      Text(
                        checkoutError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    if (quote != null) ...[
                      const Divider(),
                      for (final g in quote!['stores'])
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(g['store']),
                          subtitle: Text(
                            'Items ${money(g['subtotal'])} + shipping ${money(g['shipping'])} − savings ${money(g['discount'])}',
                          ),
                          trailing: Text(money(g['total'])),
                        ),
                      for (final d in quote!['discounts'])
                        Text('${d['code']}: −${money(d['amount'])}'),
                      Text(
                        'Total ${money(quote!['total'])}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: working
                            ? null
                            : () async {
                                selectedCodes = code.text
                                    .split(',')
                                    .map((c) => c.trim().toUpperCase())
                                    .where((c) => c.isNotEmpty)
                                    .toSet()
                                    .toList();
                                await calculate(update, sheet);
                              },
                        child: const Text('Review total'),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: working || quote == null
                            ? null
                            : () async {
                                update(() => working = true);
                                try {
                                  // The displayed quote is submitted unchanged. The server compares it
                                  // with current catalog prices and reserves stock transactionally.
                                  await ApiService.post(
                                    '/checkout',
                                    body: {
                                      'address_id': addressId,
                                      'vouchers': selectedCodes,
                                      'payment_method': 'COD',
                                      'note': note.text,
                                      'idempotency_key': requestKey,
                                      'expected_quote': quote,
                                    },
                                  );
                                  await refresh();
                                  if (!mounted) return;
                                  setState(() => tab = 2);
                                  if (sheet.mounted) Navigator.pop(sheet);
                                } catch (e) {
                                  if (sheet.mounted) {
                                    update(() {
                                      checkoutError = e.toString();
                                      working = false;
                                    });
                                  }
                                  // Preserve the request key on network failure so retry is safe.
                                  if (e is ApiException &&
                                      e.status == 409 &&
                                      sheet.mounted) {
                                    update(() => quote = null);
                                  }
                                }
                              },
                        child: Text(working ? 'Please wait…' : 'Place order'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> ordersView() => [
    const PageHeading(
      'Your orders.',
      eyebrow: 'EVERY STEP, TOGETHER',
      subtitle: 'Track purchases and manage your orders.',
    ),
    SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final s in [
            'All',
            'To Pay',
            'To Ship',
            'To Receive',
            'Completed',
            'Cancelled',
            'Return/Refund',
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  '$s (${orders.where((o) => s == 'All' || o['status'] == s).length})',
                ),
                selected: orderFilter == s,
                onSelected: (_) => setState(() => orderFilter = s),
              ),
            ),
        ],
      ),
    ),
    if (!orders.any((o) => orderFilter == 'All' || o['status'] == orderFilter))
      empty(
        'No orders here yet',
        'Your purchases will appear in the matching tab.',
        Icons.receipt_long_outlined,
      ),
    for (final o in orders.where(
      (o) => orderFilter == 'All' || o['status'] == orderFilter,
    ))
      Card(
        child: ListTile(
          title: Text(o['store']),
          subtitle: Text('${o['id']}\n${o['status']} · ${money(o['total'])}'),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => orderDetails(o),
        ),
      ),
  ];

  Future<void> orderDetails(dynamic o) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(o['id'], style: Theme.of(context).textTheme.headlineSmall),
              Text('${o['store']} · ${o['status']}'),
              const Divider(),
              for (final i in o['items'])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(i['name']),
                  subtitle: Text('${i['variant']} × ${i['quantity']}'),
                  trailing: Text(money(i['price'] * i['quantity'])),
                ),
              Text(
                'Deliver to ${o['address']['name']} · ${o['address']['phone']}',
              ),
              Text(
                '${o['address']['street']}, ${o['address']['city']}, ${o['address']['province']}',
              ),
              if (o['note'].toString().isNotEmpty) Text('Note: ${o['note']}'),
              const Divider(),
              Text('Items ${money(o['subtotal'])}'),
              Text('Shipping ${money(o['shipping'])}'),
              Text('Discounts −${money(o['discount'])}'),
              Text(
                'COD ${money(o['total'])} to collect on delivery',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Divider(),
              for (final event in o['timeline'])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(event['title']),
                  subtitle: Text(date(event['date'])),
                ),
              if (['To Pay', 'To Ship'].contains(o['status']) &&
                  o['ready_for_pickup'] != true)
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(sheet);
                    cancelOrder(o);
                  },
                  child: const Text('Cancel order'),
                ),
              if (supports('receipt_confirmation') &&
                  o['status'] == 'To Receive' &&
                  o['delivered_at'] != null) ...[
                FilledButton(
                  onPressed: () {
                    Navigator.pop(sheet);
                    receiveOrder(o);
                  },
                  child: const Text('Order received'),
                ),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(sheet);
                    returnOrder(o);
                  },
                  child: const Text('Return / refund'),
                ),
              ],
              if (supports('reviews') && o['status'] == 'Completed')
                for (final i in o['items'])
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(sheet);
                      review(o, i);
                    },
                    child: Text('Review ${i['name']}'),
                  ),
              if (o['cancellation_reason'] != null)
                Text('Cancellation: ${o['cancellation_reason']}'),
              if (o['status'] == 'Return/Refund')
                TextButton(
                  onPressed: () async {
                    dynamic requests;
                    if (!await perform(() async {
                      requests = await ApiService.get('/returns');
                    })) {
                      return;
                    }
                    if (!sheet.mounted) return;
                    final r = (requests as List)
                        .where((r) => r['order_id'] == o['id'])
                        .firstOrNull;
                    if (r != null && mounted) {
                      showDialog<void>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text('Return: ${r['status']}'),
                          content: Text('${r['reason']}\n${r['description']}'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  child: const Text('View return request'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> receiveOrder(dynamic o) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirm order received?'),
        content: const Text(
          'Confirm that the items arrived. This completes the order and closes the return window.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep tracking'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await perform(
        () => ApiService.post('/orders/${o['id']}/receive', body: {}),
      );
    }
  }

  Future<void> cancelOrder(dynamic o) => form(
    'Cancel order',
    {'reason': 'Reason (10–300 characters)'},
    (values, photos) =>
        ApiService.post('/orders/${o['id']}/cancel', body: values),
    limits: {'reason': 300},
  );

  Future<void> returnOrder(dynamic o) => form(
    'Return / refund',
    {
      'reason': 'Reason',
      'description': 'Describe the issue (10–500 characters)',
    },
    (values, photos) => ApiService.post(
      '/orders/${o['id']}/return',
      body: {...values, 'photos': photos},
    ),
    attach: true,
    choices: {
      'reason': [
        'Damaged item',
        'Wrong item',
        'Missing item',
        'Not as described',
      ],
    },
    limits: {'description': 500},
  );

  Future<void> review(dynamic o, dynamic item) => form(
    'Review ${item['name']}',
    {'stars': 'Stars', 'text': 'Your review (optional)'},
    (values, photos) => ApiService.post(
      '/orders/${o['id']}/review',
      body: {
        ...values,
        'stars': int.tryParse(values['stars'] ?? ''),
        'product_id': item['product_id'],
        'photos': photos,
      },
    ),
    attach: true,
    choices: {
      'stars': ['1', '2', '3', '4', '5'],
    },
    limits: {'text': 500},
  );

  List<Widget> savedView() => [
    if (!supports('wishlist')) ...[
      const PageHeading('Saved items'),
      const Text(
        'Wishlist and followed stores are not yet configured for this database.',
      ),
    ] else ...[
      const PageHeading(
        'Your favorites.',
        eyebrow: 'SAVE A LITTLE GOOD',
        subtitle: 'Saved products and stores you follow.',
      ),
      if (wishlist.isEmpty)
        empty(
          'Start your wishlist',
          'Tap the heart on a product to save it.',
          Icons.favorite_border,
        ),
      for (final p in products.where(
        (p) => wishlist.any((w) => w['id'] == p['id']),
      ))
        productCard(p),
      const SizedBox(height: 20),
      Text('Followed stores', style: Theme.of(context).textTheme.titleLarge),
      if (follows.isEmpty) const Text('Follow a store from its product page.'),
      for (final f in follows)
        ListTile(
          leading: const Icon(Icons.storefront),
          title: Text(
            f['id'] == 's1' ? 'Maria Clara Handicrafts' : 'RV Gadget Hub',
          ),
          trailing: TextButton(
            onPressed: busy
                ? null
                : () => perform(() => ApiService.delete('/follows/${f['id']}')),
            child: const Text('Unfollow'),
          ),
        ),
    ],
  ];

  List<Widget> accountView() => [
    if (profile['photo'] != null) ...photosView([profile['photo']]),
    PageHeading(
      profile['name'] ?? 'Your account',
      eyebrow: 'MAKE YOURSELF AT HOME',
      subtitle: profile['email'],
    ),
    OutlinedButton.icon(
      onPressed: () => form(
        'Edit profile',
        {'name': 'Full name'},
        (v, p) => ApiService.patch('/me', body: {...v, 'photos': p}),
        initial: {'name': profile['name']},
        attach: supports('profile_photos'),
      ),
      icon: const Icon(Icons.edit_outlined),
      label: const Text('Edit profile'),
    ),
    OutlinedButton.icon(
      onPressed: () => form('Change password', {
        'current_password': 'Current password',
        'new_password': 'New password',
        'confirm_password': 'Confirm new password',
      }, (v, p) => ApiService.post('/auth/password', body: v)),
      icon: const Icon(Icons.lock_outline),
      label: const Text('Change password'),
    ),
    const SizedBox(height: 16),
    Row(
      children: [
        Expanded(
          child: Text(
            'Address book (${addresses.length}/10)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        IconButton(
          tooltip: 'Add address',
          onPressed: addresses.length >= 10 ? null : addressForm,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    if (addresses.isEmpty)
      const Text('Add a delivery address before checking out.'),
    for (final a in addresses)
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${a['label']}${a['default'] ? ' · Default' : ''}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('${a['name']} · ${a['phone']}'),
              Text('${a['street']}, ${a['city']}, ${a['province']}'),
              Wrap(
                children: [
                  TextButton(
                    onPressed: () => addressForm(a),
                    child: const Text('Edit'),
                  ),
                  if (!a['default'])
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => perform(
                              () => ApiService.patch(
                                '/addresses/${a['id']}',
                                body: {'default': true},
                              ),
                            ),
                      child: const Text('Make default'),
                    ),
                  if (!a['default'])
                    TextButton(
                      onPressed: () => confirmDeleteAddress(a),
                      child: const Text('Delete'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    const SizedBox(height: 20),
    Text('Vouchers & rewards', style: Theme.of(context).textTheme.titleLarge),
    if (!supports('vouchers'))
      const Text('Vouchers are not configured for this database.'),
    for (final v in vouchers)
      Card(
        child: ListTile(
          title: Text(v['id']),
          subtitle: Text(
            '${v['percent'] ? '${v['amount']}%' : money(v['amount'])} off · Min. ${money(v['minimum'])}\n'
            '${v['kind']} voucher · Cap ${money(v['cap'])}',
          ),
          isThreeLine: true,
          trailing: TextButton(
            onPressed: busy || v['claimed']
                ? null
                : () => perform(
                    () =>
                        ApiService.post('/vouchers/${v['id']}/claim', body: {}),
                  ),
            child: Text(
              v['redeemed']
                  ? 'Used'
                  : v['claimed']
                  ? 'Claimed'
                  : 'Claim',
            ),
          ),
        ),
      ),
    const SizedBox(height: 20),
    Row(
      children: [
        Expanded(
          child: Text(
            'Notifications',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        TextButton(
          onPressed: busy || !supports('notifications')
              ? null
              : () =>
                    perform(() => ApiService.post('/notifications', body: {})),
          child: const Text('Read all'),
        ),
      ],
    ),
    if (notifications.isEmpty)
      Text(
        supports('notifications')
            ? 'You’re all caught up.'
            : 'Notifications are not configured for this database.',
      ),
    for (final n in notifications)
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          n['read']
              ? Icons.notifications_none
              : Icons.notifications_active_outlined,
        ),
        title: Text(n['title']),
        subtitle: Text(date(n['date'])),
        onTap: () async {
          if (!await perform(
            () => ApiService.post('/notifications/${n['id']}', body: {}),
          )) {
            return;
          }
          final o = orders.where((o) => o['id'] == n['order_id']).firstOrNull;
          if (o != null && mounted) orderDetails(o);
        },
      ),
  ];

  Future<void> confirmDeleteAddress(dynamic a) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text('Remove ${a['label']} from your address book?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await perform(() => ApiService.delete('/addresses/${a['id']}'));
    }
  }

  Future<void> addressForm([dynamic address]) => form(
    address == null ? 'New address' : 'Edit address',
    {
      'label': 'Label (Home, Office…)',
      'name': 'Recipient name',
      'phone': 'Mobile number',
      'street': 'House, street & barangay',
      if (capabilities['storage'] == 'mysql') 'barangay': 'Barangay',
      'city': 'City / municipality',
      'province': 'Province',
      if (capabilities['storage'] == 'mysql') 'postal_code': 'Postal code',
      if (capabilities['storage'] != 'mysql') 'zone': 'Shipping zone',
    },
    (v, p) => address == null
        ? ApiService.post('/addresses', body: v)
        : ApiService.patch(
            '/addresses/${address['id']}',
            body: {...v, 'default': address['default']},
          ),
    choices: {
      'zone': ['NCR', 'CALABARZON', 'Visayas', 'Mindanao', 'Unserviceable'],
    },
    initial: address == null
        ? {'name': profile['name'], 'phone': profile['phone']}
        : Map<String, dynamic>.from(address),
  );

  Future<void> form(
    String title,
    Map<String, String> fields,
    Future<dynamic> Function(Map<String, String>, List<Map<String, dynamic>>)
    save, {
    Map<String, dynamic> initial = const {},
    Map<String, List<String>> choices = const {},
    Map<String, int> limits = const {},
    bool attach = false,
  }) async {
    if (!mounted) return;
    final controllers = {
      for (final k in fields.keys)
        k: TextEditingController(
          text: k == 'phone'
              ? MobileNumber.forEditing(initial[k]?.toString() ?? '')
              : initial[k]?.toString() ?? '',
        ),
    };
    final photos = <Map<String, dynamic>>[];
    String? formError;
    bool saving = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => _SheetControllerOwner(
        controllers: controllers.values.toList(),
        child: StatefulBuilder(
          builder: (sheet, update) => SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                22,
                22,
                MediaQuery.viewInsetsOf(sheet).bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 18),
                    for (final entry in fields.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: choices.containsKey(entry.key)
                            ? DropdownButtonFormField<String>(
                                initialValue:
                                    choices[entry.key]!.contains(
                                      controllers[entry.key]!.text,
                                    )
                                    ? controllers[entry.key]!.text
                                    : null,
                                decoration: InputDecoration(
                                  labelText: entry.value,
                                ),
                                items: choices[entry.key]!
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(s),
                                      ),
                                    )
                                    .toList(),
                                onChanged: saving
                                    ? null
                                    : (v) => controllers[entry.key]!.text =
                                          v ?? '',
                              )
                            : TextField(
                                controller: controllers[entry.key],
                                obscureText: entry.key.contains('password'),
                                enabled: !saving,
                                maxLength: entry.key == 'phone'
                                    ? MobileNumber.maxLength
                                    : limits[entry.key],
                                inputFormatters: entry.key == 'phone'
                                    ? MobileNumber.inputFormatters
                                    : null,
                                maxLines:
                                    entry.key == 'description' ||
                                        entry.key == 'text'
                                    ? 3
                                    : 1,
                                keyboardType: entry.key == 'phone'
                                    ? TextInputType.phone
                                    : TextInputType.text,
                                decoration: InputDecoration(
                                  labelText: entry.value,
                                ),
                              ),
                      ),
                    if (attach) ...[
                      OutlinedButton.icon(
                        onPressed: saving || photos.length >= 5
                            ? null
                            : () async {
                                try {
                                  final files = await FilePicker.pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: ['jpg', 'jpeg', 'png'],
                                  );
                                  for (final f in files) {
                                    if (photos.length >= 5) break;

                                    final bytes = await f.readAsBytes();

                                    if (bytes.length > 5 * 1024 * 1024) {
                                      throw const ApiException(
                                        'Choose JPG or PNG photos of at most 5 MB.',
                                      );
                                    }

                                    photos.add({
                                      'name': f.name,
                                      'data': base64Encode(bytes),
                                    });
                                  }
                                  if (sheet.mounted) update(() {});
                                } catch (e) {
                                  if (sheet.mounted) {
                                    update(() => formError = e.toString());
                                  }
                                }
                              },
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text('Attach photos (${photos.length}/5)'),
                      ),
                      for (final p in photos.toList())
                        ListTile(
                          title: Text(p['name']),
                          trailing: IconButton(
                            onPressed: saving
                                ? null
                                : () => update(() => photos.remove(p)),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                    ],
                    if (formError != null)
                      Text(
                        formError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (controllers.containsKey('phone') &&
                                    !MobileNumber.isValid(
                                      controllers['phone']!.text,
                                    )) {
                                  update(() => formError = MobileNumber.error);
                                  return;
                                }
                                update(() {
                                  saving = true;
                                  formError = null;
                                });
                                try {
                                  await save({
                                    for (final e in controllers.entries)
                                      e.key: e.value.text.trim(),
                                  }, photos);
                                  await refresh();
                                  if (sheet.mounted) Navigator.pop(sheet);
                                } catch (e) {
                                  if (sheet.mounted) {
                                    update(() {
                                      saving = false;
                                      formError = e.toString();
                                    });
                                  }
                                }
                              },
                        child: Text(saving ? 'Saving…' : 'Save'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> photosView(dynamic photos) => [
    for (final p in (photos as List? ?? []))
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Image.memory(
          base64Decode(p['data']),
          height: 120,
          width: 160,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Text('Photo unavailable'),
        ),
      ),
  ];

  Future<void> chat(String seller, String store) async {
    List<dynamic> messages = [];
    if (!await perform(() async {
      messages = await ApiService.get('/chat/$seller');
    })) {
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, update) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .8,
            child: Column(
              children: [
                ListTile(
                  title: Text(store),
                  subtitle: const Text('Messages to the seller'),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () async {
                      await perform(() async {
                        messages = await ApiService.get('/chat/$seller');
                      });
                      if (sheet.mounted) update(() {});
                    },
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (messages.isEmpty)
                        const Text('Start a conversation with this store.'),
                      for (final m in messages)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m['sender'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(m['text']),
                                ...photosView(m['photos']),
                                Text(
                                  date(m['date']),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton.icon(
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Write a message'),
                    onPressed: () async {
                      final messageKey = key();
                      await form(
                        'Message $store',
                        {'text': 'Message'},
                        (v, p) => ApiService.post(
                          '/chat/$seller',
                          body: {
                            ...v,
                            'photos': p,
                            'idempotency_key': messageKey,
                          },
                        ),
                        attach: true,
                        limits: {'text': 1000},
                      );
                      await perform(() async {
                        messages = await ApiService.get('/chat/$seller');
                      });
                      if (sheet.mounted) update(() {});
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Keep controllers alive until the sheet's closing animation has finished.
class _SheetControllerOwner extends StatefulWidget {
  const _SheetControllerOwner({required this.controllers, required this.child});

  final List<TextEditingController> controllers;
  final Widget child;

  @override
  State<_SheetControllerOwner> createState() => _SheetControllerOwnerState();
}

class _SheetControllerOwnerState extends State<_SheetControllerOwner> {
  @override
  void dispose() {
    for (final controller in widget.controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      LumearAppearance.build(context, () => widget.child);
}
