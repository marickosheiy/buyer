import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/design/lumear_theme.dart';
import 'package:flutter_application_1/services/top_notification.dart';

void main() {
  testWidgets('top notice respects safe area and lets taps through its text', (
    tester,
  ) async {
    late BuildContext screen;
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: lumearTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 24),
            viewInsets: const EdgeInsets.only(bottom: 280),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) {
            screen = context;
            return Scaffold(
              body: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const SizedBox.expand(),
              ),
              bottomNavigationBar: TextButton(
                onPressed: () => taps++,
                child: const Text('Checkout'),
              ),
            );
          },
        ),
      ),
    );
    final handle = showTopNotification(
      screen,
      const SnackBar(content: Text('Saved successfully')),
    )!;
    await tester.pump();
    final notice = find.byKey(const ValueKey('top-notification'));
    expect(tester.getTopLeft(notice).dy, 24 + kToolbarHeight + 8);
    expect(tester.getRect(notice).bottom, lessThan(200));
    expect(find.byType(SnackBar), findsNothing);
    await tester.tapAt(tester.getCenter(find.text('Saved successfully')));
    expect(taps, 1);
    await tester.tap(find.text('Checkout'));
    expect(taps, 2);
    await tester.pump(const Duration(seconds: 4));
    expect(notice, findsNothing);
    handle.dismiss();
  });

  testWidgets('new notice replaces old notice and only its action takes taps', (
    tester,
  ) async {
    late BuildContext screen;
    var taps = 0;
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            screen = context;
            return Scaffold(
              body: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const SizedBox.expand(),
              ),
            );
          },
        ),
      ),
    );
    showTopNotification(screen, const SnackBar(content: Text('Old message')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    showTopNotification(
      screen,
      SnackBar(
        content: const Text('Try again'),
        action: SnackBarAction(label: 'RETRY', onPressed: () => retries++),
      ),
    );
    await tester.pump();
    expect(find.text('Old message'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Try again'), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.text('Try again')));
    expect(taps, 1);
    await tester.tap(find.text('RETRY'));
    await tester.pump();
    expect(retries, 1);
    expect(taps, 1);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('notice clears when its route is replaced', (tester) async {
    late BuildContext screen;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            screen = context;
            return const Scaffold(body: Text('First screen'));
          },
        ),
      ),
    );
    showTopNotification(screen, const SnackBar(content: Text('Transient')));
    await tester.pump();
    Navigator.of(screen).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Next screen')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Transient'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
