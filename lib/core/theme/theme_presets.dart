import 'package:flutter/material.dart';

/// A selectable color preset; each builds a Material-3 light/dark [ThemeData] from a seed color.
class ThemePreset {
  final String name;
  final Color seed;
  const ThemePreset(this.name, this.seed);

  ThemeData theme(bool dark) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: dark ? Brightness.dark : Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    );
  }
}

const List<ThemePreset> kThemePresets = [
  ThemePreset('Indigo', Color(0xFF4F46E5)),
  ThemePreset('Emerald', Color(0xFF059669)),
  ThemePreset('Sunset', Color(0xFFEA580C)),
  ThemePreset('Graphite', Color(0xFF475569)),
];
