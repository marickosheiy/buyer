import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import 'login_page.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _slideAnimation = Tween<double>(
      begin: 0,
      end: -120,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _startIntro();
  }

  Future<void> _startIntro() async {
    // Play voice-over
   await _audioPlayer.play(
  AssetSource('video/lumear.mp3'),
  position: const Duration(seconds: 2),
);

    // Wait before starting animation
    await Future.delayed(const Duration(milliseconds: 500));

    // Slide the L to the left
    await _animationController.forward();

    // Keep the logo visible
    await Future.delayed(const Duration(seconds: 2));

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
    _animationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // The rest of the brand name behind the L
                const Text(
                  'UMEAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 65,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),

                // The big L slides to reveal the name
                Transform.translate(
                  offset: Offset(_slideAnimation.value, 0),
                  child: const Text(
                    'L',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 100,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}