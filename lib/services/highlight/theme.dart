import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

final HLTheme _theme = HLTheme();

class HLTheme extends ChangeNotifier {
  String fontFamily = 'FiraCode';
  double fontSize = 18;

  String uiFontFamily = 'FiraCode';
  double uiFontSize = 16;

  double gutterFontSize = 16;

  Color foreground = Color(0xfff8f8f2);
  Color background = Color(0xff272822);
  Color comment = Color(0xff88846f);
  Color selection = Color(0xff44475a);
  Color function = Color(0xff50fa7b);
  Color keyword = Color(0xffff79c6);
  Color string = Color(0xffff00ff);

  static HLTheme instance() {
    return _theme;
  }
}
