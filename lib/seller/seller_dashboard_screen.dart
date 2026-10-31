import 'package:flutter/material.dart';

import '../design/components.dart';
import '../design/brand_art.dart';
import '../design/lumear_theme.dart';
import 'seller_profile_screen.dart';
import 'seller_shop.dart';
import 'seller_shop_images.dart';
import 'seller_commerce.dart';
import 'seller_tools_screen.dart';
import '../screen/chat_screen.dart';
import '../services/demo_accounts.dart';
import '../services/marketplace_policy.dart';
import '../services/top_notification.dart';
import 'seller_stock_alerts_screen.dart';
import 'seller_analytics_panel.dart';

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
  final notificationKey = GlobalKey();
  final Map<String, int> _previousStock = {};
  TopNotificationHandle? _stockNotice;
  bool _stockCheckScheduled = false;
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
    commerce.addListener(_queueStockCheck);
    _queueStockCheck();
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

  void _queueStockCheck() {
    if (_stockCheckScheduled) return;
    _stockCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _stockCheckScheduled = false;
      if (!mounted) return;
      final alerts = commerce.lowStockProducts.where((product) {
        final previous = _previousStock[product.id];
        return previous == null || product.stock < previous;
      }).toList();
      _previousStock
        ..clear()
        ..addEntries(commerce.products.map((p) => MapEntry(p.id, p.stock)));
      if (alerts.isEmpty) return;
      final names = alerts
          .take(2)
          .map((p) => '${p.name}: ${p.stock} left')
          .join('; ');
      _stockNotice = showTopNotification(
        context,
        SnackBar(
          content: Text(
            'Low stock (5 or less) · $names${alerts.length > 2 ? '; +${alerts.length - 2} more' : ''}',
          ),
          action: SnackBarAction(
            label: 'View stock',
            onPressed: openStockAlerts,
          ),
        ),
      );
    });
  }

  Future<void> openStockAlerts() async {
    _stockNotice?.dismiss();
    final manage = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SellerStockAlertsScreen(commerce: commerce),
      ),
    );
    if (mounted && manage == true) select(2);
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
      shop.readImages(p);
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
    commerce.removeListener(_queueStockCheck);
    _stockNotice?.dismiss();
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
                    IconButton(
                      tooltip: 'Seller notifications',
                      onPressed: () {
                        select(0);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          final target = notificationKey.currentContext;
                          if (target != null) {
                            Scrollable.ensureVisible(
                              target,
                              duration: const Duration(milliseconds: 300),
                            );
                          }
                        });
                      },
                      icon: const Icon(Icons.notifications_outlined),
                    ),
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
                        child: shop.profileImage != null
                            ? ClipOval(
                                child: SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: ShopPhoto(
                                    photo: shop.profileImage,
                                    profile: true,
                                  ),
                                ),
                              )
                            : Text(
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
                    SellerToolsScreen(
                      commerce: commerce,
                      section: 'Earnings',
                      shopName: shop.name.isEmpty ? 'Lumear Seller' : shop.name,
                    ),
                    SellerProfileScreen(
                      shop: shop,
                      showBottomNavigation: false,
                    ),
                    _inventory(),
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
            (5, Icons.stacked_bar_chart, 'Inventory'),
            (1, Icons.local_shipping_outlined, 'Order management'),
            (0, Icons.show_chart, 'Analytics'),
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
        SellerAnalyticsPanel(
          commerce: commerce,
          shopName: shop.name.isEmpty ? 'Lumear Seller' : shop.name,
          openSection: select,
          notificationKey: notificationKey,
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
              color: p.stock <= MarketplacePolicy.lowStockThreshold
                  ? LumearColors.maroon
                  : LumearColors.gold,
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
}
