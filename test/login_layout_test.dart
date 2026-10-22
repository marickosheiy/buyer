import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/design/lumear_theme.dart';
import 'package:flutter_application_1/login_page.dart';

void main() {
  for (final size in [const Size(360, 800), const Size(744, 1190)]) {
    testWidgets('Login fills the screen at $size and keeps account selection', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: lumearTheme(),
          home: const LoginPage(useBackend: false),
        ),
      );
      await tester.pumpAndSettle();
      final photo = find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/image_login1.jpg',
      );
      expect(tester.getRect(photo).left, 0);
      expect(tester.getSize(photo).width, size.width);
      final whitePanel = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints?.minHeight != null &&
            widget.constraints!.minHeight > 100 &&
            widget.decoration is BoxDecoration,
      );
      expect(
        tester.getRect(whitePanel).bottom,
        greaterThanOrEqualTo(size.height - 1),
      );
      final buyer = find.widgetWithText(ChoiceChip, 'Buyer');
      await tester.ensureVisible(buyer);
      await tester.tap(buyer);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(buyer).selected, isTrue);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'lumear@gmail.com',
      );
      expect(tester.takeException(), isNull);
    });
  }
}
