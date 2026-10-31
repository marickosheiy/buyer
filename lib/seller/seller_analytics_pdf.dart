import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

import 'seller_analytics.dart';

Future<Uint8List> buildSellerAnalyticsPdf({
  required SellerAnalyticsSnapshot snapshot,
  required SellerAnalyticsRange selectedRange,
  required String shopName,
  required bool demo,
}) async {
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/roboto-regular.ttf'),
  );
  final doc = pw.Document(theme: pw.ThemeData.withFont(base: font));
  pw.Widget table(List<String> headers, List<List<String>> rows) =>
      pw.TableHelper.fromTextArray(headers: headers, data: rows);
  doc.addPage(
    pw.MultiPage(
      maxPages: 1000,
      build: (_) => [
        pw.Text(
          '$shopName — Seller report',
          style: const pw.TextStyle(fontSize: 22),
        ),
        pw.Text('${selectedRange.label} · Philippine time'),
        pw.Text('Previous: ${selectedRange.previous.label}'),
        if (demo) pw.Text('DEMO / SAMPLE DATA'),
        pw.Text(
          'Completed merchandise sales; shipping excluded. Earnings deduct recorded commission and refunds. Conversion = completed orders / shop visits.',
        ),
        table(
          ['Metric', 'Value', 'Comparison'],
          [
            for (final e in snapshot.current.entries)
              [
                e.key,
                analyticsValue(e.key, e.value),
                analyticsChange(e.key, snapshot),
              ],
          ],
        ),
        pw.Text('Revenue by day'),
        table(
          ['Date', 'Revenue'],
          [
            for (final r in snapshot.daily)
              ['${r['date']}', analyticsValue('revenue', r['revenue'] as num)],
          ],
        ),
        pw.Text('Product performance'),
        table(
          [
            'Product',
            'Views',
            'Cart %',
            'Purchases',
            'Units',
            'Revenue',
            'Stock',
          ],
          [
            for (final r in snapshot.products)
              [
                for (final k in [
                  'name',
                  'views',
                  'cart_rate',
                  'purchases',
                  'units',
                  'revenue',
                  'stock',
                ])
                  k == 'revenue' ? analyticsValue(k, r[k] as num) : '${r[k]}',
              ],
          ],
        ),
        pw.Text(
          'Customers: ${snapshot.customers['new']} new; ${snapshot.customers['returning']} returning; ${snapshot.customers['repeat']} repeat buyers.',
        ),
        for (final r in snapshot.customers['locations'] as List)
          pw.Text('${r['name']}: ${r['buyers']} buyers'),
        pw.Text('Promotion performance'),
        table(
          [
            'Promotion',
            'Views',
            'Claims',
            'Redemptions',
            'Revenue',
            'Conversion',
          ],
          [
            for (final r in snapshot.promotions)
              [
                '${r['name']}',
                '${r['views']}',
                '${r['claims']}',
                '${r['redemptions']}',
                analyticsValue('revenue', r['revenue'] as num),
                analyticsValue('conversion', r['conversion'] as num),
              ],
          ],
        ),
        pw.Text('Current order snapshot'),
        for (final e in snapshot.operations.entries)
          pw.Text('${e.key}: ${e.value}'),
        for (final r in snapshot.returns)
          pw.Text(
            'Return ${r['id']} · ${r['order_id']} · ${r['status']} · ${r['reason']}',
          ),
      ],
    ),
  );
  return doc.save();
}
