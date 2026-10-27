import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'seller_income_report.dart';

Future<Uint8List> buildSellerIncomePdf(
  SellerIncomeReport report, {
  PdfPageFormat format = PdfPageFormat.a4,
}) async {
  final regular = await rootBundle.load('assets/fonts/roboto-regular.ttf');
  final bold = await rootBundle.load('assets/fonts/roboto-bold.ttf');
  final logoData = await rootBundle.load('assets/images/logo.png');
  final logo = pw.MemoryImage(
    logoData.buffer.asUint8List(logoData.offsetInBytes, logoData.lengthInBytes),
  );
  final document = pw.Document(
    title: 'Lumear Income & Earnings',
    author: report.shopName,
    theme: pw.ThemeData.withFont(
      base: pw.Font.ttf(regular),
      bold: pw.Font.ttf(bold),
    ),
  );
  final maroon = PdfColor.fromHex('#651D32');
  pw.Widget amount(String label, int cents) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [pw.Text(label), pw.Text(incomeMoney(cents))],
    ),
  );
  document.addPage(
    pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(32),
      maxPages: 1000,
      header: (_) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Image(logo, width: 48, height: 48, fit: pw.BoxFit.contain),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Text(
                'Income & Earnings',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: maroon,
                ),
              ),
            ),
          ],
        ),
      ),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Lumear • ${report.demo ? 'Demo / sample data' : report.shopName}',
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
      build: (_) => [
        pw.Text(report.shopName),
        pw.Text(report.period.label),
        pw.Text('Period: ${report.rangeLabel} (Philippine time)'),
        pw.Text('Generated ${incomeDateLabel(report.generatedAt)}'),
        if (report.demo)
          pw.Text(
            'DEMO REPORT — SAMPLE TRANSACTIONS',
            style: pw.TextStyle(color: maroon),
          ),
        pw.SizedBox(height: 18),
        amount('Gross merchandise sales', report.gross),
        amount(
          report.hasLegacyCommission
              ? 'Recorded commission'
              : 'Platform commission (10%)',
          report.commission,
        ),
        amount('Refunds', report.refunds),
        pw.Divider(),
        amount('Total net seller income', report.net),
        pw.Text('Completed orders: ${report.rows.length}'),
        pw.SizedBox(height: 14),
        pw.Text(
          'Shipping is ₱50.00 per shop order and is excluded from sales, commission and seller income. Seller share is 90% before refunds. This is a sales report, not a payout balance.',
          style: const pw.TextStyle(fontSize: 9),
        ),
        if (report.hasLegacyDates)
          pw.Text(
            'Orders without completion timestamps use placement dates.',
            style: const pw.TextStyle(fontSize: 9),
          ),
        if (report.hasLegacyCommission)
          pw.Text(
            'Some historical commissions differ from 10%. Recorded server amounts are preserved.',
            style: const pw.TextStyle(fontSize: 9),
          ),
        pw.SizedBox(height: 18),
        pw.Text(
          'Income Transaction History',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
        ),
        pw.SizedBox(height: 8),
        if (report.rows.isEmpty)
          pw.Text('No completed sales in this period.')
        else
          pw.TableHelper.fromTextArray(
            headers: [
              'Order / date',
              'Sales',
              'Commission',
              'Refunds',
              'Net income',
            ],
            data: [
              for (final row in report.rows)
                [
                  '${row.id}\n${incomeDateLabel(row.date)}',
                  incomeMoney(row.gross),
                  incomeMoney(row.commission),
                  incomeMoney(row.refund),
                  incomeMoney(row.net),
                ],
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: maroon),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.all(7),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              for (var column = 1; column < 5; column++)
                column: pw.Alignment.centerRight,
            },
            columnWidths: {0: const pw.FlexColumnWidth(1.6)},
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            border: null,
          ),
      ],
    ),
  );
  return document.save();
}
