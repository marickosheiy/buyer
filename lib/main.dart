import 'package:flutter/material.dart';

import 'intro_screen.dart';
import 'design/lumear_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LumearAppearance.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LumearAppearance.instance,
      builder: (context, _) => LumearAppearanceScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Lumear',
          theme: lumearTheme(dark: false),
          darkTheme: lumearTheme(dark: true),
          themeMode: LumearAppearance.instance.mode,
          home: const IntroScreen(),
        ),
      ),
    );
  }
}
