import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One appearance preference shared by every buyer and seller route.
class LumearAppearance extends ChangeNotifier with WidgetsBindingObserver {
  LumearAppearance._();
  static final instance = LumearAppearance._();
  static const channel = MethodChannel('lumear/appearance');
  ThemeMode mode = ThemeMode.light;
  bool get isDark =>
      mode == ThemeMode.dark ||
      (mode == ThemeMode.system &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark);
  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    try {
      final saved = await channel.invokeMethod<String>('read');
      mode = ThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => ThemeMode.light,
      );
    } on MissingPluginException {
      /* Other platforms follow the device setting. */
    } on PlatformException {
      /* Retain system appearance when storage is unavailable. */
    }
  }

  Future<void> setMode(ThemeMode value) async {
    mode = value;
    notifyListeners();
    try {
      await channel.invokeMethod<void>('write', value.name);
    } on MissingPluginException {
      /* Widget tests and unsupported hosts. */
    } on PlatformException {
      /* Retain the choice for this session. */
    }
  }

  @override
  void didChangePlatformBrightness() {
    if (mode == ThemeMode.system) notifyListeners();
  }

  static void watch(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<LumearAppearanceScope>();
  }

  static Widget build(BuildContext context, Widget Function() builder) {
    watch(context);
    return builder();
  }
}

class LumearAppearanceScope extends InheritedNotifier<LumearAppearance> {
  LumearAppearanceScope({super.key, required super.child})
    : super(notifier: LumearAppearance.instance);
}

abstract final class LumearColors {
  static const brandMaroon = Color(0xFF651D32);
  static const beige = Color(0xFFF4E8D8);
  static const ivory = Color(0xFFFFFDF9);
  static const gold = Color(0xFFC9A36A);
  static const charcoal = Color(0xFF292323);
  static bool get isDark => LumearAppearance.instance.isDark;
  static Color get cream => isDark ? const Color(0xFF151112) : ivory;
  static Color get surface => isDark ? const Color(0xFF241B1E) : ivory;
  static Color get field => isDark ? const Color(0xFF2D2327) : beige;
  static Color get maroon => isDark ? const Color(0xFFD294A4) : brandMaroon;
  static Color get action => isDark ? const Color(0xFF94415B) : brandMaroon;
  static Color get dark => isDark ? ivory : brandMaroon;
  static Color get ink => isDark ? beige : charcoal;
  static Color get light =>
      isDark ? const Color(0xFFC5AEA8) : const Color(0xFF78645C);
  static Color get border =>
      isDark ? const Color(0xFF4C383F) : const Color(0xFFE1D2BD);
  static Color get onAction => ivory;
  static Color get success =>
      isDark ? const Color(0xFF90CBA8) : const Color(0xFF287049);
}

class AppearanceButton extends StatelessWidget {
  const AppearanceButton({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: LumearAppearance.instance,
    builder: (context, _) => Tooltip(
      message: 'Dark mode',
      child: Switch.adaptive(
        value: LumearAppearance.instance.isDark,
        thumbIcon: WidgetStateProperty.resolveWith(
          (states) => Icon(
            states.contains(WidgetState.selected)
                ? Icons.dark_mode
                : Icons.light_mode,
            size: 16,
          ),
        ),
        onChanged: (enabled) => LumearAppearance.instance.setMode(
          enabled ? ThemeMode.dark : ThemeMode.light,
        ),
      ),
    ),
  );
}

ThemeData lumearTheme({bool? dark}) {
  final isDark = dark ?? LumearAppearance.instance.isDark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: LumearColors.brandMaroon,
        brightness: isDark ? Brightness.dark : Brightness.light,
      ).copyWith(
        primary: isDark ? const Color(0xFFD294A4) : LumearColors.brandMaroon,
        onPrimary: isDark ? LumearColors.charcoal : LumearColors.ivory,
        secondary: LumearColors.gold,
        onSecondary: LumearColors.charcoal,
        surface: isDark ? const Color(0xFF241B1E) : LumearColors.ivory,
        onSurface: isDark ? LumearColors.beige : LumearColors.charcoal,
        onSurfaceVariant: isDark
            ? const Color(0xFFC5AEA8)
            : const Color(0xFF78645C),
        outline: isDark ? const Color(0xFF6A505A) : const Color(0xFFAC9587),
        outlineVariant: isDark
            ? const Color(0xFF4C383F)
            : const Color(0xFFE1D2BD),
      );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final action = isDark ? const Color(0xFF94415B) : LumearColors.brandMaroon;
  final background = isDark ? const Color(0xFF151112) : LumearColors.ivory;
  final field = isDark ? const Color(0xFF2D2327) : LumearColors.beige;
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
  );
  return base.copyWith(
    scaffoldBackgroundColor: background,
    textTheme: base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      toolbarHeight: 64,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      shape: rounded,
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: scheme.surface),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: isDark ? action : LumearColors.beige,
      height: 72,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          color: scheme.onSurface,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: action,
        foregroundColor: LumearColors.ivory,
        minimumSize: const Size(48, 48),
        shape: rounded,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: action,
        foregroundColor: LumearColors.ivory,
        elevation: 0,
        minimumSize: const Size(48, 48),
        shape: rounded,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.outlineVariant),
        minimumSize: const Size(48, 48),
        shape: rounded,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: field,
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: LumearColors.charcoal,
      contentTextStyle: TextStyle(color: LumearColors.ivory),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: .7),
  );
}
