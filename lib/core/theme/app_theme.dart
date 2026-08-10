import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';

class AppTheme {
  AppTheme(this.mode, this.fontFamily);
  final AppThemeMode mode;
  final String fontFamily;

  // === TOPOR VPN brand palette (matches the Telegram mini-app) ===
  static const Color brandOrange = Color(0xFFFF7A3D); // --a1
  static const Color brandPink = Color(0xFFFF4D6D); // --a2
  static const Color brandBg = Color(0xFF0B0E14); // --bg
  static const Color brandCard = Color(0xFF141A24); // --card
  static const Color brandCard2 = Color(0xFF1B2230); // --card2
  static const Color brandText = Color(0xFFEEF2F7); // --text
  static const Color brandHint = Color(0xFF8B95A7); // --hint
  static const Color brandOk = Color(0xFF32D583); // --ok

  // Applied AFTER ThemeData is built so the display font survives the
  // internal textTheme.apply(fontFamily) (fontFamily is "" on macOS/ru).
  static TextTheme _brandHeadings(TextTheme t) {
    TextStyle? h(TextStyle? s, FontWeight w) => s?.copyWith(fontFamily: 'Oswald', fontWeight: w);
    return t.copyWith(
      displayLarge: h(t.displayLarge, FontWeight.w700),
      displayMedium: h(t.displayMedium, FontWeight.w700),
      displaySmall: h(t.displaySmall, FontWeight.w700),
      headlineLarge: h(t.headlineLarge, FontWeight.w700),
      headlineMedium: h(t.headlineMedium, FontWeight.w600),
      headlineSmall: h(t.headlineSmall, FontWeight.w600),
      titleLarge: h(t.titleLarge, FontWeight.w600),
    );
  }

  // Mini-app component styling applied to every screen at once.
  static ThemeData _applyBrand(ThemeData theme) {
    final scheme = theme.colorScheme;
    RoundedRectangleBorder r(double radius, {BorderSide side = BorderSide.none}) =>
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: side);
    return theme.copyWith(
      textTheme: _brandHeadings(theme.textTheme),
      splashFactory: InkSparkle.splashFactory,
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: r(20, side: BorderSide(color: scheme.outlineVariant)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: r(14),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(shape: r(14), elevation: 0),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: r(14), side: BorderSide(color: scheme.outlineVariant)),
      ),
      listTileTheme: ListTileThemeData(shape: r(14)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
        enabledBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: scheme.outlineVariant)),
        focusedBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: scheme.primary, width: 1.5)),
      ),
      chipTheme: ChipThemeData(shape: r(20), side: BorderSide(color: scheme.outlineVariant)),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: .18),
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: .18),
        selectedIconTheme: IconThemeData(color: scheme.primary),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    );
  }

  ThemeData lightTheme(ColorScheme? lightColorScheme) {
    final ColorScheme scheme = lightColorScheme ??
        ColorScheme.fromSeed(seedColor: brandOrange).copyWith(
          primary: const Color(0xFFE85D2B),
          secondary: brandPink,
        );
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      extensions: const <ThemeExtension<dynamic>>{ConnectionButtonTheme.light},
    );
    return _applyBrand(theme);
  }

  ThemeData darkTheme(ColorScheme? darkColorScheme) {
    final ColorScheme scheme = darkColorScheme ??
        ColorScheme.fromSeed(seedColor: brandOrange, brightness: Brightness.dark).copyWith(
          primary: brandOrange,
          onPrimary: Colors.white,
          secondary: brandPink,
          onSecondary: Colors.white,
          surface: brandBg,
          onSurface: brandText,
          surfaceContainerLowest: const Color(0xFF090C11),
          surfaceContainerLow: brandCard,
          surfaceContainer: brandCard,
          surfaceContainerHigh: brandCard2,
          surfaceContainerHighest: brandCard2,
          onSurfaceVariant: brandHint,
          outline: const Color(0xFF2A3446),
          outlineVariant: const Color(0xFF1C2432),
        );
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: mode.trueBlack ? Colors.black : brandBg,
      fontFamily: fontFamily,
      extensions: const <ThemeExtension<dynamic>>{ConnectionButtonTheme.light},
    );
    return _applyBrand(theme);
  }

  CupertinoThemeData cupertinoThemeData(bool sysDark, ColorScheme? lightColorScheme, ColorScheme? darkColorScheme) {
    final bool isDark = switch (mode) {
      AppThemeMode.system => sysDark,
      AppThemeMode.light => false,
      AppThemeMode.dark => true,
      AppThemeMode.black => true,
    };
    final def = CupertinoThemeData(brightness: isDark ? Brightness.dark : Brightness.light);
    // final def = CupertinoThemeData(brightness: Brightness.dark);

    // return def;
    final defaultMaterialTheme = isDark ? darkTheme(darkColorScheme) : lightTheme(lightColorScheme);
    return MaterialBasedCupertinoThemeData(
      materialTheme: defaultMaterialTheme.copyWith(
        cupertinoOverrideTheme: def.copyWith(
          textTheme: CupertinoTextThemeData(
            textStyle: def.textTheme.textStyle.copyWith(fontFamily: fontFamily),
            actionTextStyle: def.textTheme.actionTextStyle.copyWith(fontFamily: fontFamily),
            navActionTextStyle: def.textTheme.navActionTextStyle.copyWith(fontFamily: fontFamily),
            navTitleTextStyle: def.textTheme.navTitleTextStyle.copyWith(fontFamily: fontFamily),
            navLargeTitleTextStyle: def.textTheme.navLargeTitleTextStyle.copyWith(fontFamily: fontFamily),
            pickerTextStyle: def.textTheme.pickerTextStyle.copyWith(fontFamily: fontFamily),
            dateTimePickerTextStyle: def.textTheme.dateTimePickerTextStyle.copyWith(fontFamily: fontFamily),
            tabLabelTextStyle: def.textTheme.tabLabelTextStyle.copyWith(fontFamily: fontFamily),
          ).copyWith(),
          barBackgroundColor: def.barBackgroundColor,
          scaffoldBackgroundColor: def.scaffoldBackgroundColor,
        ),
      ),
    );
  }
}
