import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/design/lumear_theme.dart';
import 'package:flutter_application_1/product_model.dart';
import 'package:flutter_application_1/screen/chat_screen.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/chat_service.dart';

void main() {
  setUp(() {
    ApiService.baseUrl = 'https://integration.example.invalid/api';
    ApiService.setToken('chat-session');
  });
  tearDown(() {
    ApiService.baseUrl = '';
    ApiService.setToken(null);
  });

  test(
    'Demo buyer and seller see opposite sides of the same conversation',
    () async {
      final buyer = ChatService(connected: false);
      final seller = ChatService(connected: false, seller: true);
      final thread = await buyer.openSeller(sampleLumearProducts.first);
      final before = (await buyer.messages(thread)).length;
      await buyer.send(thread, 'Is this available?', 'demo-1');
      final sellerThread = (await seller.threads()).firstWhere(
        (t) => t.id == thread.id,
      );
      expect((await seller.messages(sellerThread)).last.mine, isFalse);
      await seller.send(sellerThread, 'Yes, it is available.', 'demo-2');
      final messages = await buyer.messages(thread);
      expect(messages.length, before + 2);
      expect(messages[messages.length - 2].mine, isTrue);
      expect(messages.last.mine, isFalse);
      expect(messages.last.text, 'Yes, it is available.');
    },
  );

  test(
    'Connected chat authenticates and exchanges thread and message payloads',
    () async {
      final service = ChatService(connected: true);
      const product = LumearProduct(
        id: 'p1',
        sellerId: 's1',
        name: 'Basket',
        description: 'A basket',
        category: 'Home',
        price: 125,
        imageUrl: '',
        icon: Icons.shopping_bag,
      );
      await http.runWithClient(
        () async {
          final thread = await service.openSeller(product);
          expect(thread.id, 't1');
          expect((await service.threads()).single.name, 'Basket shop');
          await service.send(thread, 'Hello', 'stable-request-id');
          final messages = await service.messages(thread);
          expect(messages.single.text, 'Hello');
          expect(messages.single.mine, isTrue);
        },
        () => MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer chat-session');
          final path = request.url.path;
          if (path == '/api/chat/threads' && request.method == 'POST') {
            expect(jsonDecode(request.body), {
              'seller_id': 's1',
              'product_id': 'p1',
            });
            return http.Response('{"id":"t1","name":"Basket shop"}', 200);
          }
          if (path == '/api/chat/threads') {
            return http.Response(
              '{"threads":[{"id":"t1","name":"Basket shop"}]}',
              200,
            );
          }
          expect(path, '/api/chat/threads/t1/messages');
          if (request.method == 'POST') {
            expect(jsonDecode(request.body), {
              'text': 'Hello',
              'request_id': 'stable-request-id',
            });
            return http.Response('{}', 201);
          }
          return http.Response(
            '{"messages":[{"text":"Hello","mine":true,"date":"2026-10-24T06:00:00Z"}]}',
            200,
          );
        }),
      );
    },
  );

  testWidgets(
    'Failed sends retain the draft and reuse the request ID on retry',
    (tester) async {
      var sends = 0;
      String? requestId;
      var delivered = false;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: lumearTheme(),
              home: ChatScreen(
                service: ChatService(connected: true),
                thread: const ChatThread(id: 'retry', name: 'Seller'),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), 'Can you help?');
          await tester.tap(find.byTooltip('Send message'));
          await tester.pumpAndSettle();
          expect(find.text('Please try again.'), findsOneWidget);
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            'Can you help?',
          );
          await tester.tap(find.text('Retry'));
          await tester.pumpAndSettle();
          expect(sends, 2);
          expect(find.byType(SelectableText), findsOneWidget);
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            isEmpty,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        () => MockClient((request) async {
          if (request.method == 'POST') {
            sends++;
            final body = jsonDecode(request.body);
            requestId ??= body['request_id'];
            expect(body['request_id'], requestId);
            if (sends == 1) {
              return http.Response('{"message":"Please try again."}', 503);
            }
            delivered = true;
            return http.Response('{}', 201);
          }
          return http.Response(
            jsonEncode({
              'messages': delivered
                  ? [
                      {
                        'text': 'Can you help?',
                        'mine': true,
                        'date': '2026-10-24T06:00:00Z',
                      },
                    ]
                  : [],
            }),
            200,
          );
        }),
      );
    },
  );

  testWidgets('AI sends conversation history and preserves it when reopened', (
    tester,
  ) async {
    final service = ChatService(connected: true);
    var calls = 0;
    await http.runWithClient(
      () async {
        Future<void> mount() => tester.pumpWidget(
          MaterialApp(
            theme: lumearTheme(),
            home: ChatScreen(service: service),
          ),
        );
        await mount();
        await tester.tap(find.text('Track my order'));
        await tester.pumpAndSettle();
        expect(find.text('Check your Orders tab.'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await mount();
        await tester.pumpAndSettle();
        expect(find.text('Check your Orders tab.'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'And delivery?');
        await tester.tap(find.byTooltip('Send message'));
        await tester.pumpAndSettle();
        expect(calls, 2);
        expect(tester.takeException(), isNull);
      },
      () => MockClient((request) async {
        calls++;
        expect(request.url.path, '/api/chat/assistant');
        final messages = jsonDecode(request.body)['messages'] as List;
        expect(messages.length, calls == 1 ? 1 : 3);
        if (calls == 2) {
          expect(messages[1], {
            'role': 'assistant',
            'content': 'Check your Orders tab.',
          });
          expect(messages.last, {'role': 'user', 'content': 'And delivery?'});
        }
        return http.Response('{"reply":"Check your Orders tab."}', 200);
      }),
    );
  });

  testWidgets('Demo assistant is labeled and fits a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: lumearTheme(),
        home: ChatScreen(service: ChatService(connected: false)),
      ),
    );
    await tester.tap(find.text('Track my order'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sample replies, not live AI'), findsOneWidget);
    expect(find.textContaining('Open Orders'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Inbox refreshes when the buyer returns to its tab', (
    tester,
  ) async {
    Future<void> showInbox(bool active) => tester.pumpWidget(
      MaterialApp(
        theme: lumearTheme(),
        home: ChatInboxScreen(connected: false, active: active),
      ),
    );
    await showInbox(false);
    await tester.pumpAndSettle();
    const product = LumearProduct(
      id: 'inbox-refresh',
      name: 'New product',
      description: '',
      category: 'Home',
      price: 1,
      imageUrl: '',
      icon: Icons.shopping_bag,
      shopName: 'Inbox refresh shop',
    );
    await ChatService(connected: false).openSeller(product);
    await showInbox(true);
    await tester.pumpAndSettle();
    expect(find.text('Inbox refresh shop'), findsOneWidget);
    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
