import 'dart:async';

import 'package:flutter/material.dart';

import '../design/brand_art.dart';
import '../design/lumear_image.dart';
import '../design/lumear_theme.dart';
import '../product_model.dart';
import '../screen/product_detail_screen.dart';

class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key});
  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final controller = PageController();
  Timer? timer;
  int current = 0;
  List<LumearProduct> get picks => ProductCatalog.instance.connected
      ? lumearProducts.take(3).toList()
      : [lumearProducts[7], lumearProducts[1], lumearProducts[3]];
  final titles = [
    'YOUR DAY.\nYOUR WAY.',
    'TURN UP\nTHE EVERYDAY.',
    'SMALL THINGS.\nBIG ENERGY.',
  ];
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted ||
          picks.isEmpty ||
          !controller.hasClients ||
          MediaQuery.disableAnimationsOf(context)) {
        return;
      }
      controller.animateToPage(
        (current + 1) % picks.length,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LumearAppearance.build(
    context,
    () => ListenableBuilder(
      listenable: ProductCatalog.instance,
      builder: (context, _) => _content(context),
    ),
  );

  Widget _content(BuildContext context) => picks.isEmpty
      ? Container(
          height: 274,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: LumearColors.brandMaroon,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Text(
            'YOUR DAY.\nYOUR WAY.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LumearColors.ivory,
              fontWeight: FontWeight.w900,
              fontSize: 30,
            ),
          ),
        )
      : Column(
          children: [
            SizedBox(
              height: 274,
              child: PageView.builder(
                controller: controller,
                itemCount: picks.length,
                onPageChanged: (i) => setState(() => current = i),
                itemBuilder: (context, i) {
                  final p = picks[i];
                  final discount = p.originalPrice == null
                      ? 0
                      : ((1 - p.price / p.originalPrice!) * 100).round();
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 5,
                    ),
                    child: Material(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(26),
                        topRight: Radius.circular(26),
                        bottomLeft: Radius.circular(26),
                        bottomRight: Radius.circular(6),
                      ),
                      color: i == 1
                          ? LumearColors.brandMaroon
                          : LumearColors.charcoal,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(product: p),
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final w = constraints.maxWidth;
                            return Stack(
                              children: [
                                Positioned(
                                  right: -55,
                                  top: -90,
                                  child: Container(
                                    width: 285,
                                    height: 285,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: LumearColors.light.withValues(
                                          alpha: .5,
                                        ),
                                        width: 38,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 20,
                                  bottom: -100,
                                  child: Container(
                                    width: 230,
                                    height: 230,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: LumearColors.light.withValues(
                                          alpha: .25,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: w * .045,
                                  top: 35,
                                  width: w * .43,
                                  height: 200,
                                  child: Transform.rotate(
                                    angle: .09,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: LumearColors.ivory,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: LumearColors.dark.withValues(
                                              alpha: .3,
                                            ),
                                            blurRadius: 20,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(7),
                                        child: LumearImage(
                                          p.imageUrl,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 20,
                                  right: w * .48,
                                  top: 22,
                                  bottom: 22,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      RuledLabel(
                                        '${p.category} / THE GOOD FINDS',
                                        light: true,
                                      ),
                                      const SizedBox(height: 19),
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.topLeft,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.topLeft,
                                            child: Text(
                                              titles[i],
                                              style: TextStyle(
                                                fontSize: 39,
                                                fontWeight: FontWeight.w900,
                                                color: LumearColors.ivory,
                                                height: .96,
                                                letterSpacing: -1.8,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'From ${p.formattedPrice}',
                                        style: TextStyle(
                                          color: LumearColors.ivory,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 13,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: LumearColors.ivory,
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                'Meet your next find',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color:
                                                      LumearColors.brandMaroon,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 6),
                                            Icon(
                                              Icons.north_east,
                                              size: 15,
                                              color: LumearColors.brandMaroon,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  right: 5,
                                  top: 5,
                                  child: Transform.rotate(
                                    angle: .15,
                                    child: Burst(
                                      label: discount > 0
                                          ? '$discount%\nOFF'
                                          : 'THE\nEDIT',
                                      size: 62,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 12,
                                  bottom: 9,
                                  child: Icon(
                                    Icons.auto_awesome,
                                    color: LumearColors.ivory,
                                    size: 30,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                children: [
                  Text(
                    '0${current + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: LumearColors.brandMaroon,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '/ 03',
                    style: TextStyle(fontSize: 10, color: LumearColors.ink),
                  ),
                  const Spacer(),
                  for (int i = 0; i < picks.length; i++)
                    Semantics(
                      label: 'Collection ${i + 1}',
                      selected: i == current,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => controller.animateToPage(
                          i,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOut,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 14,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 5,
                            width: i == current ? 28 : 6,
                            decoration: BoxDecoration(
                              color: i == current
                                  ? LumearColors.dark
                                  : LumearColors.light,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
}
