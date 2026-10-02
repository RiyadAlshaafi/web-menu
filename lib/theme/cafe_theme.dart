import 'package:flutter/material.dart';

class CafeColors {
  static const cream = Color(0xFFFDF9F2);
  static const creamDark = Color(0xFFF1EDE7);
  static const paper = Color(0xFFFFFFFF);
  static const card = Color(0xFFFFFCF8);
  static const terracotta = Color(0xFFBA5333);
  static const terracottaDark = Color(0xFF9A3C1D);
  static const terracottaSoft = Color(0xFFFFDBD1);
  static const peach = Color(0xFFF6DED1);
  static const ink = Color(0xFF1C1C18);
  static const inkMuted = Color(0xFF56423C);
  static const line = Color(0xFFE8E6DE);
  static const key = Color(0xFFF7F3ED);
  static const success = Color(0xFF4F7A45);
  static const alert = Color(0xFFBA1A1A);
  static const sidebar = Color(0xFFFFFFFF);

  static const defaultHeader = Color(0xFF1B3A4B);
  static const defaultSidebar = Color(0xFFFFFFFF);
  static const defaultBackground = Color(0xFFE7EEF2);
  static const defaultButton = Color(0xFFBA5333);

  static Color contrastOn(Color color) => color.computeLuminance() > 0.55 ? ink : const Color(0xFFFFFFFF);

  static Color parseHex(String? value, Color fallback) {
    final raw = (value ?? '').trim().replaceFirst('#', '');
    if (raw.length != 6 && raw.length != 8) return fallback;
    final parsed = int.tryParse(raw, radix: 16);
    if (parsed == null) return fallback;
    return Color(raw.length == 6 ? 0xFF000000 | parsed : parsed);
  }

  static String toHex(Color color) {
    final argb = color.toARGB32();
    return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}

class CafeSurfaces extends ThemeExtension<CafeSurfaces> {
  const CafeSurfaces({
    required this.header,
    required this.sidebar,
    required this.background,
    required this.button,
  });

  final Color header;
  final Color sidebar;
  final Color background;
  final Color button;

  Color get onHeader => CafeColors.contrastOn(header);
  Color get onSidebar => CafeColors.contrastOn(sidebar);
  Color get onBackground => CafeColors.contrastOn(background);
  Color get onButton => CafeColors.contrastOn(button);

  static const defaults = CafeSurfaces(
    header: CafeColors.defaultHeader,
    sidebar: CafeColors.defaultSidebar,
    background: CafeColors.defaultBackground,
    button: CafeColors.defaultButton,
  );

  static CafeSurfaces of(BuildContext context) => Theme.of(context).extension<CafeSurfaces>() ?? defaults;

  factory CafeSurfaces.fromCafe(Map<String, dynamic> cafe) => CafeSurfaces(
        header: CafeColors.parseHex(cafe['headerColor'] as String?, CafeColors.defaultHeader),
        sidebar: CafeColors.parseHex(cafe['sidebarColor'] as String?, CafeColors.defaultSidebar),
        background: CafeColors.parseHex(cafe['backgroundColor'] as String?, CafeColors.defaultBackground),
        button: CafeColors.parseHex(cafe['buttonColor'] as String?, CafeColors.defaultButton),
      );

  @override
  CafeSurfaces copyWith({Color? header, Color? sidebar, Color? background, Color? button}) => CafeSurfaces(
        header: header ?? this.header,
        sidebar: sidebar ?? this.sidebar,
        background: background ?? this.background,
        button: button ?? this.button,
      );

  @override
  CafeSurfaces lerp(ThemeExtension<CafeSurfaces>? other, double t) {
    if (other is! CafeSurfaces) return this;
    return CafeSurfaces(
      header: Color.lerp(header, other.header, t) ?? header,
      sidebar: Color.lerp(sidebar, other.sidebar, t) ?? sidebar,
      background: Color.lerp(background, other.background, t) ?? background,
      button: Color.lerp(button, other.button, t) ?? button,
    );
  }
}

class CafeMotion {
  static const easeOut = Cubic(0.23, 1, 0.32, 1);
  static const easeInOut = Cubic(0.77, 0, 0.175, 1);
  static const quick = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
}

class CafePageTransitionsBuilder extends PageTransitionsBuilder {
  const CafePageTransitionsBuilder();

  static final _rise = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: CafeMotion.easeOut,
      reverseCurve: CafeMotion.easeOut.flipped,
    );
    final faded = FadeTransition(opacity: curved, child: child);
    if (MediaQuery.disableAnimationsOf(context)) return faded;
    return SlideTransition(position: _rise.animate(curved), child: faded);
  }
}

class CafeTheme {
  static ThemeData get light => forSurfaces(CafeSurfaces.defaults);

  static ThemeData forSurfaces(CafeSurfaces surfaces) {
    final textTheme = ThemeData(fontFamily: 'PlusJakartaSans').textTheme.apply(
      bodyColor: CafeColors.ink,
      displayColor: CafeColors.ink,
    );
    final onButton = surfaces.onButton;
    final scheme = ColorScheme.fromSeed(seedColor: surfaces.button, surface: CafeColors.paper).copyWith(
      primary: surfaces.button,
      onPrimary: onButton,
    );
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'PlusJakartaSans',
      colorScheme: scheme,
      scaffoldBackgroundColor: surfaces.background,
      canvasColor: surfaces.background,
      extensions: [surfaces],
      appBarTheme: AppBarTheme(
        backgroundColor: surfaces.header,
        foregroundColor: surfaces.onHeader,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(backgroundColor: surfaces.button, foregroundColor: onButton, shape: buttonShape),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(backgroundColor: surfaces.button, foregroundColor: onButton, shape: buttonShape),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: surfaces.button, foregroundColor: onButton),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? onButton : null),
        trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? surfaces.button : null),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? surfaces.button : null),
        checkColor: WidgetStateProperty.all(onButton),
        side: WidgetStateBorderSide.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return BorderSide(color: surfaces.button, width: 2);
          return const BorderSide(color: CafeColors.inkMuted, width: 2);
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? surfaces.button : CafeColors.inkMuted),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: surfaces.button,
        disabledColor: CafeColors.line,
        labelStyle: TextStyle(color: CafeColors.ink, fontWeight: FontWeight.w700),
        secondaryLabelStyle: TextStyle(color: onButton, fontWeight: FontWeight.w700),
        checkmarkColor: onButton,
        side: WidgetStateBorderSide.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return BorderSide(color: surfaces.button, width: 1.5);
          return const BorderSide(color: CafeColors.line);
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CafePageTransitionsBuilder(),
          TargetPlatform.iOS: CafePageTransitionsBuilder(),
          TargetPlatform.macOS: CafePageTransitionsBuilder(),
          TargetPlatform.windows: CafePageTransitionsBuilder(),
          TargetPlatform.linux: CafePageTransitionsBuilder(),
          TargetPlatform.fuchsia: CafePageTransitionsBuilder(),
        },
      ),
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CafeColors.key,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: surfaces.button, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
    );
  }

  static const display = TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontWeight: FontWeight.w600,
        color: CafeColors.ink,
        height: 1.15,
        letterSpacing: -0.4,
      );

  static const brand = TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontWeight: FontWeight.w700,
        color: CafeColors.ink,
        letterSpacing: -0.4,
      );
}
