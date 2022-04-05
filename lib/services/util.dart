import 'package:flutter/material.dart';

const double sidebarDarken = 0.0425;
const double tabbarDarken = 0.025;
const double statusbarDarken = tabbarDarken;

bool isDark(Color clr) {
  return clr.computeLuminance() <= 0.5;
}

Color darken(Color color, [double amount = .1]) {
  assert(amount >= 0 && amount <= 1);

  final hsl = HSLColor.fromColor(color);
  final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
  return hslDark.toColor();
}

Color lighten(Color color, [double amount = .1]) {
  assert(amount >= 0 && amount <= 1);

  final hsl = HSLColor.fromColor(color);
  final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));

  return hslLight.toColor();
}

Color darkenOrLighten(Color color, [double amount = .1]) {
  return !isDark(color) ? lighten(color, amount) : darken(color, amount);
}

Color colorCombine(Color a, Color b, {int aw = 1, int bw = 1}) {
  int red = (a.red * aw + b.red * bw) ~/ (aw + bw);
  int green = (a.green * aw + b.green * bw) ~/ (aw + bw);
  int blue = (a.blue * aw + b.blue * bw) ~/ (aw + bw);
  return Color.fromRGBO(red, green, blue, 1);
}

MaterialColor toMaterialColor(Color clr) {
  Map<int, Color> colors = {
    50: clr.withOpacity(0.1),
    100: clr.withOpacity(0.2),
    200: clr.withOpacity(0.3),
    300: clr.withOpacity(0.4),
    400: clr.withOpacity(0.5),
    500: clr.withOpacity(0.6),
    600: clr.withOpacity(0.7),
    700: clr.withOpacity(0.8),
    800: clr.withOpacity(0.9),
    900: clr.withOpacity(01),
  };
  return MaterialColor(clr.value, colors);
}

Size getTextExtents(String text, TextStyle style,
    {double minWidth = 0,
    double maxWidth: double.infinity,
    int? maxLines = 1}) {
  final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: maxLines,
      textDirection: TextDirection.ltr)
    ..layout(minWidth: minWidth, maxWidth: maxWidth);
  return textPainter.size;
}
