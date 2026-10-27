import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../services/top_notification.dart';
import 'seller_commerce.dart';
import 'seller_income_pdf.dart';
import 'seller_income_report.dart';

class SellerIncomePanel extends StatefulWidget {
  const SellerIncomePanel({
    super.key,
    required this.commerce,
    this.shopName = 'Lumear Seller',
  });
  final SellerCommerce commerce;
  final String shopName;

  @override
  State<SellerIncomePanel> createState() => _SellerIncomePanelState();
}

class _SellerIncomePanelState extends State<SellerIncomePanel> {
  EarningsPeriod period = EarningsPeriod.month;
  bool exporting = false;
  DateTimeRange? customRange;

  Future<void> selectDateRange() async {
    final now = manilaTime(DateTime.now());
    final today = DateTime(now.year, now.month, now.day);
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: today,
      initialDateRange:
          customRange ??
          DateTimeRange(start: DateTime(today.year, 1, 1), end: today),
      helpText: 'Select earnings dates',
      saveText: 'Apply dates',
    );
    if (!mounted || selected == null) return;
    setState(() {
      customRange = selected;
      period = EarningsPeriod.custom;
    });
  }

  Future<void> export(SellerIncomeReport report, {required bool print}) async {
    if (exporting) return;
    setState(() => exporting = true);
    try {
      bool finished;
      if (print) {
        finished = await Printing.layoutPdf(
          name: report.filename,
          onLayout: (format) => buildSellerIncomePdf(report, format: format),
        );
      } else {
        final bytes = await buildSellerIncomePdf(report);
        if (!mounted) return;
        final saved = await FilePicker.saveFile(
          fileName: report.filename,
          bytes: bytes,
          mimeType: 'application/pdf',
          dialogTitle: 'Save income report',
        );
        finished = saved != null;
      }
      if (mounted && finished) {
        showTopNotification(
          context,
          SnackBar(
            content: Text(
              print ? 'Report sent to print.' : 'Income report PDF saved.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        showTopNotification(
          context,
          const SnackBar(
            content: Text('Unable to export the report. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Widget metric(String label, String value, {Color? color}) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.commerce,
    builder: (context, _) {
      final commerce = widget.commerce;
      final report = SellerIncomeReport(
        orders: commerce.orders,
        period: period,
        generatedAt: DateTime.now(),
        demo: !commerce.connected,
        shopName: widget.shopName,
        customStart: customRange?.start,
        customEnd: customRange?.end,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final option in const [
                EarningsPeriod.week,
                EarningsPeriod.month,
                EarningsPeriod.allTime,
              ])
                Expanded(
                  child: TextButton(
                    onPressed: exporting
                        ? null
                        : () => setState(() => period = option),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 10,
                      ),
                      backgroundColor: period == option
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                    ),
                    child: Text(
                      option.label,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: exporting
                    ? null
                    : () => setState(() => period = EarningsPeriod.yearToDate),
                style: TextButton.styleFrom(
                  backgroundColor: period == EarningsPeriod.yearToDate
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                ),
                child: const Text('Year to Date'),
              ),
              OutlinedButton.icon(
                onPressed: exporting ? null : selectDateRange,
                style: OutlinedButton.styleFrom(
                  backgroundColor: period == EarningsPeriod.custom
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                ),
                icon: const Icon(Icons.date_range_outlined),
                label: const Text('Custom date range'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(report.rangeLabel, key: const ValueKey('earnings-date-range')),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Net Seller Income'),
                  const SizedBox(height: 8),
                  Text(
                    incomeMoney(report.net),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF219653),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    report.hasLegacyCommission
                        ? 'After recorded commission and refunds.'
                        : 'After 10% platform commission. Seller share: 90% before refunds.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 280
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: width,
                    child: metric('Gross Sales', incomeMoney(report.gross)),
                  ),
                  SizedBox(
                    width: width,
                    child: metric(
                      report.hasLegacyCommission
                          ? 'Recorded Commission'
                          : 'Commission (10%)',
                      incomeMoney(report.commission),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: metric('Completed Orders', '${report.rows.length}'),
                  ),
                  SizedBox(
                    width: width,
                    child: metric(
                      'Low Stock Alert',
                      '5 or less',
                      color: Colors.deepOrange,
                    ),
                  ),
                ],
              );
            },
          ),
          if (report.refunds != 0) ...[
            const SizedBox(height: 12),
            metric('Refunds deducted', incomeMoney(report.refunds)),
          ],
          const SizedBox(height: 16),
          const Text(
            'Fixed shipping: ₱50.00 per shop order. Shipping is excluded from seller income.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: exporting
                    ? null
                    : () => export(report, print: false),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Export PDF'),
              ),
              OutlinedButton.icon(
                onPressed: exporting ? null : () => export(report, print: true),
                icon: const Icon(Icons.print_outlined),
                label: const Text('Print'),
              ),
            ],
          ),
          if (exporting) const LinearProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Income Transaction History',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (report.rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No completed sales in this period.'),
            ),
          for (final row in report.rows)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.id,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(incomeDateLabel(row.date)),
                    const SizedBox(height: 8),
                    Text('Sales: ${incomeMoney(row.gross)}'),
                    Text('Commission: ${incomeMoney(row.commission)}'),
                    if (row.refund != 0)
                      Text('Refunds: ${incomeMoney(row.refund)}'),
                    Text(
                      'Net income: ${incomeMoney(row.net)}',
                      style: const TextStyle(
                        color: Color(0xFF219653),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Filters use Philippine time. This Week starts on Monday. Only completed sales are included.',
          ),
          if (report.hasLegacyDates)
            const Text(
              'Orders without completion timestamps use placement dates.',
            ),
          if (report.hasLegacyCommission)
            const Text(
              'Some historical commissions differ from 10%. Recorded server amounts are preserved.',
            ),
          if (report.demo)
            const Text(
              'Demo report · Sample transactions only. No money is transferred.',
            ),
          const SizedBox(height: 24),
        ],
      );
    },
  );
}
