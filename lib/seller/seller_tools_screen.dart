import '../services/top_notification.dart';
import 'product_media.dart';

import 'package:flutter/material.dart';

import 'seller_product_editor_screen.dart';

import '../design/components.dart';
import '../design/lumear_theme.dart';
import 'seller_commerce.dart';
import 'seller_income_panel.dart';
import '../services/marketplace_policy.dart';
import 'payout_request_dialog.dart';

class SellerToolsScreen extends StatefulWidget {
  const SellerToolsScreen({
    super.key,
    required this.commerce,
    required this.section,
    this.shopName = 'Lumear Seller',
  });
  final SellerCommerce commerce;
  final String section;
  final String shopName;
  @override
  State<SellerToolsScreen> createState() => _SellerToolsScreenState();
}

class _SellerToolsScreenState extends State<SellerToolsScreen> {
  String query = '';
  String filter = 'All';
  bool working = false;
  SellerCommerce get data => widget.commerce;

  Future<bool> perform(Future<void> Function() action) async {
    if (working) return false;
    setState(() => working = true);
    try {
      await action();
      return true;
    } catch (e) {
      if (mounted) {
        showTopNotification(context, SnackBar(content: Text(e.toString())));
      }
      return false;
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => ListenableBuilder(
      listenable: data,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          PageHeading(
            widget.section == 'Earnings' ? 'Income & Earnings' : widget.section,
            eyebrow: widget.section == 'Products'
                ? 'CATALOGUE'
                : widget.section == 'Earnings'
                ? 'SELLER FINANCE'
                : 'SELLER OPERATIONS',
            subtitle: switch (widget.section) {
              'Products' =>
                'Keep your listings and available stock up to date.',
              'Orders' =>
                'Pack carefully. Get every order ready for its next step.',
              _ =>
                'Know what you sold, what was deducted, and what is pending.',
            },
          ),
          SellerPreviewNotice(connected: data.connected),
          if (working) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          if (widget.section == 'Products') ...products(),
          if (widget.section == 'Orders') ...orders(),
          if (widget.section == 'Earnings') ...[
            SellerIncomePanel(commerce: data, shopName: widget.shopName),
            ...(data.connected ? connectedEarnings() : earnings()),
          ],
        ],
      ),
    ),
  );

  Widget search(String label) => TextField(
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.search),
    ),
    onChanged: (value) => setState(() => query = value.toLowerCase()),
  );

  Widget filters(List<String> labels) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final label in labels)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: filter == label,
                onSelected: (_) => setState(() => filter = label),
              ),
            ),
        ],
      ),
    ),
  );

  List<Widget> products() {
    final visible = data.products
        .where(
          (p) =>
              p.name.toLowerCase().contains(query) &&
              switch (filter) {
                'Active' => p.active,
                'Hidden' => !p.active,
                'Low stock' => p.stock <= MarketplacePolicy.lowStockThreshold,
                _ => true,
              },
        )
        .toList();
    return [
      FilledButton.icon(
        onPressed: working ? null : () => editProduct(),
        icon: const Icon(Icons.add),
        label: const Text('Add product'),
      ),
      const SizedBox(height: 16),
      search('Search products'),
      filters(['All', 'Active', 'Hidden', 'Low stock']),
      if (visible.isEmpty)
        const _Empty(
          'No products here',
          'Add a listing or try another filter.',
        ),
      LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth < 760) {
            return Column(
              children: [
                for (final p in visible)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: LumearColors.field,
                                child: Icon(
                                  Icons.inventory_2_outlined,
                                  color: LumearColors.maroon,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  p.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Edit ${p.name}',
                                onPressed: working || !p.editable
                                    ? null
                                    : () => editProduct(p),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (p.media.isNotEmpty) ...[
                            ProductMediaGallery(media: p.media),
                            const SizedBox(height: 12),
                          ],
                          Text('${sellerMoney(p.price)} · ${p.category}'),
                          if (p.subcategory.isNotEmpty) Text(p.subcategory),
                          Text('Variety: ${p.variety}'),
                          const SizedBox(height: 8),
                          Text(
                            p.stock == 0
                                ? 'Out of stock'
                                : '${p.stock} available${p.stock <= MarketplacePolicy.lowStockThreshold ? ' · Low stock' : ''}',
                            style: TextStyle(
                              color:
                                  p.stock <= MarketplacePolicy.lowStockThreshold
                                  ? LumearColors.maroon
                                  : LumearColors.ink,
                            ),
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              p.active ? 'Listing active' : 'Listing hidden',
                            ),
                            subtitle: Text(
                              !p.editable
                                  ? 'Separate products are required for each variety before this listing can be edited.'
                                  : data.connected
                                  ? 'Active listings appear in the buyer catalog'
                                  : 'Preview visibility',
                            ),
                            value: p.active,
                            onChanged: working || !p.editable
                                ? null
                                : (active) => perform(
                                    () => data.saveProduct(
                                      SellerProduct(
                                        id: p.id,
                                        name: p.name,
                                        price: p.price,
                                        stock: p.stock,
                                        category: p.category,
                                        subcategory: p.subcategory,
                                        variety: p.variety,
                                        description: p.description,
                                        active: active,
                                        media: p.media,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          }
          return Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('PRODUCT')),
                  DataColumn(label: Text('MEDIA')),
                  DataColumn(label: Text('CATEGORY')),
                  DataColumn(label: Text('VARIETY')),
                  DataColumn(label: Text('PRICE')),
                  DataColumn(label: Text('STOCK')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('')),
                ],
                rows: [
                  for (final p in visible)
                    DataRow(
                      cells: [
                        DataCell(SizedBox(width: 150, child: Text(p.name))),
                        DataCell(
                          TextButton.icon(
                            onPressed: p.media.isEmpty
                                ? null
                                : () => showDialog<void>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: Text(p.name),
                                      content: SingleChildScrollView(
                                        child: SizedBox(
                                          width: 420,
                                          child: ProductMediaGallery(
                                            media: p.media,
                                          ),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                                  ),
                            icon: const Icon(Icons.perm_media_outlined),
                            label: Text('${p.media.length} attachments'),
                          ),
                        ),
                        DataCell(Text(p.category)),
                        DataCell(SizedBox(width: 120, child: Text(p.variety))),
                        DataCell(Text(sellerMoney(p.price))),
                        DataCell(Text('${p.stock}')),
                        DataCell(
                          Chip(label: Text(p.active ? 'Active' : 'Hidden')),
                        ),
                        DataCell(
                          TextButton(
                            onPressed: working || !p.editable
                                ? null
                                : () => editProduct(p),
                            child: const Text('Edit →'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ];
  }

  Future<void> editProduct([SellerProduct? product]) async {
    final result = await Navigator.of(context).push<SellerProduct>(
      MaterialPageRoute(
        builder: (_) => SellerProductEditorScreen(product: product),
      ),
    );
    if (result != null && mounted) {
      await perform(() => data.saveProduct(result));
    }
  }

  List<Widget> orders() {
    final visible = data.orders
        .where(
          (o) =>
              (filter == 'All' || o.status.label == filter) &&
              '${o.id} ${o.buyer} ${o.productName}'.toLowerCase().contains(
                query,
              ),
        )
        .toList();
    return [
      search('Search order or buyer'),
      filters(['All', ...SellerOrderStatus.values.map((s) => s.label)]),
      if (visible.isEmpty)
        const _Empty('No matching orders', 'Try another status or search.'),
      for (final o in visible)
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              o.id,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${o.buyer}\n${data.connected ? o.productName : '${o.quantity} × ${o.productName}'}\n${o.status.label} · ${sellerMoney(o.subtotal)}',
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => orderDetails(o),
          ),
        ),
    ];
  }

  Future<void> orderDetails(SellerOrder order) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(order.id, style: Theme.of(context).textTheme.headlineSmall),
            Text(order.status.label),
            const Divider(height: 28),
            Text(
              order.buyer,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(order.address),
            const SizedBox(height: 16),
            Text(
              data.connected
                  ? order.productName
                  : '${order.quantity} × ${order.productName}',
            ),
            Text(
              'Placed ${order.placedAt.toLocal().toString().split(' ').first}',
            ),
            const SizedBox(height: 16),
            _amount('Items', order.subtotal),
            _amount('Shipping charged to buyer', order.shipping),
            _amount(
              'Buyer total · ${order.paymentMethod}',
              order.subtotal + order.shipping,
            ),
            const SizedBox(height: 16),
            if (order.cancellationReason != null)
              Text('Cancellation: ${order.cancellationReason}'),
            if (order.status == SellerOrderStatus.toPack) ...[
              const Text(
                'Check the items and packaging before marking this order ready.',
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: working
                      ? null
                      : () async {
                          final ok = await perform(() => data.prepare(order));
                          if (ok && sheet.mounted) Navigator.pop(sheet);
                        },
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Mark ready for pickup'),
                ),
              ),
              if (order.cancellable)
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () async {
                      Navigator.pop(sheet);
                      await cancelOrder(order);
                    },
                    child: const Text('Cancel order'),
                  ),
                ),
            ] else if (order.status == SellerOrderStatus.ready ||
                order.status == SellerOrderStatus.inTransit)
              const Text(
                'Pickup and delivery are confirmed by the delivery service. Waiting for integration.',
              ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pop(sheet),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> cancelOrder(SellerOrder order) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _CancelDialog(),
    );
    if (reason != null && mounted) {
      await perform(() => data.cancel(order, reason));
    }
  }

  Future<void> requestPayout() async {
    final sent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PayoutRequestDialog(commerce: data),
    );
    if (sent == true && mounted) {
      showTopNotification(
        context,
        const SnackBar(content: Text('Payout request sent for manual review.')),
      );
      await perform(() async {
        await data.load();
      });
    }
  }

  void payoutDetails() {
    final accounts = data.earnings['payout_accounts'] as List? ?? [];
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Payout details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (accounts.isEmpty)
              const Text('No payout account is saved for this shop.'),
            for (final a in accounts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.account_balance_outlined),
                title: Text(a['name']),
                subtitle: Text(a['type']),
              ),
            const SizedBox(height: 12),
            const Text(
              'Contact your marketplace administrator to add or change payout account details.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  List<Widget> connectedEarnings() {
    final e = data.earnings;
    final available = e['available_to_request'] as int?;
    final accounts = e['payout_accounts'] as List? ?? [];
    Widget balance(String label, dynamic amount, String note) => Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: LumearColors.light, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Text(
              amount == null ? 'Not available' : sellerMoney(amount),
              style: TextStyle(
                fontFamily: 'serif',
                fontFamilyFallback: const ['Roboto'],
                fontSize: 29,
                fontWeight: FontWeight.bold,
                color: LumearColors.dark,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              note,
              style: TextStyle(fontSize: 11, color: LumearColors.light),
            ),
          ],
        ),
      ),
    );
    final history = Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeading('Payout requests', kicker: 'PAYOUT HISTORY'),
            if ((e['payouts'] as List? ?? []).isEmpty)
              const Text('No payout requests.'),
            for (final p in e['payouts'] as List? ?? [])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(sellerMoney(p['amount'])),
                subtitle: Text('Request ${p['id']}'),
                trailing: Chip(label: Text(p['status'])),
              ),
          ],
        ),
      ),
    );
    final request = Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeading(
              'Request a manual payout',
              kicker: 'WITHDRAW EARNINGS',
            ),
            Text(
              available == null
                  ? 'No wallet is available for payout requests.'
                  : 'Available to request: ${sellerMoney(available)}',
            ),
            const SizedBox(height: 12),
            Text(
              accounts.isEmpty
                  ? 'Add a payout account through your marketplace administrator.'
                  : 'Choose one of your saved payout accounts. Requests are reviewed before payment.',
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed:
                  working ||
                      available == null ||
                      available < 100 ||
                      accounts.isEmpty
                  ? null
                  : requestPayout,
              child: const Text('Request payout'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: payoutDetails,
              child: const Text('Payout details →'),
            ),
          ],
        ),
      ),
    );
    return [
      const SectionHeading('Wallet & payouts'),
      LayoutBuilder(
        builder: (context, c) {
          final a = balance(
            'Available balance',
            e['wallet_available'],
            'Recorded wallet balance before open payout requests.',
          );
          final b = balance(
            'Pending COD earnings',
            e['wallet_pending'],
            'Released after delivery and settlement requirements are met.',
          );
          return c.maxWidth >= 650
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: a),
                    const SizedBox(width: 16),
                    Expanded(child: b),
                  ],
                )
              : Column(children: [a, b]);
        },
      ),
      LayoutBuilder(
        builder: (context, c) => c.maxWidth >= 800
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: request),
                  const SizedBox(width: 16),
                  Expanded(child: history),
                ],
              )
            : Column(children: [request, history]),
      ),
      const SectionHeading('Completed sales'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _amount('Item sales', data.grossSales),
              _amount('Recorded commission', -data.fees),
              const Divider(),
              _amount('Sales less commission', data.netEarnings),
              _amount('Recorded paid payouts', e['paid_out'] ?? 0),
            ],
          ),
        ),
      ),
      const SectionHeading('Wallet ledger', kicker: 'ACCOUNT ACTIVITY'),
      if ((e['journals'] as List? ?? []).isEmpty)
        const Text('No wallet activity yet.'),
      for (final j in e['journals'] as List? ?? [])
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  j['type'].toString().replaceAll('_', ' '),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                if ((j['reference'] as String? ?? '').isNotEmpty)
                  Text(j['reference']),
                if (j['amount'] != null)
                  _amount('Recorded amount', j['amount'])
                else ...[
                  _amount('Available change', j['available_delta']),
                  _amount('Pending change', j['pending_delta']),
                ],
              ],
            ),
          ),
        ),
      const SizedBox(height: 16),
      Text(
        'Sales reports and wallet balances are separate. Shipping is excluded from item sales. Refunds, adjustments and open payout requests may affect the amount available to request.',
        style: TextStyle(fontSize: 12, color: LumearColors.light, height: 1.5),
      ),
    ];
  }

  List<Widget> earnings() => [
    const SectionHeading('Settlement overview'),
    Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _amount('Awaiting settlement', data.awaitingSettlement),
            _amount('Paid out · sample history', data.paidOut),
            _amount('Uncompleted item sales', data.pendingSales),
          ],
        ),
      ),
    ),
    const SizedBox(height: 12),
    const Text(
      'Settlement totals cover all completed sample orders. Withdrawals require connected payout services. No money is transferred in this preview.',
      style: TextStyle(fontSize: 12, height: 1.5),
    ),
  ];
  Widget _amount(String label, int value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            sellerMoney(value),
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class SellerPreviewNotice extends StatelessWidget {
  const SellerPreviewNotice({super.key, this.connected = false});
  final bool connected;
  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LumearColors.field,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        connected
            ? 'Connected shop · Products, orders and balances come from your database.'
            : 'Seller preview · Sample orders and earnings. Changes last until sign-out and are not published to buyers.',
        style: TextStyle(fontSize: 12, height: 1.4),
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.title, this.subtitle);
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 36),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _CancelDialog extends StatefulWidget {
  const _CancelDialog();
  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  String reason = 'Item unavailable';
  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => AlertDialog(
      title: const Text('Cancel this order?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reserved stock will be restored in this preview.'),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: reason,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: [
              for (final r in [
                'Item unavailable',
                'Item damaged',
                'Unable to fulfill',
              ])
                DropdownMenuItem(value: r, child: Text(r)),
            ],
            onChanged: (v) => setState(() => reason = v!),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep order'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, reason),
          child: const Text('Confirm cancellation'),
        ),
      ],
    ),
  );
}
