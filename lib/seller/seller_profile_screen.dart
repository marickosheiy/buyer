import 'package:flutter/material.dart';

import '../design/components.dart';
import '../design/lumear_theme.dart';
import '../login_page.dart';
import '../services/api_service.dart';
import '../services/mobile_number.dart';
import 'seller_shop.dart';

class SellerProfileScreen extends StatefulWidget {
  const SellerProfileScreen({
    super.key,
    this.shop,
    this.showBottomNavigation = true,
  });
  final SellerShop? shop;
  final bool showBottomNavigation;

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  late final SellerShop shop = widget.shop ?? SellerShop();

  @override
  void dispose() {
    if (widget.shop == null) shop.dispose();
    super.dispose();
  }

  Future<void> edit() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _ShopEditor(shop: shop),
    );
    if (result == null || !mounted) return;
    if (shop.connected) {
      try {
        await ApiService.patch('/seller/shop', body: result);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString())));
        }
        return;
      }
      if (!mounted) return;
    }
    shop.update(
      owner: result['owner']!,
      name: result['name']!,
      description: result['description']!,
      email: result['email']!,
      phone: result['phone']!,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          shop.connected
              ? 'Shop profile saved.'
              : 'Shop profile saved for this session.',
        ),
      ),
    );
  }

  Future<void> logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Log out?'),
        content: Text(
          shop.connected
              ? 'Sign out of your seller account?'
              : 'Your local shop profile changes will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (shop.connected) {
      try {
        await ApiService.post('/auth/logout', body: {});
      } catch (_) {}
      if (!mounted) return;
    }
    ApiService.setToken(null);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => ListenableBuilder(
      listenable: shop,
      builder: (context, _) => Scaffold(
        appBar: widget.showBottomNavigation
            ? AppBar(
                title: const Text('My profile'),
                actions: const [AppearanceButton()],
              )
            : null,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            PageHeading(
              'My profile',
              eyebrow: 'SELLER OPERATOR',
              subtitle:
                  'Manage the operator details for ${shop.name.isEmpty ? 'your shop' : shop.name}.',
            ),
            LayoutBuilder(
              builder: (context, c) {
                final operator = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: LumearColors.action,
                              child: Text(
                                shop.owner.isEmpty ? 'L' : shop.owner[0],
                                style: const TextStyle(
                                  color: LumearColors.ivory,
                                  fontFamily: 'serif',
                                  fontFamilyFallback: ['Roboto'],
                                  fontSize: 26,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    shop.owner.isEmpty
                                        ? 'Your seller name'
                                        : shop.owner,
                                    style: TextStyle(
                                      fontSize: 23,
                                      fontFamily: 'serif',
                                      fontFamilyFallback: const ['Roboto'],
                                      color: LumearColors.dark,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    shop.email.isEmpty
                                        ? 'Add your contact details'
                                        : shop.email,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: LumearColors.light,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        if (shop.connected)
                          Chip(
                            avatar: Icon(
                              Icons.storefront_outlined,
                              size: 16,
                              color:
                                  ['active', 'approved'].contains(shop.status)
                                  ? LumearColors.success
                                  : LumearColors.gold,
                            ),
                            label: Text(
                              shop.status.isEmpty
                                  ? 'Status unavailable'
                                  : ['active', 'approved'].contains(shop.status)
                                  ? 'Active'
                                  : shop.status,
                            ),
                          ),
                        const Divider(height: 32),
                        for (final field in [
                          ('Full name', shop.owner),
                          ('Mobile number', shop.phone),
                          ('Email address', shop.email),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: InputDecorator(
                              decoration: InputDecoration(labelText: field.$1),
                              child: Text(
                                field.$2.isEmpty ? 'Not provided' : field.$2,
                              ),
                            ),
                          ),
                        if (shop.connected)
                          Text(
                            'Your email is used to sign in to your account.',
                            style: TextStyle(
                              color: LumearColors.light,
                              fontSize: 11,
                            ),
                          ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: edit,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit shop profile'),
                        ),
                      ],
                    ),
                  ),
                );
                final details = Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'STORE IDENTITY',
                              style: TextStyle(
                                color: LumearColors.light,
                                fontSize: 10,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              shop.name.isEmpty ? 'Your shop name' : shop.name,
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontFamilyFallback: const ['Roboto'],
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                                color: LumearColors.dark,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              shop.description.isEmpty
                                  ? 'Tell buyers about your shop.'
                                  : shop.description,
                            ),
                            const SizedBox(height: 20),
                            TextButton(
                              onPressed: edit,
                              child: const Text('Edit store details →'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ACCOUNT SECURITY',
                              style: TextStyle(
                                color: LumearColors.light,
                                fontSize: 10,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Sign-in protection',
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontFamilyFallback: const ['Roboto'],
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                                color: LumearColors.dark,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Use your email and password to access your seller account. Keep your password private.',
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                const Expanded(child: Text('Appearance')),
                                const AppearanceButton(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
                return c.maxWidth >= 800
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: operator),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: details),
                        ],
                      )
                    : Column(children: [operator, details]);
              },
            ),
            const SizedBox(height: 16),
            Text(
              shop.connected
                  ? 'Your profile changes are saved to your account.'
                  : 'Local preview · Details are saved only for this session.',
              style: TextStyle(color: LumearColors.light, fontSize: 12),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: logout,
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ShopEditor extends StatefulWidget {
  const _ShopEditor({required this.shop});
  final SellerShop shop;
  @override
  State<_ShopEditor> createState() => _ShopEditorState();
}

class _ShopEditorState extends State<_ShopEditor> {
  final formKey = GlobalKey<FormState>();
  late final controllers = <String, TextEditingController>{
    'owner': TextEditingController(text: widget.shop.owner),
    'name': TextEditingController(text: widget.shop.name),
    'description': TextEditingController(text: widget.shop.description),
    'email': TextEditingController(text: widget.shop.email),
    'phone': TextEditingController(
      text: MobileNumber.forEditing(widget.shop.phone),
    ),
  };

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => AlertDialog(
      title: const Text('Edit shop profile'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final field in const {
                  'owner': 'Seller name',
                  'name': 'Shop name',
                  'description': 'Shop story',
                  'email': 'Email address',
                  'phone': 'Mobile number',
                }.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: TextFormField(
                      controller: controllers[field.key],
                      readOnly:
                          widget.shop.connected &&
                          (field.key == 'email' || field.key == 'phone'),
                      decoration: InputDecoration(
                        labelText: field.value,
                        errorMaxLines: 2,
                        helperText: field.key == 'owner' || field.key == 'name'
                            ? 'Required'
                            : 'Optional',
                      ),
                      maxLength: field.key == 'description'
                          ? 300
                          : field.key == 'phone'
                          ? MobileNumber.maxLength
                          : 100,
                      maxLines: field.key == 'description' ? 3 : 1,
                      inputFormatters: field.key == 'phone'
                          ? MobileNumber.inputFormatters
                          : null,
                      keyboardType: field.key == 'email'
                          ? TextInputType.emailAddress
                          : field.key == 'phone'
                          ? TextInputType.phone
                          : TextInputType.text,
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if ((field.key == 'owner' || field.key == 'name') &&
                            text.isEmpty) {
                          return 'Please enter your ${field.value.toLowerCase()}.';
                        }
                        if (field.key == 'email' &&
                            text.isNotEmpty &&
                            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(text)) {
                          return 'Enter a valid email address.';
                        }
                        if (field.key == 'phone' &&
                            text.isNotEmpty &&
                            !MobileNumber.isValid(text)) {
                          return MobileNumber.error;
                        }
                        return null;
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(context, {
                for (final e in controllers.entries) e.key: e.value.text.trim(),
              });
            }
          },
          child: const Text('Save changes'),
        ),
      ],
    ),
  );
}
