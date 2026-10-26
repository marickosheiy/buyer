import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/address_book_screen.dart';
import 'package:flutter_application_1/design/lumear_theme.dart';
import 'package:flutter_application_1/services/mobile_number.dart';

void main() {
  test(
    'Local mobile validation and conversion of existing international numbers',
    () {
      expect(MobileNumber.isValid('09171234567'), isTrue);
      for (final value in [
        '',
        '0917123456',
        '091712345678',
        '12345678901',
        '09abcdefgh9',
        '+639171234567',
      ]) {
        expect(MobileNumber.isValid(value), isFalse, reason: value);
      }
      expect(MobileNumber.forEditing('+63 917-123-4567'), '09171234567');
      expect(MobileNumber.forEditing('639171234567'), '09171234567');
      expect(MobileNumber.forEditing('0917 123 4567'), '09171234567');
      expect(MobileNumber.forEditing('invalid'), 'invalid');
    },
  );

  testWidgets(
    'Address contact filters pasted characters and rejects a short number',
    (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(theme: lumearTheme(), home: const AddressFormScreen()),
        );
        await tester.pumpAndSettle();
        final phone = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.keyboardType == TextInputType.phone,
        );
        await tester.ensureVisible(phone);
        await tester.enterText(phone, 'letters09 171-234(567)999');
        expect(tester.widget<TextField>(phone).controller!.text, '09171234567');
        await tester.enterText(phone, '0917');
        final save = find.byWidgetPredicate(
          (widget) => widget is ElevatedButton,
        );
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.text(MobileNumber.error), findsOneWidget);
        expect(find.byType(AddressFormScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, () => MockClient((_) async => http.Response('[]', 200)));
    },
  );
}
