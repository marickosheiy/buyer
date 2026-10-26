import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../design/lumear_theme.dart';
import '../product_model.dart';
import '../services/chat_service.dart';

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({
    super.key,
    required this.connected,
    this.seller = false,
    this.active = true,
  });
  final bool connected;
  final bool seller;
  final bool active;

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  late final service = ChatService(
    connected: widget.connected,
    seller: widget.seller,
  );
  List<ChatThread> threads = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void didUpdateWidget(covariant ChatInboxScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) refresh();
  }

  Future<void> refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await service.threads();
      if (mounted) setState(() => threads = result);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> open([ChatThread? thread]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(service: service, thread: thread),
      ),
    );
    if (mounted) refresh();
  }

  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            tooltip: 'Refresh messages',
            onPressed: loading ? null : refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Lumear AI assistant'),
              subtitle: Text(
                widget.connected
                    ? 'Shopping questions and app help'
                    : 'Preview · sample replies',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.seller ? 'Buyer conversations' : 'Seller conversations',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (!widget.connected)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Demo messages stay on this device until restart. Sample shop conversations can be answered from the built-in seller demo account.',
              ),
            ),
          if (loading) const LinearProgressIndicator(),
          if (error != null) ...[
            Text(error!),
            TextButton(onPressed: refresh, child: const Text('Retry')),
          ],
          if (!loading && error == null && threads.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Text(
                widget.seller ? 'Buyer messages will appear here.' : 'No conversations yet. Open a product and tap Chat with seller.',
              ),
            ),
          for (final thread in threads)
            Card(
              child: ListTile(
                leading: Icon(
                  widget.seller
                      ? Icons.person_outline
                      : Icons.storefront_outlined,
                ),
                title: Text(thread.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(thread),
              ),
            ),
        ],
      ),
    ),
  );
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.service,
    this.thread,
    this.product,
  });
  final ChatService service;
  final ChatThread? thread;
  final LumearProduct? product;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  ChatThread? thread;
  List<ChatMessage> messages = [];
  bool loading = false, sending = false;
  bool fetching = false;
  String? error;
  Timer? poll;
  bool get ai => widget.thread == null && widget.product == null;
  String? pendingText, pendingId;

  @override
  void initState() {
    super.initState();
    thread = widget.thread;
    if (ai) messages = widget.service.assistantHistory;
    load();
    if (widget.service.connected && !ai) {
      poll = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!loading &&
            !sending &&
            error == null &&
            ModalRoute.of(context)?.isCurrent == true) {
          load(quiet: true);
        }
      });
    }
  }

  @override
  void dispose() {
    poll?.cancel();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && scroll.hasClients) {
      scroll.jumpTo(scroll.position.maxScrollExtent);
    }
  });

  Future<void> load({bool quiet = false}) async {
    if (ai || fetching) return;
    fetching = true;
    if (!quiet) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      thread ??= await widget.service.openSeller(widget.product!);
      final result = await widget.service.messages(thread!);
      if (!mounted) return;
      final changed = result.length != messages.length;
      setState(() {
        messages = result;
        error = null;
      });
      if (changed) toBottom();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      fetching = false;
      if (mounted && !quiet) setState(() => loading = false);
    }
  }

  Future<void> send() async {
    final text = input.text.trim();
    if (sending || loading || text.isEmpty || (!ai && thread == null)) return;
    setState(() {
      sending = true;
      error = null;
    });
    try {
      if (ai) {
        final reply = await widget.service.askAssistant(
          messages.length > 20
              ? messages.sublist(messages.length - 20)
              : messages,
          text,
        );
        if (!mounted) return;
        setState(
          () => messages.addAll([
            ChatMessage(text: text, mine: true, date: DateTime.now()),
            ChatMessage(text: reply, mine: false, date: DateTime.now()),
          ]),
        );
      } else {
        if (pendingText != text) {
          pendingText = text;
          pendingId =
              '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
        }
        await widget.service.send(thread!, text, pendingId!);
        pendingText = pendingId = null;
        if (!mounted) return;
      }
      input.clear();
      if (!ai) await load(quiet: true);
      toBottom();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => Scaffold(
      appBar: AppBar(
        title: Text(
          ai
              ? 'Lumear AI assistant'
              : thread?.name ?? widget.product?.shopName ?? 'Conversation',
        ),
        actions: [
          if (!ai)
            IconButton(
              tooltip: 'Refresh conversation',
              onPressed: loading || sending ? null : load,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: LumearColors.field,
              child: Text(
                !widget.service.connected
                    ? (ai
                          ? 'Preview assistant · sample replies, not live AI.'
                          : 'Demo conversation · messages are local to this device.')
                    : (ai
                          ? 'AI answers can be mistaken. Confirm order and shop details with your seller.'
                          : 'Chat directly with the seller or buyer. Pull in new replies with Refresh.'),
                style: TextStyle(color: LumearColors.ink, fontSize: 12),
              ),
            ),
            if (widget.product != null)
              ListTile(
                dense: true,
                leading: const Icon(Icons.shopping_bag_outlined),
                title: Text(widget.product!.name),
                subtitle: Text(widget.product!.formattedPrice),
              ),
            if (loading || sending) const LinearProgressIndicator(),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: sending || loading
                          ? null
                          : () {
                              if ((ai || thread != null) &&
                                  input.text.trim().isNotEmpty) {
                                send();
                              } else {
                                load();
                              }
                            },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          ai
                              ? 'Hi! Ask me about shopping, orders, or using Lumear.'
                              : 'Start the conversation. Ask about this product, availability, or your order.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final m = messages[index];
                        final time =
                            '${m.date.hour.toString().padLeft(2, '0')}:${m.date.minute.toString().padLeft(2, '0')}';
                        return Align(
                          alignment: m.mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * .78,
                            ),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: m.mine
                                  ? LumearColors.action
                                  : LumearColors.field,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SelectableText(
                                  m.text,
                                  style: TextStyle(
                                    color: m.mine
                                        ? LumearColors.onAction
                                        : LumearColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  time,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: m.mine
                                        ? LumearColors.onAction
                                        : LumearColors.light,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (ai && messages.isEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    for (final question in [
                      'Track my order',
                      'Contact a seller',
                      'Returns and refunds',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(question),
                          onPressed: sending
                              ? null
                              : () {
                                  input.text = question;
                                  send();
                                },
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: input,
                      enabled: !sending && !loading && (ai || thread != null),
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Type a message…',
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: sending || loading || (!ai && thread == null)
                        ? null
                        : send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
