import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/design/lumear_theme.dart';
import 'package:flutter_application_1/widgets/email_verification_form.dart';

void main() {
  testWidgets(
    'Email OTP form waits for the server to verify the entered code',
    (tester) async {
      String? proof;
      var sent = 0, checked = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: lumearTheme(),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(20),
                  child: EmailVerificationForm(
                    email: 'buyer@example.invalid',
                    onVerified: (value) => proof = value,
                  ),
                ),
              ),
            ),
          );
          expect(find.text('Verify email'), findsNothing);
          await tester.tap(find.text('Send verification code'));
          await tester.pumpAndSettle();
          expect(sent, 1);
          expect(proof, isNull);
          await tester.enterText(find.byType(TextField), '000000');
          await tester.tap(find.widgetWithText(FilledButton, 'Verify email'));
          await tester.pumpAndSettle();
          expect(proof, isNull);
          expect(find.text('Incorrect code.'), findsOneWidget);
          await tester.enterText(find.byType(TextField), '654321');
          await tester.tap(find.widgetWithText(FilledButton, 'Verify email'));
          await tester.pumpAndSettle();
          expect(proof, 'single-use-email-proof');
          expect(checked, 2);
          expect(find.text('Send verification code'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        () => MockClient((request) async {
          final body = jsonDecode(request.body);
          if (request.url.path == '/api/auth/email/send') {
            expect(body['email'], 'buyer@example.invalid');
            expect(body['purpose'], 'registration');
            sent++;
            return http.Response(
              jsonEncode({'challenge_id': '42', 'message': 'Code sent.'}),
              200,
            );
          }
          expect(request.url.path, '/api/auth/email/verify');
          expect(body['challenge_id'], '42');
          checked++;
          return http.Response(
            jsonEncode(
              body['code'] == '654321'
                  ? {
                      'verified': true,
                      'verification_token': 'single-use-email-proof',
                      'message': 'Your email is verified.',
                    }
                  : {'verified': false, 'message': 'Incorrect code.'},
            ),
            200,
          );
        }),
      );
    },
  );
  testWidgets(
    'Closing an OTP form during delivery does not update a disposed widget',
    (tester) async {
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: EmailVerificationForm(
                  email: 'buyer@example.invalid',
                  onVerified: (_) {},
                ),
              ),
            ),
          );
          await tester.tap(find.text('Send verification code'));
          await tester.pump();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull);
        },
        () => MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return http.Response(
            jsonEncode({'challenge_id': '9', 'message': 'Code sent.'}),
            200,
          );
        }),
      );
    },
  );
}
