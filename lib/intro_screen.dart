import 'dart:async';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import 'design/lumear_theme.dart';
import 'login_page.dart';

/// Start right, bounce twice to the left, then slide right and unmask LUMEAR.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, this.audioPlayer});

  final AudioPlayer? audioPlayer;
  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with TickerProviderStateMixin {
  static const introDuration = Duration(milliseconds: 4300);
  static const choreographyDuration = Duration(seconds: 6);
  static const firstBounceStartsAt = Duration(milliseconds: 450);
  static const soundStartsAt = Duration(seconds: 3);

  late final AnimationController timeline = AnimationController(
    vsync: this,
    duration: introDuration,
  );
  late final audio = widget.audioPlayer ?? AudioPlayer();
  Timer? exitTimer;
  bool audioReady = false;
  bool soundPlayed = false;
  bool entered = false;
  @override
  void initState() {
    super.initState();
    timeline.addListener(playPreparedSound);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(start());
    });
  }

  Future<void> start() async {
    if (MediaQuery.disableAnimationsOf(context)) {
      timeline.value = 1;
      exitTimer = Timer(const Duration(milliseconds: 350), enter);
      return;
    }
    // Sound preparation never delays animation or access to login.
    unawaited(prepareAudio());
    try {
      await timeline.forward().orCancel;
      if (mounted) enter();
    } on TickerCanceled {
      // Skipping or leaving the intro cancels its animation.
    }
  }

  Future<void> prepareAudio() async {
    try {
      await audio.setSource(AssetSource('video/lumear.mp3'));
      if (!mounted || entered) return;
      await audio.seek(soundStartsAt);
      if (!mounted || entered) return;
      audioReady = true;
      playPreparedSound();
    } catch (_) {
      // Audio is optional and never blocks login.
    }
  }

  void playPreparedSound() {
    final firstBounce =
        firstBounceStartsAt.inMilliseconds /
        choreographyDuration.inMilliseconds;
    if (!mounted ||
        entered ||
        !audioReady ||
        soundPlayed ||
        timeline.value < firstBounce ||
        timeline.value > .5) {
      return;
    }
    soundPlayed = true;
    unawaited(audio.resume().catchError((Object _) {}));
  }

  void enter() {
    if (!mounted || entered) return;
    entered = true;
    exitTimer?.cancel();
    timeline.stop();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  void dispose() {
    exitTimer?.cancel();
    timeline.dispose();
    unawaited(audio.dispose().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => Scaffold(
      backgroundColor: LumearColors.field,
      body: CustomPaint(
        painter: const _IntroWaveBackground(),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: timeline,
            builder: (context, _) {
              // Right hold → first leftward hop → second leftward hop → left
              // landing/hold → rightward slide with the text revealed by its mask.
              final elapsed =
                  timeline.value * choreographyDuration.inMilliseconds;
              final slideProgress = ((elapsed - 2300) / 1400).clamp(0.0, 1.0);
              final movement = Curves.easeInOutCubic.transform(slideProgress);
              final settle = Curves.easeInOutCubic.transform(
                ((elapsed - 3700) / 600).clamp(0.0, 1.0),
              );
              final taglineProgress = ((elapsed - 3700) / 500).clamp(0.0, 1.0);
              double travel = 0;
              double jumpY = 0;
              if (elapsed >= firstBounceStartsAt.inMilliseconds &&
                  elapsed < 1200) {
                final t = (elapsed - firstBounceStartsAt.inMilliseconds) / 750;
                travel = .5 * t;
                jumpY = -4 * 64 * t * (1 - t);
              } else if (elapsed >= 1200 && elapsed < 1850) {
                final t = (elapsed - 1200) / 650;
                travel = .5 + .5 * t;
                jumpY = -4 * 42 * t * (1 - t);
              } else if (elapsed >= 1850) {
                travel = 1;
              }
              return Stack(
                children: [
                  Positioned(
                    top: 8,
                    right: 12,
                    child: TextButton(
                      onPressed: enter,
                      child: const Text('Skip'),
                    ),
                  ),
                  Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = (constraints.maxWidth - 32).clamp(
                          0.0,
                          420.0,
                        );
                        // Measure the visible word so the final word + gap + logo
                        // lockup is centered, including on narrower screens.
                        final wordStyle = TextStyle(
                          color: LumearColors.dark,
                          fontSize: 58,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        );
                        final wordPainter = TextPainter(
                          text: TextSpan(
                            text: 'LUMEAR',
                            style: DefaultTextStyle.of(context).style
                                .merge(wordStyle),
                          ),
                          textDirection: Directionality.of(context),
                          textScaler: MediaQuery.textScalerOf(context),
                        )..layout();
                        final wordScale = ((width - 94) / wordPainter.width)
                            .clamp(0.0, 1.0);
                        final heightScale = (68 / wordPainter.height).clamp(
                          0.0,
                          1.0,
                        );
                        final visibleWordWidth =
                            wordPainter.width *
                            (wordScale < heightScale ? wordScale : heightScale);
                        wordPainter.dispose();
                        final finalWordLeft =
                            (width - visibleWordWidth - 12 - 78) / 2;
                        final finalLogoCenter =
                            finalWordLeft + visibleWordWidth + 12 + 39;
                        final travellingLogoCenter =
                            width -
                            41 -
                            (width - 82) * travel +
                            (width - 82) * movement;
                        final logoCenterX =
                            travellingLogoCenter +
                            (finalLogoCenter - travellingLogoCenter) * settle;
                        return SizedBox(
                          width: width,
                          height: 220,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                left: logoCenterX - (36 + jumpY * .22) / 2,
                                top: 152,
                                width: 36 + jumpY * .22,
                                height: 7,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: LumearColors.maroon.withValues(
                                      alpha:
                                          (.16 + jumpY * .0014) *
                                          (1 - movement),
                                    ),
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                ),
                              ),
                              Positioned(
                                // The same logo travels right → left in exactly
                                // two hops, then slides left → right on the ground.
                                left: logoCenterX - 39,
                                top: (220 - 78) / 2 + jumpY,
                                width: 78,
                                height: 78,
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              Positioned(
                                left: finalWordLeft * settle,
                                width: width - 94,
                                top: 78,
                                height: 68,
                                child: ClipRect(
                                  key: const ValueKey('lumear-word-mask'),
                                  clipper: LumearWordMask(movement),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text('LUMEAR', style: wordStyle),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 20,
                                left: 12,
                                right: 12,
                                child: Opacity(
                                  opacity: taglineProgress,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'FIND YOUR KIND OF EVERYDAY.',
                                      style: TextStyle(
                                        color: LumearColors.maroon,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.8,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _IntroWaveBackground extends CustomPainter {
  const _IntroWaveBackground();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = LumearColors.cream);
    final wave = Path()
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * .61)
      ..cubicTo(
        size.width * .78,
        size.height * .56,
        size.width * .76,
        size.height * .42,
        size.width * .40,
        size.height * .42,
      )
      ..cubicTo(
        size.width * .20,
        size.height * .42,
        size.width * .08,
        size.height * .40,
        0,
        size.height * .36,
      )
      ..close();
    canvas.drawShadow(
      wave,
      LumearColors.light.withValues(alpha: .13),
      12,
      false,
    );
    canvas.drawPath(
      wave,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [LumearColors.field, LumearColors.cream],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(covariant _IntroWaveBackground oldDelegate) => false;
}

/// Reveal full-size typography without fading or resizing its letters.
class LumearWordMask extends CustomClipper<Rect> {
  const LumearWordMask(this.progress);
  final double progress;
  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * progress.clamp(0.0, 1.0), size.height);
  @override
  bool shouldReclip(LumearWordMask oldClipper) =>
      oldClipper.progress != progress;
}
