import 'dart:math';

import 'package:flutter/material.dart';

import '../design/lumear_theme.dart';
import '../services/api_service.dart';
import 'seller_commerce.dart';

class PayoutRequestDialog extends StatefulWidget {
  const PayoutRequestDialog({super.key, required this.commerce});
  final SellerCommerce commerce;
  @override
  State<PayoutRequestDialog> createState() => _PayoutRequestDialogState();
}

class _PayoutRequestDialogState extends State<PayoutRequestDialog> {
  final amount = TextEditingController();
  final key =
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
  String? account, error;
  bool working = false;
  List<dynamic> get accounts =>
      widget.commerce.earnings['payout_accounts'] as List? ?? [];
  @override
  void initState() {
    super.initState();
    account = accounts.isEmpty ? null : accounts.first['id'].toString();
  }

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final input = amount.text.trim();
    if (!RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(input) || account == null) {
      setState(() => error = 'Choose an account and enter a valid PHP amount.');
      return;
    }
    final parts = input.split('.');
    final minor =
        int.parse(parts.first) * 100 +
        (parts.length > 1 ? int.parse(parts[1].padRight(2, '0')) : 0);
    final available =
        widget.commerce.earnings['available_to_request'] as int? ?? 0;
    if (minor < 100 || minor > available) {
      setState(
        () =>
            error = 'Enter an amount from ₱1.00 to ${sellerMoney(available)}.',
      );
      return;
    }
    setState(() {
      working = true;
      error = null;
    });
    try {
      await ApiService.post(
        '/seller/payouts',
        body: {'account_id': account, 'amount': minor, 'idempotency_key': key},
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    LumearAppearance.watch(context);
    return PopScope(
      canPop: !working,
      child: AlertDialog(
        title: const Text('Request a manual payout'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your request will be reviewed before payment. Submitting it does not transfer money.',
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: account,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Saved payout account',
                  ),
                  items: [
                    for (final a in accounts)
                      DropdownMenuItem(
                        value: a['id'].toString(),
                        child: Text(
                          '${a['name']} (${a['type']})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: working
                      ? null
                      : (v) => setState(() => account = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amount,
                  enabled: !working,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount (PHP)',
                    prefixText: '₱ ',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Available to request: ${sellerMoney(widget.commerce.earnings['available_to_request'] ?? 0)}',
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (working) const LinearProgressIndicator(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: working ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: working ? null : submit,
            child: const Text('Request payout'),
          ),
        ],
      ),
    );
  }
}
