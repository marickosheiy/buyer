import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';
import 'package:flutter_application_1/design/lumear_theme.dart';
import 'package:flutter_application_1/seller/seller_commerce.dart';
import 'package:flutter_application_1/seller/seller_income_panel.dart';

class TestFilePicker extends FilePickerPlatform {
  Completer<void> called = Completer<void>();
  Uint8List? pdf;
  String? filename;
  bool cancel = false;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    pdf = bytes;
    filename = fileName;
    expect(mimeType, 'application/pdf');
    called.complete();
    return cancel ? null : Uri.file('income.pdf');
  }
}

class TestPrinter extends PrintingPlatform {
  final called = Completer<void>();
  Uint8List? pdf;
  String? filename;

  @override
  Future<bool> layoutPdf(
    Printer? printer,
    LayoutCallback onLayout,
    String name,
    PdfPageFormat format,
    bool dynamicLayout,
    bool usePrinterSettings,
    OutputType outputType,
    bool forceCustomPrintPaper,
    bool windowsModernDialog,
  ) async {
    filename = name;
    pdf = await onLayout(PdfPageFormat.a4);
    called.complete();
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'narrow earnings screen filters and exports the displayed report',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final commerce = SellerCommerce();
      addTearDown(commerce.dispose);
      final picker = TestFilePicker();
      final printer = TestPrinter();
      final previousPicker = FilePickerPlatform.instance;
      final previousPrinter = PrintingPlatform.instance;
      FilePickerPlatform.instance = picker;
      PrintingPlatform.instance = printer;
      addTearDown(() {
        FilePickerPlatform.instance = previousPicker;
        PrintingPlatform.instance = previousPrinter;
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: lumearTheme(dark: true),
          home: RepaintBoundary(
            key: const ValueKey('income-preview'),
            child: Scaffold(
              appBar: AppBar(title: const Text('Income & Earnings')),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SellerIncomePanel(commerce: commerce),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Year to Date'));
      await tester.pumpAndSettle();
      final dates = find.byKey(const ValueKey('earnings-date-range'));
      expect((tester.widget<Text>(dates)).data, startsWith('Jan 1,'));
      await tester.tap(find.text('Custom date range'));
      await tester.pumpAndSettle();
      expect(find.text('Select earnings dates'), findsOneWidget);
      await tester.tap(find.text('Apply dates'));
      await tester.pumpAndSettle();
      expect((tester.widget<Text>(dates)).data, startsWith('Jan 1,'));
      await tester.tap(find.text('Custom date range'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect((tester.widget<Text>(dates)).data, startsWith('Jan 1,'));
      await tester.tap(find.text('All Time'));
      await tester.pumpAndSettle();
      expect(find.text('₱1,125.00'), findsOneWidget);
      expect(find.text('₱125.00'), findsOneWidget);
      expect(tester.takeException(), isNull);

      if (const bool.fromEnvironment('WRITE_REPORT_PREVIEWS')) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('income-preview')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('tmp/pdfs/earnings-dark-phone.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await tester.ensureVisible(find.text('Custom date range'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom date range'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply dates'));
      await tester.pumpAndSettle();

      Future<void> finishExport(String label, Completer<void> signal) async {
        await tester.tap(find.text(label));
        for (var i = 0; i < 100 && !signal.isCompleted; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(
          signal.isCompleted,
          isTrue,
          reason: 'Native $label handler was not reached',
        );
        await tester.pumpAndSettle();
      }

      await tester.ensureVisible(find.text('Export PDF'));
      await tester.pumpAndSettle();
      await finishExport('Export PDF', picker.called);
      expect(String.fromCharCodes(picker.pdf!.take(5)), '%PDF-');
      expect(
        picker.filename,
        matches(
          RegExp(
            r'^lumear-income-custom-\d{4}-01-01-to-\d{4}-\d{2}-\d{2}\.pdf$',
          ),
        ),
      );
      expect(find.text('Income report PDF saved.'), findsOneWidget);

      await finishExport('Print', printer.called);
      expect(String.fromCharCodes(printer.pdf!.take(5)), '%PDF-');
      expect(printer.filename, picker.filename);
      expect(find.text('Report sent to print.'), findsOneWidget);

      picker.cancel = true;
      picker.called = Completer<void>();
      await finishExport('Export PDF', picker.called);
      expect(find.text('Income report PDF saved.'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
