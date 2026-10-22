import 'package:flutter/material.dart';

import 'lumear_theme.dart';

/// A compact navigation dock with a distinct selected state on every destination.
class LumearDock extends StatelessWidget {
  const LumearDock({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<NavigationDestination> destinations;
  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => DecoratedBox(
      decoration: BoxDecoration(
        color: LumearColors.cream,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: LumearColors.border),
        boxShadow: [
          BoxShadow(
            color: LumearColors.dark.withValues(alpha: .08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 7, 6, 5),
          child: Row(
            children: [
              for (int i = 0; i < destinations.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == selectedIndex,
                    button: true,
                    label: destinations[i].label,
                    excludeSemantics: true,
                    onTap: () => onSelected(i),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => onSelected(i),
                      child: SizedBox(
                        height: 58,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: i == selectedIndex
                                    ? LumearColors.action
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: IconTheme(
                                data: IconThemeData(
                                  size: 21,
                                  color: i == selectedIndex
                                      ? LumearColors.ivory
                                      : LumearColors.ink,
                                ),
                                child: i == selectedIndex
                                    ? destinations[i].selectedIcon ??
                                          destinations[i].icon
                                    : destinations[i].icon,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              destinations[i].label,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 9,
                                color: LumearColors.dark,
                                fontWeight: i == selectedIndex
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
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
  );
}

/// Brand-native decorative art: no new palette or replacement logo.
class Burst extends StatelessWidget {
  const Burst({
    super.key,
    required this.label,
    this.size = 72,
    this.dark = false,
  });
  final String label;
  final double size;
  final bool dark;
  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _BurstPainter(dark ? LumearColors.action : LumearColors.cream),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FittedBox(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dark ? LumearColors.ivory : LumearColors.dark,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: .95,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _BurstPainter extends CustomPainter {
  const _BurstPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final path = Path();
    // Alternating points form a paper-like retail sticker.
    const points = <Offset>[
      Offset(.5, 0),
      Offset(.58, .1),
      Offset(.69, .04),
      Offset(.72, .17),
      Offset(.85, .15),
      Offset(.83, .28),
      Offset(.96, .31),
      Offset(.9, .42),
      Offset(1, .5),
      Offset(.9, .58),
      Offset(.96, .69),
      Offset(.83, .72),
      Offset(.85, .85),
      Offset(.72, .83),
      Offset(.69, .96),
      Offset(.58, .9),
      Offset(.5, 1),
      Offset(.42, .9),
      Offset(.31, .96),
      Offset(.28, .83),
      Offset(.15, .85),
      Offset(.17, .72),
      Offset(.04, .69),
      Offset(.1, .58),
      Offset(0, .5),
      Offset(.1, .42),
      Offset(.04, .31),
      Offset(.17, .28),
      Offset(.15, .15),
      Offset(.28, .17),
      Offset(.31, .04),
      Offset(.42, .1),
    ];
    for (int i = 0; i < points.length; i++) {
      final p = Offset(points[i].dx * size.width, points[i].dy * size.height);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawCircle(
      center,
      size.shortestSide * .32,
      Paint()
        ..color =
            (color == LumearColors.dark
                    ? LumearColors.ivory
                    : LumearColors.maroon)
                .withValues(alpha: .2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .6,
    );
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) => oldDelegate.color != color;
}

class RuledLabel extends StatelessWidget {
  const RuledLabel(this.text, {super.key, this.light = false});
  final String text;
  final bool light;
  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => Row(
      children: [
        Icon(
          Icons.auto_awesome,
          size: 13,
          color: light ? LumearColors.ivory : LumearColors.maroon,
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            text.toUpperCase(),
            style: TextStyle(
              color: light ? LumearColors.ivory : LumearColors.maroon,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}
