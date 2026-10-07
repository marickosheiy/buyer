import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import 'login_page.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;

  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();

    // L animation
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // UMEAR fade animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _slideAnimation = Tween<double>(
      begin: 0,
      end: -140,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeInOut,
      ),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _startIntro();
  }

  Future<void> _startIntro() async {
    // Start audio immediately at 0:00
    await _audioPlayer.play(
      AssetSource('video/lumear.mp3'),
    );

    // Small delay before the L starts moving
    await Future.delayed(const Duration(milliseconds: 500));

    // Move the L to the left
    await _slideController.forward();

    // After L reaches the side, reveal UMEAR
    await _fadeController.forward();

    // Wait until the 6-second audio is almost finished.
    // 0.5 sec delay + 2 sec slide + 1 sec fade = 3.5 sec
    // Wait another 2.5 sec = approximately 6 sec total
    await Future.delayed(const Duration(milliseconds: 2500));

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF9EEEA),
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _slideController,
            _fadeController,
          ]),
          builder: (context, child) {
            return SizedBox(
              width: 350,
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // UMEAR is invisible at first
                  Opacity(
                    opacity: _fadeAnimation.value,
                    child: const Text(
                      'UMEAR',
                      style: TextStyle(
                        color: Color(0xFF963B36),
                        fontSize: 65,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),

                  // L starts in the center and moves left
                  Transform.translate(
                    offset: Offset(
                      _slideAnimation.value,
                      0,
                    ),
                    child: const Text(
                      'L',
                      style: TextStyle(
                        color: Color(0xFF963B36),
                        fontSize: 65,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}