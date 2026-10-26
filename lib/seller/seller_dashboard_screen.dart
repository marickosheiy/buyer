import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../design/components.dart';
import '../design/brand_art.dart';
import '../design/lumear_theme.dart';
import 'seller_profile_screen.dart';
import 'seller_shop.dart';
import 'seller_commerce.dart';
import 'seller_tools_screen.dart';
import '../screen/chat_screen.dart';
import '../services/demo_accounts.dart';
import '../product_categories.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key, this.connected = false});
  final bool connected;
  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  late final shop = SellerShop(connected: widget.connected);
  late final commerce = SellerCommerce(connected: widget.connected);
  bool loading = false;
  String? error;
  int selectedIndex = 0;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  static const destinations = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.shopping_bag_outlined),
      label: 'Orders',
    ),
    NavigationDestination(
      icon: Icon(Icons.inventory_2_outlined),
      label: 'Products',
    ),
    NavigationDestination(
      icon: Icon(Icons.account_balance_wallet_outlined),
      label: 'Earnings',
    ),
    NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
  ];
  @override
  void initState() {
    super.initState();
    final account = DemoAccounts.current;
    if (!widget.connected &&
        account?.role == 'seller' &&
        account!.shopName.isNotEmpty) {
      shop.update(
        owner: account.name,
        name: account.shopName,
        description: account.shopDescription,
        email: account.email,
        phone: account.phone,
      );
    }
    if (widget.connected) refresh();
  }

  Future<void> refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final p = await commerce.load();
      if (!mounted) return;
      shop.status = p['status'] ?? '';
      shop.update(
        owner: p['owner'],
        name: p['name'],
        description: p['description'],
        email: p['email'],
        phone: p['phone'],
      );
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    shop.dispose();
    commerce.dispose();
    super.dispose();
  }

  void select(int index) {
    setState(() => selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    LumearAppearance.watch(context);
    return ListenableBuilder(
      listenable: Listenable.merge([shop, commerce]),
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1000;
          final body = Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    if (!wide)
                      IconButton(
                        tooltip: 'Seller menu',
                        onPressed: () => scaffoldKey.currentState?.openDrawer(),
                        icon: const Icon(Icons.menu),
                      ),
                    Expanded(
                      child: Text(
                        wide
                            ? 'SELLER CENTRE'
                            : (shop.name.isEmpty || selectedIndex == 4
                                  ? 'Lumear Seller'
                                  : shop.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontFamilyFallback: const ['Roboto'],
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: LumearColors.dark,
                        ),
                      ),
                    ),
                    const AppearanceButton(),
                    if (widget.connected)
                      IconButton(
                        tooltip: 'Refresh shop',
                        onPressed: loading ? null : refresh,
                        icon: const Icon(Icons.refresh),
                      ),
                    IconButton(
                      tooltip: 'Seller profile',
                      onPressed: () => select(4),
                      icon: CircleAvatar(
                        radius: 16,
                        backgroundColor: LumearColors.action,
                        child: Text(
                          shop.owner.isEmpty
                              ? 'L'
                              : shop.owner[0].toUpperCase(),
                          style: const TextStyle(
                            color: LumearColors.ivory,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (loading) const LinearProgressIndicator(),
              if (error != null)
                MaterialBanner(
                  content: Text(error!),
                  actions: [
                    TextButton(onPressed: refresh, child: const Text('Retry')),
                  ],
                ),
              Expanded(
                child: IndexedStack(
                  index: selectedIndex,
                  children: [
                    _dashboard(),
                    SellerToolsScreen(commerce: commerce, section: 'Orders'),
                    SellerToolsScreen(commerce: commerce, section: 'Products'),
                    SellerToolsScreen(commerce: commerce, section: 'Earnings'),
                    SellerProfileScreen(
                      shop: shop,
                      showBottomNavigation: false,
                    ),
                    _inventory(),
                    _analytics(),
                    _categories(),
                  ],
                ),
              ),
            ],
          );
          return Scaffold(
            key: scaffoldKey,
            floatingActionButton: FloatingActionButton.extended(
              heroTag: 'seller-chat',
              tooltip: 'Open chat',
              backgroundColor: LumearColors.action,
              foregroundColor: LumearColors.onAction,
              shape: const StadiumBorder(),
              elevation: 3,
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('Chat'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatInboxScreen(
                    connected: widget.connected,
                    seller: true,
                  ),
                ),
              ),
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            drawer: wide
                ? null
                : Drawer(child: SafeArea(child: _sidebar(closeAfter: true))),
            body: SafeArea(
              child: Row(
                children: [
                  if (wide) SizedBox(width: 236, child: _sidebar()),
                  Expanded(child: body),
                ],
              ),
            ),
            bottomNavigationBar: wide
                ? null
                : LumearDock(
                    selectedIndex: selectedIndex < 5 ? selectedIndex : 0,
                    onSelected: select,
                    destinations: destinations,
                  ),
          );
        },
      ),
    );
  }

  Widget _sidebar({bool closeAfter = false}) => Material(
    color: LumearColors.surface,
    child: Container(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: LumearColors.border)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Image.asset('assets/images/logo.png', width: 40, height: 40),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Lumear',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontFamilyFallback: const ['Roboto'],
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                    color: LumearColors.dark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOUR SHOP',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.5,
                      color: LumearColors.light,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    shop.name.isEmpty ? 'Your shop' : shop.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.connected
                        ? (['active', 'approved'].contains(shop.status)
                              ? '● Operational'
                              : '● ${shop.status}')
                        : 'Preview workspace',
                    style: TextStyle(fontSize: 11, color: LumearColors.success),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'OVERVIEW',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.4,
              color: LumearColors.light,
            ),
          ),
          for (final item in [
            (0, Icons.dashboard_outlined, 'Dashboard'),
            (2, Icons.inventory_2_outlined, 'Products'),
            (7, Icons.category_outlined, 'Store categories'),
            (5, Icons.stacked_bar_chart, 'Inventory'),
            (1, Icons.local_shipping_outlined, 'Order management'),
            (6, Icons.show_chart, 'Analytics'),
            (3, Icons.account_balance_wallet_outlined, 'Earnings'),
            (4, Icons.person_outline, 'My profile'),
          ])
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                selected: selectedIndex == item.$1,
                selectedTileColor: LumearColors.action,
                selectedColor: LumearColors.ivory,
                leading: Icon(
                  item.$2,
                  size: 19,
                  color: selectedIndex == item.$1
                      ? LumearColors.ivory
                      : LumearColors.gold,
                ),
                title: Text(item.$3),
                onTap: () {
                  select(item.$1);
                  if (closeAfter) Navigator.pop(context);
                },
              ),
            ),
        ],
      ),
    ),
  );
  List<double> get recentRevenue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      return commerce.completed
          .where(
            (o) =>
                o.placedAt.year == day.year &&
                o.placedAt.month == day.month &&
                o.placedAt.day == day.day,
          )
          .fold<double>(0, (sum, o) => sum + o.subtotal / 100);
    });
  }

  Widget _dashboard() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    final name = shop.owner.trim().split(' ').first;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        PageHeading(
          '$greeting${name.isEmpty ? '' : ', $name'}.',
          eyebrow: shop.name.isEmpty ? 'YOUR SHOP' : shop.name,
          subtitle: 'Here is how your shop is performing.',
          action: IconButton(
            tooltip: 'View products',
            onPressed: () => select(2),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ),
        SellerPreviewNotice(connected: widget.connected),
        if (widget.connected &&
            shop.status.isNotEmpty &&
            !['active', 'approved'].contains(shop.status))
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Shop status: ${shop.status}. Listing and order actions are unavailable while your shop is inactive.',
              ),
            ),
          ),
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth >= 700 ? (c.maxWidth - 24) / 3 : c.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric(
                  'GROSS SALES',
                  sellerMoney(commerce.grossSales),
                  'Completed seller sales',
                  Icons.payments_outlined,
                  w,
                ),
                _metric(
                  'ORDERS',
                  '${commerce.orders.length}',
                  'Customer purchases',
                  Icons.shopping_bag_outlined,
                  w,
                ),
                _metric(
                  'PRODUCTS',
                  '${commerce.products.length}',
                  'Items in your shop',
                  Icons.inventory_2_outlined,
                  w,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, c) {
            final chart = _revenueCard();
            final stock = _stockCard();
            return c.maxWidth >= 800
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: chart),
                      const SizedBox(width: 16),
                      Expanded(child: stock),
                    ],
                  )
                : Column(children: [chart, const SizedBox(height: 4), stock]);
          },
        ),
        const SectionHeading('Needs your attention'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.local_shipping_outlined),
            title: Text('${commerce.toPack} orders to pack'),
            subtitle: const Text('Review items and prepare for pickup'),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () => select(1),
          ),
        ),
        const SectionHeading('Get your shop ready'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${shop.completed} of 3 steps complete',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: shop.completed / 3),
                const SizedBox(height: 16),
                Text(
                  shop.completed == 3
                      ? 'Your shop profile is complete.'
                      : 'Add your identity, shop story and contact details.',
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => select(4),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Manage shop profile'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _metric(
    String title,
    String value,
    String note,
    IconData icon,
    double width,
  ) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: LumearColors.light,
                      fontSize: 10,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(icon, color: LumearColors.gold, size: 22),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'serif',
                fontFamilyFallback: const ['Roboto'],
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: LumearColors.dark,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              note,
              style: TextStyle(color: LumearColors.light, fontSize: 11),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _revenueCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SHOP PERFORMANCE',
            style: TextStyle(
              fontSize: 10,
              color: LumearColors.light,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Revenue overview',
            style: TextStyle(
              fontFamily: 'serif',
              fontFamilyFallback: const ['Roboto'],
              fontWeight: FontWeight.bold,
              fontSize: 25,
              color: LumearColors.dark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Completed sales by order date · Last 7 days',
            style: TextStyle(fontSize: 11, color: LumearColors.light),
          ),
          const SizedBox(height: 20),
          Text(
            sellerMoney(
              (recentRevenue.fold<double>(0, (a, b) => a + b) * 100).round(),
            ),
            style: const TextStyle(
              fontSize: 25,
              fontFamily: 'serif',
              fontFamilyFallback: ['Roboto'],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (recentRevenue.every((v) => v == 0))
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('No completed sales in this period.'),
            ),
          Semantics(
            label:
                'Revenue for the last seven days: ${recentRevenue.map((v) => sellerMoney((v * 100).round())).join(', ')}',
            child: SizedBox(
              height: 142,
              width: double.infinity,
              child: CustomPaint(
                painter: _RevenuePainter(
                  recentRevenue,
                  LumearColors.maroon,
                  LumearColors.border,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final d = DateTime.now().subtract(Duration(days: 6 - i));
              return Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${d.month}/${d.day}',
                    style: TextStyle(fontSize: 10, color: LumearColors.light),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    ),
  );
  Widget _stockCard() => Card(
    color: LumearColors.brandMaroon,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INVENTORY PULSE',
            style: TextStyle(
              color: LumearColors.beige,
              fontSize: 10,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Keep an eye on stock.',
            style: TextStyle(
              fontFamily: 'serif',
              fontFamilyFallback: ['Roboto'],
              color: LumearColors.ivory,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          if (commerce.lowStock == 0)
            const Text(
              'Your products have healthy stock levels.',
              style: TextStyle(color: LumearColors.beige),
            ),
          for (final p in commerce.products.where((p) => p.stock <= 5).take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      p.name,
                      style: const TextStyle(color: LumearColors.ivory),
                    ),
                  ),
                  Text(
                    '${p.stock} left',
                    style: const TextStyle(
                      color: LumearColors.beige,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => select(5),
            style: TextButton.styleFrom(foregroundColor: LumearColors.ivory),
            child: const Text('Open inventory →'),
          ),
        ],
      ),
    ),
  );
  Widget _inventory() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const PageHeading(
        'Inventory',
        eyebrow: 'STOCK CONTROL',
        subtitle: 'Available stock across your current listings.',
      ),
      for (final p in commerce.products)
        Card(
          child: ListTile(
            leading: Icon(
              Icons.inventory_2_outlined,
              color: p.stock <= 5 ? LumearColors.maroon : LumearColors.gold,
            ),
            title: Text(p.name),
            subtitle: Text(p.category),
            trailing: Text('${p.stock} available'),
            onTap: () => select(2),
          ),
        ),
      if (commerce.products.isEmpty) const Text('No inventory yet.'),
    ],
  );
  Widget _analytics() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const PageHeading(
        'Analytics',
        eyebrow: 'SHOP PERFORMANCE',
        subtitle: 'Completed sales and order activity from your shop.',
      ),
      _revenueCard(),
      const SectionHeading('Sales summary'),
      Card(
        child: Column(
          children: [
            ListTile(
              title: const Text('Gross sales'),
              trailing: Text(sellerMoney(commerce.grossSales)),
            ),
            ListTile(
              title: const Text('Commission'),
              trailing: Text(sellerMoney(commerce.fees)),
            ),
            ListTile(
              title: const Text('Net sales'),
              trailing: Text(sellerMoney(commerce.netEarnings)),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _categories() {
    final names = ProductCategories.names;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const PageHeading(
          'Store categories',
          eyebrow: 'CATALOGUE',
          subtitle: 'Choose from 8 categories and their subcategories.',
        ),
        for (final name in names)
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.category_outlined),
              title: Text(name),
              subtitle: Text(
                '${commerce.products.where((p) => ProductCategories.canonical(p.category) == name).length} products',
              ),
              children: [
                for (final child in ProductCategories.children(name))
                  ListTile(title: Text(child), onTap: () => select(2)),
              ],
            ),
          ),
        if (names.isEmpty)
          const Text('Categories appear when you add products.'),
      ],
    );
  }
}

class _RevenuePainter extends CustomPainter {
  _RevenuePainter(this.values, this.color, this.line);
  final List<double> values;
  final Color color, line;
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = line
          ..strokeWidth = .7,
      );
    }
    final maxValue = math.max(1.0, values.reduce(math.max));
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - 8 - (values[i] / maxValue) * (size.height - 16);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .25), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_RevenuePainter old) =>
      old.color != color || old.line != line || !listEquals(old.values, values);
}
