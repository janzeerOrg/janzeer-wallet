import 'package:flutter/material.dart';

import 'jz_tokens.dart';

/// One brand theme per brightness, built from [JzColors] (the explorer's tokens). System fonts, as on the web
/// (`--font: system-ui …`); numbers and hashes use the platform monospace with tabular figures.
/// [fontFamilyFallback] is for tests (the golden harness loads DejaVu for Arabic); devices fall back on their own.
ThemeData buildJzTheme(Brightness brightness, {List<String> fontFamilyFallback = const []}) {
  final c = brightness == Brightness.dark ? JzColors.dark : JzColors.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.accent,
    onPrimary: c.onAccent,
    secondary: c.accent,
    onSecondary: c.onAccent,
    tertiary: JzColors.emerald,
    onTertiary: c.onAccent,
    error: c.danger,
    onError: Colors.white,
    surface: c.surface,
    onSurface: c.text,
    surfaceContainerHighest: c.surface3,
    surfaceContainerHigh: c.surface2,
    surfaceContainer: c.surface2,
    surfaceContainerLow: c.surface,
    surfaceContainerLowest: c.bg,
    onSurfaceVariant: c.muted,
    outline: c.borderStrong,
    outlineVariant: c.border,
    primaryContainer: c.accentWeak,
    onPrimaryContainer: c.text,
    secondaryContainer: c.surface3,
    onSecondaryContainer: c.text,
    inverseSurface: c.text,
    onInverseSurface: c.bg,
    shadow: Colors.black,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
  // Derive from the platform typography (keeps its font family — Roboto on Android — and the test fallback).
  final t0 = base.textTheme.apply(bodyColor: c.text, displayColor: c.text, fontFamilyFallback: fontFamilyFallback);
  final text = t0.copyWith(
    titleLarge: t0.titleLarge!.copyWith(fontSize: 22, fontWeight: FontWeight.w700, color: c.text, letterSpacing: -0.2),
    titleMedium: t0.titleMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: c.text),
    titleSmall: t0.titleSmall!.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: c.text),
    bodyLarge: t0.bodyLarge!.copyWith(fontSize: 16, color: c.text, height: 1.4),
    bodyMedium: t0.bodyMedium!.copyWith(fontSize: 14, color: c.text, height: 1.45),
    bodySmall: t0.bodySmall!.copyWith(fontSize: 12.5, color: c.muted, height: 1.4),
    labelLarge: t0.labelLarge!.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: c.text),
    labelMedium: t0.labelMedium!.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500, color: c.muted),
    labelSmall: t0.labelSmall!.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.faint, letterSpacing: 0.5),
  );
  final body = text.bodyMedium!;
  final radiusSm = JzRadius.rSm;
  final radiusMd = JzRadius.rMd;
  OutlineInputBorder border(Color color, [double w = 1]) => OutlineInputBorder(borderRadius: radiusSm, borderSide: BorderSide(color: color, width: w));

  return base.copyWith(
    extensions: [c],
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    textTheme: text,
    dividerColor: c.border,
    dividerTheme: DividerThemeData(color: c.border, space: 1, thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: c.text,
      titleTextStyle: body.copyWith(fontSize: 17, fontWeight: FontWeight.w700, color: c.text, letterSpacing: -0.1),
      iconTheme: IconThemeData(color: c.muted, size: 22),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radiusMd, side: BorderSide(color: c.border)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface2,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      border: border(c.borderStrong),
      enabledBorder: border(c.borderStrong),
      focusedBorder: border(c.accent, 1.5),
      errorBorder: border(c.danger),
      focusedErrorBorder: border(c.danger, 1.5),
      labelStyle: body.copyWith(color: c.muted, fontSize: 13.5),
      floatingLabelStyle: body.copyWith(color: c.accent, fontSize: 13),
      hintStyle: body.copyWith(color: c.faint, fontSize: 14),
      helperStyle: body.copyWith(color: c.faint, fontSize: 12),
      counterStyle: body.copyWith(color: c.faint, fontSize: 11.5),
      prefixIconColor: c.muted,
      suffixIconColor: c.muted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        textStyle: body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: radiusSm),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.text,
        backgroundColor: c.surface2,
        side: BorderSide(color: c.borderStrong),
        textStyle: body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: radiusSm),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.muted,
        textStyle: body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: radiusSm),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: c.muted)),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accentWeak : c.surface2),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : c.muted),
        side: WidgetStatePropertyAll(BorderSide(color: c.borderStrong)),
        textStyle: WidgetStatePropertyAll(body.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: radiusSm)),
        visualDensity: VisualDensity.compact,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surface2,
      selectedColor: c.accentWeak,
      side: BorderSide(color: c.border),
      labelStyle: body.copyWith(color: c.text, fontSize: 13, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onAccent : c.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : c.surface3),
      trackOutlineColor: WidgetStatePropertyAll(c.borderStrong),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.accentWeak,
      elevation: 0,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? c.accent : c.muted, size: 22)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => body.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: s.contains(WidgetState.selected) ? c.accent : c.muted)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: c.surface,
      indicatorColor: c.accentWeak,
      selectedIconTheme: IconThemeData(color: c.accent),
      unselectedIconTheme: IconThemeData(color: c.muted),
      selectedLabelTextStyle: body.copyWith(color: c.accent, fontWeight: FontWeight.w600, fontSize: 13),
      unselectedLabelTextStyle: body.copyWith(color: c.muted, fontWeight: FontWeight.w600, fontSize: 13),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(JzRadius.lg))),
      showDragHandle: true,
      dragHandleColor: c.borderStrong,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: JzRadius.rLg, side: BorderSide(color: c.border)),
      titleTextStyle: body.copyWith(fontSize: 17, fontWeight: FontWeight.w700, color: c.text),
      contentTextStyle: body.copyWith(fontSize: 14, color: c.text, height: 1.45),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.surface3,
      contentTextStyle: body.copyWith(color: c.text, fontSize: 13.5),
      shape: RoundedRectangleBorder(borderRadius: radiusSm, side: BorderSide(color: c.borderStrong)),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent, linearTrackColor: c.surface3),
    listTileTheme: ListTileThemeData(iconColor: c.muted, textColor: c.text, contentPadding: const EdgeInsets.symmetric(horizontal: 16)),
    splashFactory: InkSparkle.splashFactory,
  );
}
