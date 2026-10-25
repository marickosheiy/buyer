import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/design/lumear_theme.dart';
import 'package:flutter_application_1/seller/product_media.dart';
import 'package:flutter_application_1/seller/seller_commerce.dart';
import 'package:flutter_application_1/seller/seller_tools_screen.dart';

final class _PickedFile extends PlatformFile {
  _PickedFile(this.name, this.bytes, {this.reportedSize});
  @override
  final String name;
  final Uint8List bytes;
  final int? reportedSize;
  bool read = false;
  @override
  Uri get uri => Uri.file(name);
  @override
  int? lengthSync() => reportedSize ?? bytes.length;
  @override
  Future<int?> length() async => lengthSync();
  @override
  Future<Uint8List> readAsBytes() async {
    read = true;
    return bytes;
  }

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Picker extends FilePickerPlatform {
  PlatformFile? selected;
  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => selected;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Picker picker;
  final original = FilePickerPlatform.instance;
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII=',
  );
  setUp(() {
    picker = _Picker();
    FilePickerPlatform.instance = picker;
  });
  tearDown(() => FilePickerPlatform.instance = original);

  test(
    'Oversized videos are rejected before reading and cancellation is harmless',
    () async {
      final oversized = _PickedFile(
        'large.mp4',
        Uint8List(1),
        reportedSize: 21 * 1024 * 1024,
      );
      picker.selected = oversized;
      await expectLater(
        ProductMedia.pick(video: true, existing: []),
        throwsFormatException,
      );
      expect(oversized.read, isFalse);
      picker.selected = null;
      expect(await ProductMedia.pick(video: false, existing: []), isNull);
    },
  );

  testWidgets(
    'Seller attaches, saves, edits and removes photo and video on a narrow phone',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final commerce = SellerCommerce();
      addTearDown(commerce.dispose);
      final id = commerce.products.first.id;
      await tester.pumpWidget(
        MaterialApp(
          theme: lumearTheme(),
          home: Scaffold(
            body: SellerToolsScreen(commerce: commerce, section: 'Products'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit Handwoven market tote'));
      await tester.pumpAndSettle();
      picker.selected = _PickedFile('basket.png', png);
      await tester.tap(find.text('Add photo'));
      await tester.pumpAndSettle();
      expect(find.text('basket.png'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      picker.selected = _PickedFile(
        'basket.mp4',
        Uint8List.fromList([1, 2, 3]),
      );
      await tester.tap(find.text('Add video'));
      await tester.pumpAndSettle();
      expect(find.text('basket.mp4'), findsOneWidget);
      await tester.tap(find.text('Save product'));
      await tester.pumpAndSettle();
      SellerProduct saved() => commerce.products.firstWhere((p) => p.id == id);
      expect(saved().media.length, 2);
      expect(saved().media.first.bytes, png);
      expect(saved().media.last.isVideo, isTrue);
      await tester.tap(find.byType(Image).first);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      // A visibility toggle must retain the attachments.
      final toggle = find.byType(SwitchListTile).first;
      await Scrollable.ensureVisible(tester.element(toggle), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(saved().active, isFalse);
      expect(saved().media.length, 2);
      await tester.ensureVisible(find.byTooltip('Edit Handwoven market tote'));
      await tester.tap(find.byTooltip('Edit Handwoven market tote'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove basket.png'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save product'));
      await tester.pumpAndSettle();
      expect(saved().media.single.name, 'basket.mp4');
      final roundTrip = ProductMedia.fromProduct({
        'media': saved().media.map((m) => m.toJson()).toList(),
      });
      expect(roundTrip.single.bytes, [1, 2, 3]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
