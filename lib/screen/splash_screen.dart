import 'package:flutter/material.dart';
import 'package:flutter_application_1/login_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Color cream = Color(0xFFFFF8F4);
  static const Color darkMaroon = Color(0xFF721E1E);
  static const Color lightText = Color(0xFFC78F88);

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // Logo stays visible first,
    // then slowly fades out.
    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 55),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 45,
      ),
    ]).animate(_controller);

    // Small smooth zoom animation
    _scaleAnimation = Tween<double>(
      begin: 0.90,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _startSplash();
  }

  Future<void> _startSplash() async {
    await _controller.forward();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const LoginPage();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ==========================================
                // LUMEAR LOGO
                // ==========================================

                Image.asset(
                  'assets/images/logo.png',
                  width: 135,
                  height: 135,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 20),

                // ==========================================
                // LUMEAR NAME
                // ==========================================
                const Text(
                  'LUMEAR',
                  style: TextStyle(
                    color: darkMaroon,
                    fontSize: 31,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 5,
                  ),
                ),

                const SizedBox(height: 8),

                // ==========================================
                // TAGLINE
                // ==========================================
                const Text(
                  'Good Finds. Brighter Days.',
                  style: TextStyle(
                    color: lightText,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
