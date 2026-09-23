import 'package:flutter/material.dart';

/// Paleta inspirada en una placa de circuito impreso: máscara de soldadura
/// verde, pistas de cobre, serigrafía blanca y trazos de osciloscopio.
class BoardColors {
  BoardColors._();

  static const mask = Color(0xFF0A2E22);
  static const maskDeep = Color(0xFF061F17);
  static const maskRaised = Color(0xFF103B2C);
  static const maskHigh = Color(0xFF164A38);
  static const trace = Color(0xFF1F6B4F);
  static const copper = Color(0xFFE0994A);
  static const copperDim = Color(0xFF9C6A35);
  static const silk = Color(0xFFEFF5F1);
  static const silkDim = Color(0xFFA9C2B6);
  static const signal = Color(0xFF53E0C9);
  static const truth = Color(0xFFF5F5F0);
  static const ok = Color(0xFF6BD68A);
  static const warn = Color(0xFFF2C14E);
  static const crit = Color(0xFFFF6B5E);
  static const hint = Color(0xFF8FB8FF);
  static const scopeGrid = Color(0xFF15503C);
}

class BoardTheme {
  BoardTheme._();

  static ThemeData build() {
    const scheme = ColorScheme.dark(
      primary: BoardColors.copper,
      onPrimary: Color(0xFF1C1006),
      secondary: BoardColors.signal,
      onSecondary: Color(0xFF002A24),
      surface: BoardColors.maskRaised,
      onSurface: BoardColors.silk,
      error: BoardColors.crit,
      onError: Color(0xFF2B0400),
      outline: BoardColors.trace,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.dark);
    return base.copyWith(
      scaffoldBackgroundColor: BoardColors.mask,
      appBarTheme: const AppBarTheme(
        backgroundColor: BoardColors.maskDeep,
        foregroundColor: BoardColors.silk,
        elevation: 0,
        centerTitle: false,
      ),
      dividerColor: BoardColors.trace,
      textTheme: base.textTheme.apply(bodyColor: BoardColors.silk, displayColor: BoardColors.silk),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: BoardColors.maskHigh,
        selectedColor: BoardColors.copper,
        side: const BorderSide(color: BoardColors.trace),
        labelStyle: const TextStyle(color: BoardColors.silk),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: BoardColors.copper,
        thumbColor: BoardColors.copper,
        inactiveTrackColor: BoardColors.trace,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: BoardColors.maskHigh,
        contentTextStyle: TextStyle(color: BoardColors.silk),
      ),
    );
  }

  /// Fuente monoespaciada para código y lecturas numéricas.
  static const mono = TextStyle(fontFamily: 'monospace', fontFamilyFallback: ['Courier', 'RobotoMono']);
}
