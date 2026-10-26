import '../design/lumear_theme.dart';

import 'package:flutter/material.dart';

import '../login_page.dart';
import '../services/buyer_data.dart';
import '../services/api_service.dart';
import '../address_book_screen.dart';
import '../design/components.dart';
import 'orders_screen.dart';
import 'voucher_screen.dart';
import 'wishlist_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static Color get cream => LumearColors.cream;
  static Color get maroon => LumearColors.maroon;
  static Color get darkMaroon => LumearColors.dark;
  static Color get lightMaroon => LumearColors.light;
  static Color get fieldColor => LumearColors.field;
  static Color get darkText => LumearColors.ink;

  void _showInfoDialog(BuildContext context, String title, String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: TextStyle(color: darkMaroon, fontWeight: FontWeight.bold),
        ),
        content: Text(message, style: TextStyle(color: darkText, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Got it',
              style: TextStyle(color: maroon, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Log out?',
          style: TextStyle(color: darkMaroon, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to log out of Lumear?',
          style: TextStyle(color: darkText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: TextStyle(color: lightMaroon)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: LumearColors.action,
              foregroundColor: LumearColors.ivory,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !context.mounted) return;

    if (BuyerData.instance.connected) {
      try {
        await ApiService.post('/auth/logout', body: {});
      } catch (_) {}
      if (!context.mounted) return;
    }
    BuyerData.instance.reset();
    // Removes the dashboard and all previous routes, then opens Login.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => ListenableBuilder(
      listenable: BuyerData.instance,
      builder: (context, _) => _buildContent(context),
    ),
  );

  Future<void> _editAccount(BuildContext context) async {
    if (!BuyerData.instance.connected) return;
    await showDialog<void>(
      context: context,
      builder: (_) => const _AccountEditor(),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeading(
                'MAKE YOURSELF AT HOME.',
                eyebrow: 'MY LUMEAR / YOUR SPACE',
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 18,
                ),
                decoration: BoxDecoration(
                  color: darkMaroon,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: fieldColor,
                      child: Icon(
                        Icons.person_outline,
                        color: maroon,
                        size: 32,
                      ),
                    ),
                    SizedBox(width: 17),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YOUR LUMEAR.',
                            style: TextStyle(
                              color: cream,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.5,
                            ),
                          ),
                          SizedBox(height: 7),
                          Text(
                            BuyerData.instance.profile.isNotEmpty
                                ? BuyerData.instance.profile['name'] ?? ''
                                : 'Lumear Buyer',
                            style: TextStyle(color: cream, fontSize: 12),
                          ),
                          SizedBox(height: 5),
                          Text(
                            BuyerData.instance.profile.isNotEmpty
                                ? BuyerData.instance.profile['email'] ?? ''
                                : 'lumear@gmail.com',
                            style: TextStyle(color: cream, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              _sectionTitle('My Shopping'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: LumearColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: LumearColors.border),
                ),
                child: Row(
                  children: [
                    _quickLink(
                      Icons.receipt_long_outlined,
                      'My Orders',
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OrdersScreen()),
                      ),
                    ),
                    _quickLink(
                      Icons.favorite_border_rounded,
                      'Wishlist',
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WishlistScreen(),
                        ),
                      ),
                    ),
                    _quickLink(
                      Icons.confirmation_number_outlined,
                      'Vouchers',
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VoucherScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              _sectionTitle('Account'),
              const SizedBox(height: 12),
              _option(
                context,
                Icons.person_outline_rounded,
                'My Account',
                'Manage your personal information',
                () => _editAccount(context),
              ),
              _option(
                context,
                Icons.location_on_outlined,
                'Addresses',
                'Manage your delivery addresses',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddressBookScreen()),
                ),
              ),
              _option(
                context,
                Icons.payment_outlined,
                'Payment Methods',
                'Pay with Cash on Delivery',
                () => _showInfoDialog(
                  context,
                  'Payment Methods',
                  'Cash on Delivery is currently the supported payment method.',
                ),
              ),
              const SizedBox(height: 24),
              _sectionTitle('Settings'),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.brightness_6_outlined),
                title: const Text('Dark mode'),
                subtitle: const Text('On for dark, off for light'),
                trailing: const AppearanceButton(),
              ),
              _option(
                context,
                Icons.notifications_none_rounded,
                'Notification Settings',
                'Manage your notification preferences',
                () => _showInfoDialog(
                  context,
                  'Notification Settings',
                  'Notification preferences are a placeholder for now.',
                ),
              ),
              _option(
                context,
                Icons.settings_outlined,
                'App Settings',
                'Manage your application preferences',
                () => _showInfoDialog(
                  context,
                  'App Settings',
                  'More app preferences can be added here later.',
                ),
              ),
              const SizedBox(height: 24),
              _sectionTitle('Support'),
              const SizedBox(height: 12),
              _option(
                context,
                Icons.help_outline_rounded,
                'Help Center',
                'Get help and support',
                () => _showInfoDialog(
                  context,
                  'Help Center',
                  'Help and support content has not been configured yet.',
                ),
              ),
              _option(
                context,
                Icons.info_outline_rounded,
                'About Lumear',
                'Learn more about the application',
                () => _showInfoDialog(
                  context,
                  'About Lumear',
                  BuyerData.instance.connected
                      ? 'Lumear connects buyers with sellers. Your account, cart and orders are saved to your account.'
                      : 'You are viewing Lumear in preview mode with sample data.',
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmLogout(context),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(
                    'Log Out',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: maroon,
                    side: BorderSide(color: maroon),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'LUMEAR • SHOP WITH EASE',
                  style: TextStyle(
                    color: lightMaroon,
                    fontSize: 10,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickLink(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: fieldColor,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: maroon, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: darkText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: TextStyle(
      color: darkMaroon,
      fontSize: 16,
      fontWeight: FontWeight.bold,
    ),
  );

  Widget _option(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: fieldColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: maroon, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: darkText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: TextStyle(color: darkText, fontSize: 11, height: 1.4),
          ),
        ),
        trailing: Icon(Icons.arrow_forward, color: maroon, size: 17),
        onTap: onTap,
      ),
    ),
  );
}

class _AccountEditor extends StatefulWidget {
  const _AccountEditor();
  @override
  State<_AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends State<_AccountEditor> {
  late final name = TextEditingController(
    text: BuyerData.instance.profile['name'],
  );
  bool saving = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await BuyerData.instance.saveProfile(name.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => AlertDialog(
      title: const Text('My Account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(BuyerData.instance.profile['email'] ?? ''),
          const SizedBox(height: 16),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Full name'),
          ),
          if (error != null) Text(error!),
          if (saving) const LinearProgressIndicator(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : save,
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
