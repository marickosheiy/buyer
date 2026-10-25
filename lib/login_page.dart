import 'package:flutter/material.dart';

import 'register_page.dart';

import 'design/lumear_theme.dart';

import 'seller/seller_dashboard_screen.dart';
import 'services/api_service.dart';
import 'services/google_login.dart';
import 'widgets/email_verification_form.dart';
import 'services/buyer_data.dart';
import 'screen/dashboard_screen.dart';
import 'cart_manager.dart';
import 'order_manager.dart';
import 'address_manager.dart';
import 'services/wishlist_manager.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.useBackend, this.googleIdTokenProvider});
  final bool? useBackend;
  final Future<String?> Function()? googleIdTokenProvider;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool get backendEnabled =>
      widget.useBackend ??
      const bool.fromEnvironment('ENABLE_BUYER_BACKEND', defaultValue: false);

  final TextEditingController emailController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;

  bool isLoading = false;
  String? loginError;

  // ============================================================

  // COLORS

  // ============================================================

  // ============================================================

  // LOGIN

  // ============================================================

  static Color get maroon => LumearColors.maroon;
  static Color get dark => LumearColors.ink;

  Future<void> login() async {
    if (isLoading) return;
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => loginError = 'Please enter your email and password.');
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => loginError = 'Enter a valid email address.');
      return;
    }

    setState(() {
      isLoading = true;
      loginError = null;
    });

    bool isSeller = email == 'seller@lumear.com' && password == 'Seller123';
    final isBuyer = email == 'lumear@gmail.com' && password == 'Lumear123';
    if (!backendEnabled && !isBuyer && !isSeller) {
      setState(() {
        isLoading = false;
        loginError =
            'Invalid demo email or password. Use an account shown above.';
      });
      return;
    }
    try {
      ApiService.setToken(null);
      if (backendEnabled) {
        var result = await ApiService.post(
          '/auth/login',
          body: {'email': email, 'password': password},
        );
        if (result['requires_email_verification'] == true) {
          if (!mounted) return;
          if (!await verifyExistingEmail(context, email, password)) return;
          result = await ApiService.post(
            '/auth/login',
            body: {'email': email, 'password': password},
          );
        }
        ApiService.setToken(result['token'] as String);
        isSeller = result['role'] == 'seller';
      }
      if (!mounted) return;
      openWorkspace(isSeller);
    } catch (error) {
      if (mounted) setState(() => loginError = error.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void openWorkspace(bool isSeller) {
    BuyerData.instance.reset();
    CartManager.instance.clearCart();
    OrderManager.instance.clearOrders();
    AddressManager.instance.addresses.value = [];
    WishlistManager.instance.clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => isSeller
            ? SellerDashboardScreen(connected: backendEnabled)
            : backendEnabled
            ? const DashboardScreen(connected: true)
            : const DashboardScreen(),
      ),
    );
  }

  Future<void> loginWithGoogle() async {
    if (isLoading) return;
    final apiUrl = Uri.tryParse(ApiService.baseUrl);
    if (!backendEnabled ||
        apiUrl == null ||
        !apiUrl.hasAuthority ||
        !['http', 'https'].contains(apiUrl.scheme)) {
      setState(
        () => loginError = 'Google sign-in will be available when the shared service is connected. You can use a demo account for now.',
      );
      return;
    }
    setState(() {
      isLoading = true;
      loginError = null;
    });
    ApiService.setToken(null);
    try {
      final token =
          await (widget.googleIdTokenProvider ?? GoogleLogin.idToken)();
      if (!mounted || token == null) return;
      final result = await ApiService.post(
        '/auth/google',
        body: {'id_token': token},
      );
      if (!mounted) return;
      if (result is! Map ||
          result['token'] is! String ||
          (result['token'] as String).isEmpty ||
          !['buyer', 'seller'].contains(result['role'])) {
        throw const ApiException(
          'Google sign-in could not create a Lumear session. Please try again.',
        );
      }
      ApiService.setToken(result['token'] as String);
      openWorkspace(result['role'] == 'seller');
    } catch (error) {
      if (mounted) {
        setState(
          () => loginError = error is ApiException
              ? error.message
              : 'Unable to sign in with Google. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // DISPOSE

  // ============================================================

  @override
  void dispose() {
    emailController.dispose();

    passwordController.dispose();

    super.dispose();
  }

  // ============================================================

  // INPUT DESIGN

  // ============================================================

  InputDecoration inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: dark.withValues(alpha: 0.45), fontSize: 15),
      prefixIcon: Icon(icon, color: LumearColors.light, size: 19),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: LumearColors.surface,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(32),
        borderSide: BorderSide(color: LumearColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(32),
        borderSide: BorderSide(color: maroon, width: 1.7),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => Scaffold(
      backgroundColor: LumearColors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: viewport.maxHeight),
              child: Column(
                children: [
                  SizedBox(
                    height: (viewport.maxHeight * .27).clamp(170.0, 300.0),
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/images/image_login1.jpg',
                          fit: BoxFit.cover,
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0x55651D32)],
                            ),
                          ),
                        ),
                        const Positioned(
                          top: 12,
                          right: 12,
                          child: Material(
                            color: Colors.transparent,
                            child: AppearanceButton(),
                          ),
                        ),
                        Positioned(
                          top: 18,
                          left: 20,
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 90,
                            height: 48,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const Positioned(
                          bottom: 33,
                          left: 24,
                          right: 24,
                          child: Text(
                            'YOUR EVERYDAY.\nYOUR KIND OF GOOD.',
                            style: TextStyle(
                              color: LumearColors.ivory,
                              fontWeight: FontWeight.w900,
                              fontSize: 26,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -22),
                    child: Container(
                      width: double.infinity,
                      constraints: BoxConstraints(
                        minHeight:
                            viewport.maxHeight -
                            (viewport.maxHeight * .27).clamp(170.0, 300.0) +
                            22,
                      ),
                      decoration: BoxDecoration(
                        color: LumearColors.surface,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        viewport.maxWidth < 380 ? 22 : 32,
                        24,
                        viewport.maxWidth < 380 ? 22 : 32,
                        24,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Column(
                            children: [
                              Text(
                                'hello!',
                                style: TextStyle(
                                  color: LumearColors.dark,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Sign in to make yourself at home.',
                                style: TextStyle(
                                  color: Color(0xFF888888),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 18),
                              if (!backendEnabled) _demoAccounts(),
                              if (backendEnabled)
                                const Text(
                                  'Sign in with your existing Lumear account.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              const SizedBox(height: 18),
                              if (loginError != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    loginError!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              TextField(
                                controller: emailController,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                textInputAction: TextInputAction.next,
                                decoration: inputDecoration(
                                  hint: 'Email',
                                  icon: Icons.mail_rounded,
                                ),
                              ),
                              const SizedBox(height: 18),
                              TextField(
                                controller: passwordController,
                                obscureText: obscurePassword,
                                autofillHints: const [AutofillHints.password],
                                onSubmitted: (_) {
                                  if (!isLoading) login();
                                },
                                decoration: inputDecoration(
                                  hint: 'Password',
                                  icon: Icons.shield_rounded,
                                  suffixIcon: IconButton(
                                    tooltip: obscurePassword
                                        ? 'Show password'
                                        : 'Hide password',
                                    onPressed: () => setState(
                                      () => obscurePassword = !obscurePassword,
                                    ),
                                    icon: Icon(
                                      obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      size: 20,
                                      color: LumearColors.light,
                                    ),
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => showDialog<void>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: const Text('Password assistance'),
                                      content: const Text(
                                        'Password recovery is not configured yet. Contact your administrator for account recovery.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(c),
                                          child: const Text('Got it'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  child: const Text(
                                    'Forgot password?',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      LumearColors.brandMaroon,
                                      LumearColors.action,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(32),
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      disabledBackgroundColor:
                                          Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: LumearColors.ivory,
                                      shape: const StadiumBorder(),
                                    ),
                                    onPressed: isLoading ? null : login,
                                    child: isLoading
                                        ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: LumearColors.ivory,
                                            ),
                                          )
                                        : const Text(
                                            'Sign in',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: isLoading ? null : loginWithGoogle,
                                  icon: Image.asset(
                                    'assets/images/google.png',
                                    width: 20,
                                    height: 20,
                                  ),
                                  label: const Text('Continue with Google'),
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (!backendEnabled)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    'Demo mode. Changes last for this session. Registration and email verification will be available when the shared service is connected.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Text(
                                    'New around here?',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF888888),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: backendEnabled && !isLoading
                                        ? () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const RegisterPage(),
                                            ),
                                          )
                                        : null,
                                    child: const Text(
                                      'Create an account',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _demoAccounts() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: LumearColors.field,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Text(
          'Try a demo account',
          style: TextStyle(
            color: LumearColors.dark,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final account in const [
              ['Buyer', 'lumear@gmail.com', 'Lumear123'],
              ['Seller · local preview', 'seller@lumear.com', 'Seller123'],
            ])
              ChoiceChip(
                selected: emailController.text == account[1],
                selectedColor: LumearColors.dark,
                backgroundColor: LumearColors.surface,
                showCheckmark: false,
                side: BorderSide(color: LumearColors.border),
                label: Text(
                  account[0],
                  style: TextStyle(
                    fontSize: 11,
                    color: emailController.text == account[1]
                        ? Colors.white
                        : LumearColors.dark,
                  ),
                ),
                tooltip: '${account[1]}\nPassword: ${account[2]}',
                onSelected: isLoading
                    ? null
                    : (_) => setState(() {
                        emailController.text = account[1];
                        passwordController.text = account[2];
                        loginError = null;
                      }),
              ),
          ],
        ),
      ],
    ),
  );
}
