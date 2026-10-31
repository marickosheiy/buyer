import 'package:flutter/material.dart';

import 'seller_analytics_pdf.dart';

import 'package:printing/printing.dart';

import '../design/components.dart';
import '../screen/chat_screen.dart';
import 'seller_analytics.dart';
import 'seller_commerce.dart';

class SellerAnalyticsPanel extends StatefulWidget {
  const SellerAnalyticsPanel({
    super.key,
    required this.commerce,
    required this.shopName,
    required this.openSection,
    this.notificationKey,
  });
  final SellerCommerce commerce;
  final String shopName;
  final ValueChanged<int> openSection;
  final Key? notificationKey;
  @override
  State<SellerAnalyticsPanel> createState() => _SellerAnalyticsPanelState();
}

class _SellerAnalyticsPanelState extends State<SellerAnalyticsPanel> {
  late final service = SellerAnalytics(widget.commerce);
  SellerAnalyticsRange range = SellerAnalyticsRange.period('This week');
  String period = 'This week';
  SellerAnalyticsSnapshot? data;
  String? error;
  bool busy = false, loading = false;
  int revision = 0;
  @override
  void initState() {
    super.initState();
    widget.commerce.addListener(refresh);
    refresh();
  }

  @override
  void dispose() {
    widget.commerce.removeListener(refresh);
    revision++;
    super.dispose();
  }

  Future<void> refresh() async {
    final request = ++revision;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await service.load(range);
      if (mounted && request == revision) setState(() => data = result);
    } catch (e) {
      if (mounted && request == revision) {
        setState(() {
          error = e.toString();
          data = null;
        });
      }
    } finally {
      if (mounted && request == revision) setState(() => loading = false);
    }
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    final before = revision;
    try {
      await action();
      if (revision == before) await refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> customRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      period = 'Custom';
      range = SellerAnalyticsRange(
        DateTime.utc(picked.start.year, picked.start.month, picked.start.day),
        DateTime.utc(
          picked.end.year,
          picked.end.month,
          picked.end.day,
        ).add(const Duration(days: 1)),
      );
    });
    await refresh();
  }

  Future<void> export(bool share) async {
    final snapshot = data!;
    final selectedRange = range;
    final bytes = await buildSellerAnalyticsPdf(
      snapshot: snapshot,
      selectedRange: selectedRange,
      shopName: widget.shopName,
      demo: !widget.commerce.connected,
    );
    final filename =
        'seller-report-${analyticsDate(selectedRange.start)}-${analyticsDate(selectedRange.end.subtract(const Duration(days: 1)))}.pdf';
    if (share) {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } else {
      await Printing.layoutPdf(name: filename, onLayout: (_) async => bytes);
    }
  }

  Widget section(String title, List<Widget> children, {Key? key}) => Card(
    key: key,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
  Widget line(String title, String detail, {Widget? action}) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: Text(detail),
    trailing: action,
  );
  @override
  Widget build(BuildContext context) {
    final snapshot = data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading('Seller insights'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final label in ['Today', 'This week', 'This month'])
              ChoiceChip(
                label: Text(label),
                selected: period == label,
                onSelected: (_) {
                  setState(() {
                    period = label;
                    range = SellerAnalyticsRange.period(label);
                  });
                  refresh();
                },
              ),
            OutlinedButton(
              onPressed: customRange,
              child: const Text('Custom dates'),
            ),
            IconButton(
              tooltip: 'Refresh analytics',
              onPressed: loading ? null : refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        Text('${range.label} · Philippine time'),
        Text('Compared with ${range.previous.label}'),
        if (loading || busy) const LinearProgressIndicator(),
        if (error != null) ...[
          Text(error!),
          TextButton(onPressed: refresh, child: const Text('Retry analytics')),
        ],
        if (snapshot != null && !loading) ...[
          const Text(
            'Completed merchandise sales; shipping excluded. Earnings deduct commission and refunds. Conversion: completed orders / shop visits.',
          ),
          LayoutBuilder(
            builder: (_, c) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final metric in {
                  'sales': 'Sales',
                  'orders': 'Orders',
                  'earnings': 'Earnings',
                  'conversion': 'Conversion',
                  'units': 'Units sold',
                  'aov': 'Average order value',
                  'cancelled': 'Cancelled orders',
                  'returned': 'Returned orders',
                }.entries)
                  SizedBox(
                    width: c.maxWidth >= 650
                        ? (c.maxWidth - 24) / 4
                        : (c.maxWidth - 8) / 2,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(metric.value),
                            Text(
                              analyticsValue(
                                metric.key,
                                snapshot.current[metric.key] ?? 0,
                              ),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              analyticsChange(metric.key, snapshot),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          section('Revenue by day', [
            if (snapshot.daily.isEmpty) const Text('No sales in this period.'),
            for (final row in snapshot.daily)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text('${row['date']}')),
                    Text(analyticsValue('revenue', row['revenue'] as num)),
                  ],
                ),
              ),
          ]),
          section('Best sellers & product performance', [
            if (snapshot.products.isEmpty)
              const Text('No product activity available.'),
            for (final p in snapshot.products)
              line(
                '${p['name']} · ${p['units']} units',
                '${p['views']} views · ${p['cart_rate']}% add-to-cart · ${p['purchases']} purchases\n${analyticsValue('revenue', p['revenue'] as num)} revenue · ${p['stock']} in stock${p['low_performing'] == true ? '\nLow performing: review listing and pricing' : ''}${(p['stock'] as num) <= 5 ? '\n${p['stock'] == 0 ? 'Out of stock' : 'Low stock'}' : ''}',
              ),
            OutlinedButton(
              onPressed: () => widget.openSection(2),
              child: const Text('Update stock'),
            ),
          ]),
          section('Customer insights', [
            Text(
              '${snapshot.customers['new']} new · ${snapshot.customers['returning']} returning · ${snapshot.customers['repeat']} repeat buyers',
            ),
            const Text(
              'Returning: bought before this period. Repeat: 2+ completed orders within this period.',
            ),
            if ((snapshot.customers['locations'] as List).isEmpty)
              const Text('Location data unavailable.'),
            for (final location in snapshot.customers['locations'] as List)
              line('${location['name']}', '${location['buyers']} buyers'),
          ]),
          section('Promotion analytics', [
            if (snapshot.promotions.isEmpty)
              const Text('No promotions in this period.'),
            for (final p in snapshot.promotions)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  line(
                    '${p['name']} · ${p['active'] == true ? 'Active' : 'Paused'}',
                    '${p['kind']} · ${p['views']} views · ${p['claims']} claims · ${p['redemptions']} redemptions\n${analyticsValue('revenue', p['revenue'] as num)} revenue · ${analyticsValue('conversion', p['conversion'] as num)} conversion',
                  ),
                  if ((p['warning'] as String? ?? '').isNotEmpty)
                    Text('${p['warning']}'),
                  if (p['active'] == true)
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => perform(() => service.pause('${p['id']}')),
                      child: const Text('Pause promotion'),
                    ),
                ],
              ),
          ]),
          section('Order snapshot · current', [
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (final e in snapshot.operations.entries)
                  Text('${e.key}: ${e.value}'),
              ],
            ),
            for (final o in widget.commerce.orders.where(
              (o) => [
                SellerOrderStatus.toPack,
                SellerOrderStatus.ready,
              ].contains(o.status),
            ))
              line(
                o.id,
                '${o.buyer} · ${o.rawStatus == 'packed' ? 'Packed' : o.status.label}',
                action: TextButton(
                  onPressed: busy
                      ? null
                      : () => perform(
                          () =>
                              o.rawStatus == 'packed' ||
                                  o.status == SellerOrderStatus.ready
                              ? widget.commerce.markShipped(o)
                              : widget.commerce.markPacked(o),
                        ),
                  child: Text(
                    o.rawStatus == 'packed' ||
                            o.status == SellerOrderStatus.ready
                        ? 'Mark shipped'
                        : 'Mark packed',
                  ),
                ),
              ),
            OutlinedButton(
              onPressed: () => widget.openSection(1),
              child: const Text('Manage orders'),
            ),
            for (final r in snapshot.returns)
              line(
                'Return ${r['id']} · ${r['order_id']}',
                '${r['status']} · ${r['reason']}\n${sellerMoney((r['amount'] as num).toInt())} requested',
              ),
          ]),
          section('Notifications', [
            if (snapshot.notifications.isEmpty)
              const Text('You are all caught up.'),
            for (final n in snapshot.notifications)
              line(
                '${n['title']}',
                '${n['type']}',
                action: n['read'] == true
                    ? const Icon(Icons.done)
                    : IconButton(
                        tooltip: 'Mark notification read',
                        icon: const Icon(Icons.done_all),
                        onPressed: busy
                            ? null
                            : () =>
                                  perform(() => service.markRead('${n['id']}')),
                      ),
              ),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatInboxScreen(
                    connected: widget.commerce.connected,
                    seller: true,
                  ),
                ),
              ),
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Reply to buyer'),
            ),
          ], key: widget.notificationKey),
          section('Seller reports', [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : () => perform(() => export(false)),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print / save PDF'),
                ),
                FilledButton.icon(
                  onPressed: busy ? null : () => perform(() => export(true)),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Export / share PDF'),
                ),
              ],
            ),
          ]),
        ],
      ],
    );
  }
}
