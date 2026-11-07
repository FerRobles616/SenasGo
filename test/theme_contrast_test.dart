import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senasgo/core/theme/app_theme.dart';

double _luminance(Color color) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrast(Color a, Color b) {
  final first = _luminance(a);
  final second = _luminance(b);
  final light = math.max(first, second);
  final dark = math.min(first, second);
  return (light + 0.05) / (dark + 0.05);
}

void main() {
  for (final palette in [AppPalette.light, AppPalette.dark]) {
    final label = palette.isDark ? 'oscuro' : 'claro';

    test('El texto principal contrasta en modo $label', () {
      expect(_contrast(palette.ink, palette.surface), greaterThan(7));
      expect(_contrast(palette.muted, palette.surface), greaterThan(4.5));
    });

    test('Los botones principales contrastan en modo $label', () {
      expect(_contrast(palette.onPrimary, palette.primary), greaterThan(4.5));
      expect(_contrast(palette.primary, palette.surface), greaterThan(4.5));
    });

    test('Los bordes interactivos se distinguen del fondo en modo $label', () {
      expect(_contrast(palette.outlineStrong, palette.surface), greaterThan(3));
      expect(
        _contrast(palette.outlineStrong, palette.background),
        greaterThan(3),
      );
    });
  }
}
