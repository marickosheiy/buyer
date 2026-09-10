import 'package:flutter/material.dart';

import 'register_page.dart';
import 'screen/dashboard_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;
  bool rememberMe = false;
  bool isLoading = false;

  // ============================================================
  // COLORS
  // ============================================================

  static const Color maroon = Color(0xFF6B1E2B);
  static const Color cream = Color(0xFFF8F3EC);
  static const Color dark = Color(0xFF292929);
  static const Color brown = Color(0xFF8B5A3C);

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email and password.')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    // Temporary loading effect
    await Future.delayed(const Duration(milliseconds: 1000));

    if (!mounted) return;

    // Temporary hardcoded account
    if (email == 'lumear@gmail.com' && password == 'Lumear123') {
      setState(() {
        isLoading = false;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } else {
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid email or password.')),
      );
    }
  }

  // ============================================================
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

      prefixIcon: Icon(icon, color: maroon, size: 23),

      suffixIcon: suffixIcon,

      filled: true,
      fillColor: Colors.white,

      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: brown.withValues(alpha: 0.25)),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: maroon, width: 1.7),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,

      body: SafeArea(
        child: Column(
          children: [
            // =================================================
            // FIXED HERO IMAGE
            // =================================================

            SizedBox(
              height: 330,
              width: double.infinity,

              child: Stack(
                fit: StackFit.expand,
                children: [
                  // =============================================
                  // BACKGROUND IMAGE
                  // =============================================

                  Image.asset(
                    'assets/images/image_login1.jpg',
                    fit: BoxFit.cover,
                  ),

                  // =============================================
                  // CREAM FADE
                  // =============================================
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,

                        stops: [0.0, 0.55, 0.78, 0.92, 1.0],

                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Color(0x20F8F3EC),
                          Color(0xB8F8F3EC),
                          Color(0xFFF8F3EC),
                        ],
                      ),
                    ),
                  ),

                  // =============================================
                  // BACK BUTTON
                  // =============================================
                  Positioned(
                    top: 12,
                    left: 12,

                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.75),
                        shape: BoxShape.circle,
                      ),

                      child: IconButton(
                        onPressed: () {
                          Navigator.maybePop(context);
                        },

                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: dark,
                          size: 21,
                        ),
                      ),
                    ),
                  ),

                  // =============================================
                  // LUMEAR BRAND
                  // =============================================
                  Positioned(
                    top: 45,
                    left: 0,
                    right: 0,

                    child: Column(
                      children: [
                        const Text(
                          'LUMEAR',
                          style: TextStyle(
                            color: maroon,
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 4,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          'Good Finds. Brighter Days.',
                          style: TextStyle(
                            color: dark.withValues(alpha: 0.65),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // =============================================
                  // WELCOME TEXT
                  // =============================================
                  Positioned(
                    left: 28,
                    right: 28,
                    bottom: 24,

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        const Text(
                          'Welcome Back',
                          style: TextStyle(
                            color: maroon,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          'Log in to continue shopping '
                          'for the things you love.',
                          style: TextStyle(
                            color: dark.withValues(alpha: 0.75),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // =================================================
            // SCROLLABLE LOGIN FORM
            // =================================================
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),

                padding: const EdgeInsets.fromLTRB(28, 8, 28, 35),

                child: Column(
                  children: [
                    // ==========================================
                    // EMAIL
                    // ==========================================

                    TextField(
                      controller: emailController,

                      keyboardType: TextInputType.emailAddress,

                      textInputAction: TextInputAction.next,

                      decoration: inputDecoration(
                        hint: 'Email address',
                        icon: Icons.mail_outline_rounded,
                      ),
                    ),

                    const SizedBox(height: 15),

                    // ==========================================
                    // PASSWORD
                    // ==========================================
                    TextField(
                      controller: passwordController,

                      obscureText: obscurePassword,

                      textInputAction: TextInputAction.done,

                      onSubmitted: (_) {
                        login();
                      },

                      decoration: inputDecoration(
                        hint: 'Password',
                        icon: Icons.lock_outline_rounded,

                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },

                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,

                            color: dark.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ==========================================
                    // REMEMBER ME + FORGOT PASSWORD
                    // ==========================================
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,

                          child: Checkbox(
                            value: rememberMe,

                            activeColor: maroon,

                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),

                            onChanged: (value) {
                              setState(() {
                                rememberMe = value ?? false;
                              });
                            },
                          ),
                        ),

                        const SizedBox(width: 8),

                        const Text(
                          'Remember me',
                          style: TextStyle(fontSize: 13),
                        ),

                        const Spacer(),

                        TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Forgot password will be available soon.',
                                ),
                              ),
                            );
                          },

                          child: const Text(
                            'Forgot password?',
                            style: TextStyle(
                              color: maroon,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ==========================================
                    // LOGIN BUTTON
                    // ==========================================
                    SizedBox(
                      width: double.infinity,
                      height: 57,

                      child: ElevatedButton(
                        onPressed: isLoading ? null : login,

                        style: ElevatedButton.styleFrom(
                          backgroundColor: maroon,
                          foregroundColor: Colors.white,

                          disabledBackgroundColor: maroon.withValues(
                            alpha: 0.60,
                          ),

                          elevation: 0,

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),

                        child: isLoading
                            ? const SizedBox(
                                width: 23,
                                height: 23,

                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,

                                children: [
                                  Text(
                                    'Log In',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  SizedBox(width: 10),

                                  Icon(Icons.arrow_forward_rounded),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 27),

                    // ==========================================
                    // DIVIDER
                    // ==========================================
                    Row(
                      children: [
                        Expanded(
                          child: Divider(color: brown.withValues(alpha: 0.25)),
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 15),

                          child: Text(
                            'or continue with',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),

                        Expanded(
                          child: Divider(color: brown.withValues(alpha: 0.25)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // ==========================================
                    // GOOGLE LOGIN ONLY
                    // ==========================================
                    SizedBox(
                      width: double.infinity,

                      child: socialButton(
                        'assets/images/google.png',
                        'Continue with Google',
                      ),
                    ),

                    const SizedBox(height: 30),

                    // ==========================================
                    // SIGN UP
                    // ==========================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,

                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: dark.withValues(alpha: 0.60),
                            fontSize: 14,
                          ),
                        ),

                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterPage(),
                              ),
                            );
                          },

                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              color: maroon,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // ==========================================
                    // DEMO ACCOUNT
                    // ==========================================
                    Container(
                      width: double.infinity,

                      padding: const EdgeInsets.all(16),

                      decoration: BoxDecoration(
                        color: maroon.withValues(alpha: 0.06),

                        borderRadius: BorderRadius.circular(15),

                        border: Border.all(
                          color: maroon.withValues(alpha: 0.15),
                        ),
                      ),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          const Row(
                            children: [
                              Icon(Icons.info_outline, color: maroon, size: 19),

                              SizedBox(width: 8),

                              Text(
                                'Demo Buyer Account',
                                style: TextStyle(
                                  color: maroon,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          const Text('Email: lumear@gmail.com'),

                          const SizedBox(height: 4),

                          const Text('Password: Lumear123'),

                          const SizedBox(height: 8),

                          Align(
                            alignment: Alignment.centerRight,

                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  emailController.text = 'lumear@gmail.com';

                                  passwordController.text = 'Lumear123';
                                });
                              },

                              child: const Text(
                                'USE ACCOUNT',
                                style: TextStyle(
                                  color: maroon,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // GOOGLE SOCIAL BUTTON
  // ============================================================

  Widget socialButton(String imagePath, String title) {
    return SizedBox(
      height: 52,

      child: OutlinedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title will be available soon.')),
          );
        },

        style: OutlinedButton.styleFrom(
          foregroundColor: dark,
          backgroundColor: Colors.white,

          side: BorderSide(color: brown.withValues(alpha: 0.20)),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Image.asset(imagePath, width: 23, height: 23, fit: BoxFit.contain),

            const SizedBox(width: 10),

            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
