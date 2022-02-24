import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ffi/ffi.dart';
import 'editor.dart';
import 'highlighter.dart';
import 'theme.dart';
import 'native.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  initHighlighter();
  // int theme = loadTheme("/home/iceman/.editor/extensions/theme-monokai-dimmed/themes/dimmed-monokai-color-theme.json");
  int theme = loadTheme("/home/iceman/.editor/extensions/dracula-theme.theme-dracula-2.24.0/theme/dracula-soft.json");
  int lang = loadLanguage("test.cpp");
  // runHighlighter("int main(int argc, char** argv)", lang, theme, 0, 0, 0);
  
  ThemeData themeData = ThemeData(
    fontFamily: 'FiraCode',
    primaryColor: foreground,
    backgroundColor: background,
    scaffoldBackgroundColor: background,
  );

  String path = '/sdcard/Developer/tests/tinywl.c';
  if (args.length > 0) {
    path = args[0];
  }

  return runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themeData,
      home: Scaffold(
          body: Row(children: [
        Expanded(
            child:
                Padding(padding: EdgeInsets.all(0), child: Editor(path: path))),
        //Expanded(
        //    child:
        //        Padding(padding: EdgeInsets.all(0), child: Editor(path: path))),
      ]))));
}
