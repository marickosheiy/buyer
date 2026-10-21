import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../design/lumear_theme.dart';

class EmailVerificationForm extends StatefulWidget {
  const EmailVerificationForm({
    super.key,
    required this.email,
    this.password,
    this.purpose = 'registration',
    required this.onVerified,
  });
  final String email, purpose;
  final String? password;
  final ValueChanged<String?> onVerified;
  @override
  State<EmailVerificationForm> createState() => _EmailVerificationFormState();
}

class _EmailVerificationFormState extends State<EmailVerificationForm> {
  final code = TextEditingController();
  String? challenge, message;
  bool working = false, verified = false;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (working) return;
    setState(() {
      working = true;
      message = null;
    });
    try {
      final r = await ApiService.post(
        '/auth/email/send',
        body: {
          'email': widget.email,
          'purpose': widget.purpose,
          if (widget.password != null) 'password': widget.password,
        },
      );
      if (!mounted) return;
      setState(() {
        challenge = r['challenge_id'].toString();
        message = r['message'];
        code.clear();
      });
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> verify() async {
    if (working || challenge == null) return;
    if (!RegExp(r'^\d{6}$').hasMatch(code.text.trim())) {
      setState(() => message = 'Enter the six-digit code from your email.');
      return;
    }
    setState(() {
      working = true;
      message = null;
    });
    try {
      final r = await ApiService.post(
        '/auth/email/verify',
        body: {'challenge_id': challenge, 'code': code.text.trim()},
      );
      if (!mounted) return;
      setState(() {
        verified = r['verified'] == true;
        message = r['message'];
      });
      if (verified) widget.onVerified(r['verification_token']);
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    LumearAppearance.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.email, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (verified)
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: LumearColors.success),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Email verified. You can create your account.'),
              ),
            ],
          )
        else ...[
          const Text('Send a code to your email inbox to verify this account.'),
          const SizedBox(height: 16),
          if (challenge != null) ...[
            TextField(
              controller: code,
              enabled: !working,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Verification code'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: working ? null : verify,
                child: const Text('Verify email'),
              ),
            ),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: working ? null : send,
              child: Text(
                challenge == null ? 'Send verification code' : 'Resend code',
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check your inbox and spam folder. Codes expire in 10 minutes; wait 60 seconds before resending.',
            style: TextStyle(fontSize: 11),
          ),
        ],
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              message!,
              style: TextStyle(
                color: verified
                    ? LumearColors.success
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        if (working)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

Future<bool> verifyExistingEmail(
  BuildContext context,
  String email,
  String password,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Verify your account'),
        content: SingleChildScrollView(
          child: EmailVerificationForm(
            email: email,
            password: password,
            purpose: 'account',
            onVerified: (_) => Navigator.pop(dialog, true),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ) ??
    false;
