import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'editor.dart';
import 'highlighter.dart';
import 'theme.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  ThemeData themeData = ThemeData(
    fontFamily: 'FiraCode',
    primaryColor: foreground,
    backgroundColor: background,
    scaffoldBackgroundColor: background,
  );

  // String path = '/sdcard/Developer/tests/tinywl.c';
  String path = './tests/tinywl.c';
  // String path = './tests/sqlite3.c';
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
