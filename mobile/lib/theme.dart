import 'package:flutter/material.dart';

/// Central design system for the app -- one place to tune color/shape/type
/// instead of each screen hand-rolling its own Containers and TextStyles.
/// Brand colors are lifted directly from the same logo used as the web app's
/// favicon (packages/frontend/public/favicon.svg) and the Android launcher
/// icon, so all three surfaces (web, mobile, app icon) share one identity.

const brandPurple = Color(0xFF863BFF);
const brandPurpleDeep = Color(0xFF7E14FF);
const brandBlue = Color(0xFF47BFFF);

// Refined from the original flat 0xFF0CA30C/0xFFE66767 -- less saturated,
// closer to what modern market-data apps use so a screenful of deltas reads
// calmly instead of like a stoplight.
const upColor = Color(0xFF16C784);
const downColor = Color(0xFFEA4C6B);
const warningColor = Color(0xFFF5A524);

ThemeData buildLightTheme() => _build(
  ColorScheme.fromSeed(seedColor: brandPurple, brightness: Brightness.light).copyWith(secondary: brandBlue),
);

ThemeData buildDarkTheme() => _build(
  ColorScheme.fromSeed(seedColor: brandPurple, brightness: Brightness.dark).copyWith(
    secondary: brandBlue,
    surface: const Color(0xFF13101C),
    surfaceContainerLow: const Color(0xFF181420),
    surfaceContainer: const Color(0xFF1C1826),
    surfaceContainerHigh: const Color(0xFF231E2E),
    surfaceContainerHighest: const Color(0xFF2A2436),
  ),
);

ThemeData _build(ColorScheme scheme) {
  final radius = BorderRadius.circular(16);
  final pill = const StadiumBorder();

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: InkSparkle.splashFactory,
    textTheme: _textTheme(scheme),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: radius),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.primaryContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHighest,
      selectedColor: scheme.primaryContainer,
      disabledColor: scheme.surfaceContainerHighest,
      labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: scheme.onSurface),
      secondaryLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: scheme.onPrimaryContainer),
      shape: pill,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.error, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(textStyle: const TextStyle(fontWeight: FontWeight.w600)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5), thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    tabBarTheme: TabBarThemeData(
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      indicatorColor: scheme.primary,
      dividerColor: Colors.transparent,
    ),
  );
}

TextTheme _textTheme(ColorScheme scheme) {
  return TextTheme(
    headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: scheme.onSurface),
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: scheme.onSurface),
    titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurface),
    bodyLarge: TextStyle(fontSize: 15, color: scheme.onSurface, height: 1.4),
    bodyMedium: TextStyle(fontSize: 13.5, color: scheme.onSurface, height: 1.4),
    bodySmall: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, height: 1.3),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: scheme.onSurface),
  );
}
