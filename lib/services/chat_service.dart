import '../product_model.dart';
import 'api_service.dart';
import 'demo_accounts.dart';

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.mine,
    required this.date,
  });
  final String text;
  final bool mine;
  final DateTime date;

  factory ChatMessage.fromJson(dynamic row) => ChatMessage(
    text: row['text'] as String,
    mine: row['mine'] == true,
    date: DateTime.parse(row['date'] as String).toLocal(),
  );
}

class ChatThread {
  const ChatThread({required this.id, required this.name});
  final String id;
  final String name;
}

/// Demo conversations are scoped to local preview accounts.
/// Connected conversations always come from the authenticated shared service.
class ChatService {
  ChatService({required this.connected, this.seller = false})
    : _demoUser = DemoAccounts.current?.role == (seller ? 'seller' : 'buyer')
          ? DemoAccounts.current!.email
          : (seller ? 'seller@lumear.com' : 'lumear@gmail.com'),
      _demoName = DemoAccounts.current?.name ?? 'Demo buyer';
  final bool connected;
  final bool seller;
  final String _demoUser, _demoName;
  final List<ChatMessage> assistantHistory = [];
  static final Map<
    String,
    ({String shop, String buyer, String buyerName, String seller})
  >
  _demoShops = {};
  static final Map<String, List<({String text, bool seller, DateTime date})>>
  _demoMessages = {};

  Future<List<ChatThread>> threads() async {
    if (!connected) {
      return [
        for (final entry in _demoShops.entries)
          if (seller
              ? entry.value.seller == _demoUser
              : entry.value.buyer == _demoUser)
            ChatThread(
              id: entry.key,
              name: seller
                  ? '${entry.value.buyerName} · ${entry.value.shop}'
                  : entry.value.shop,
            ),
      ];
    }
    final data = await ApiService.get('/chat/threads');
    return [
      for (final row in data['threads'] as List)
        ChatThread(id: row['id'].toString(), name: row['name'] as String),
    ];
  }

  Future<ChatThread> openSeller(LumearProduct product) async {
    if (connected) {
      if (product.sellerId.isEmpty || product.sellerId == 'null') {
        throw const ApiException('This product has no seller contact yet.');
      }
      final row = await ApiService.post(
        '/chat/threads',
        body: {'seller_id': product.sellerId, 'product_id': product.id},
      );
      return ChatThread(id: row['id'].toString(), name: row['name'] as String);
    }
    if (seller) {
      throw const ApiException(
        'Open buyer conversations from your chat inbox.',
      );
    }
    final id = '$_demoUser|${product.shopName}';
    _demoShops[id] = (
      shop: product.shopName,
      buyer: _demoUser,
      buyerName: _demoName.isEmpty ? 'Demo buyer' : _demoName,
      seller: 'seller@lumear.com',
    );
    _demoMessages.putIfAbsent(id, () => []);
    return ChatThread(id: id, name: product.shopName);
  }

  Future<List<ChatMessage>> messages(ChatThread thread) async {
    if (!connected) {
      _checkDemoAccess(thread);
      return [
        for (final m in _demoMessages[thread.id] ?? [])
          ChatMessage(text: m.text, mine: m.seller == seller, date: m.date),
      ];
    }
    final data = await ApiService.get(
      '/chat/threads/${Uri.encodeComponent(thread.id)}/messages',
    );
    return [
      for (final row in data['messages'] as List) ChatMessage.fromJson(row),
    ];
  }

  Future<void> send(ChatThread thread, String text, String requestId) async {
    if (connected) {
      await ApiService.post(
        '/chat/threads/${Uri.encodeComponent(thread.id)}/messages',
        body: {'text': text, 'request_id': requestId},
      );
    } else {
      _checkDemoAccess(thread);
      (_demoMessages[thread.id] ??= []).add((
        text: text,
        seller: seller,
        date: DateTime.now(),
      ));
    }
  }

  void _checkDemoAccess(ChatThread thread) {
    final entry = _demoShops[thread.id];
    if (entry == null ||
        (seller ? entry.seller != _demoUser : entry.buyer != _demoUser)) {
      throw const ApiException(
        'This conversation belongs to another demo account.',
      );
    }
  }

  Future<String> askAssistant(List<ChatMessage> history, String text) async {
    if (connected) {
      final data = await ApiService.post(
        '/chat/assistant',
        body: {
          'messages': [
            for (final m in history.skip(
              history.length > 20 ? history.length - 20 : 0,
            ))
              {'role': m.mine ? 'user' : 'assistant', 'content': m.text},
            {'role': 'user', 'content': text},
          ],
        },
      );
      final reply = data['reply'];
      if (reply is! String || reply.trim().isEmpty) {
        throw const ApiException(
          'The assistant did not return a reply. Please try again.',
        );
      }
      return reply;
    }
    final query = text.toLowerCase();
    if (query.contains('order') ||
        query.contains('deliver') ||
        query.contains('track')) {
      return 'Open Orders to see the status shown for your purchase. For dispatch or delivery questions, open the product and tap Chat with seller. I cannot change or verify orders in this preview.';
    }
    if (query.contains('return') ||
        query.contains('refund') ||
        query.contains('cancel')) {
      return 'Open the order details to check available actions, or contact the seller about a return or refund. Eligibility depends on the order and shop policy; this preview cannot approve a request.';
    }
    if (query.contains('seller') || query.contains('chat')) {
      return 'Open a product, then tap Chat with seller. Your conversations appear under Messages. In demo mode you can switch to the seller demo account to reply on this device.';
    }
    return 'I can help you find your way around Lumear. Try asking about orders, delivery, returns, or contacting a seller. These are sample replies; AI-generated answers will be available when the shared service is connected.';
  }
}
