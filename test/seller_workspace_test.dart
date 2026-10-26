import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/design/lumear_theme.dart';
import 'package:flutter_application_1/design/brand_art.dart';
import 'package:flutter_application_1/login_page.dart';
import 'package:flutter_application_1/seller/seller_dashboard_screen.dart';

void main() {
  testWidgets(
    'Seller can manage a listing and prepare an order on a narrow phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(theme: lumearTheme(), home: const SellerDashboardScreen()),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Products').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(FilledButton, 'Add product'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Save product'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('This field is required.'), findsWidgets);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Test basket');
      await tester.enterText(fields.at(1), '125.50');
      await tester.enterText(fields.at(2), '7');
      final category = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(category);
      await tester.tap(category);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home & Living').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save product'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Test basket'), findsOneWidget);
      expect(find.text('₱125.50 · Home & Living'), findsOneWidget);
      await tester.tap(find.text('Orders').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('SO-1001'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Mark ready for pickup'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Ready for pickup · ₱900.00'), findsOneWidget);
      await tester.tap(find.text('Earnings').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('₱1187.50'), findsOneWidget);
      final breakdown = find.text('Net earnings');
      await tester.scrollUntilVisible(
        breakdown,
        150,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Seller profile updates setup progress and clears on logout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: lumearTheme(), home: const SellerDashboardScreen()),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<LumearDock>(find.byType(LumearDock)).destinations.length,
      5,
    );
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Edit shop profile'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Please enter your seller name.'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Maria');
    await tester.enterText(fields.at(1), 'Maria Handmade');
    await tester.enterText(fields.at(2), 'Handmade everyday favorites.');
    await tester.ensureVisible(fields.at(3));
    await tester.enterText(fields.at(3), 'maria@example.com');
    await tester.ensureVisible(fields.at(4));
    await tester.enterText(fields.at(4), 'abc12345678901999');
    expect(
      tester.widget<TextFormField>(fields.at(4)).controller!.text,
      '12345678901',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter an 11-digit mobile number starting with 09.'),
      findsOneWidget,
    );
    await tester.enterText(fields.at(4), '09171234567');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Maria Handmade'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final progress = find.text('3 of 3 steps complete');
    await tester.scrollUntilVisible(
      progress,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(progress, findsOneWidget);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, 'Log out'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Log out'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(SellerDashboardScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
